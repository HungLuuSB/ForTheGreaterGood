--!strict
-- Construction, factory production and reclaim (guide 8.2, 8.7, 9).
--
-- Each tick (Construction system):
--   1. Mobile builders with a pending BUILD drive to the site; in range they
--      check placement and start an unfinished structure (1% health), or
--      assist one another builder already started there. Builders with a
--      target in range add their build power to it; out of range they drive
--      closer. Reclaimers drain wrecks into the team account.
--   2. Each target with build power advances by BP / buildTime × the team's
--      effective stall ratio (guide 8.2, 8.4), spending supply and power at
--      the same rate, capped by the window allowance. Health grows with
--      progress. Demand at full rate is reported to the Economy.
--   3. Finished structures start producing (Lifecycle.completed). A factory's
--      finished item spawns at the factory's exit and rolls clear of it.
-- Targets are processed in the order their first builder appears in
-- world.ids, so results are deterministic.

local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Air = require("./Air")
local BuildState = require("./BuildState")
local Combat = require("./Combat/Combat")
local EW = require("./EW")
local Economy = require("./Economy")
local Lifecycle = require("./Lifecycle")
local Match = require("./Match")
local Nav = require("./Nav")
local Placement = require("./Placement")
local Spawn = require("./Spawn")
local Types = require("./Types")
local World = require("./World")

local Build = {}

Build.DT = 1 / 15
Build.START_HEALTH = 0.01 -- fraction of max health a new frame starts with
Build.RECLAIM_RATE = 0.1 -- supply per second per point of build power
Build.EXIT_ROLL = 24 -- studs a new unit drives out of its factory

local sqrt = math.sqrt

local function def(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

-- Half the footprint in studs: builders reach a target's edge, not its center.
local function halfSize(d: Defs.UnitDef): number
	return d.footprint * Grid.CELL_SIZE / 2
end

local function inRange(sim: Types.Sim, builder: number, x: number, z: number, targetHalf: number): boolean
	local w = sim.world
	local d = def(sim, builder)
	local dx, dz = w.posX[builder] - x, w.posZ[builder] - z
	return sqrt(dx * dx + dz * dz) <= (d.buildRange or 0) + targetHalf
end

-- Drive toward (x, z) unless already moving there.
local function approach(sim: Types.Sim, id: number, x: number, z: number)
	local nav = sim.nav
	local w = sim.world
	if nav and w.orderId[id] == 0 then
		Nav.issueMove(nav, w, sim.tick, { id }, x, z)
	end
end

-- Stop moving and hold this spot (a builder in range of its work).
local function halt(sim: Types.Sim, id: number)
	local w = sim.world
	if sim.nav and w.orderId[id] ~= 0 then
		Nav.clearOrder(sim.nav, w, id)
		w.goalX[id], w.goalZ[id] = w.posX[id], w.posZ[id]
	end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

-- BUILD from player-owned `ids`: mobile builders get a pending structure at
-- (x, z); factories (complete structures with buildOptions) queue the unit.
function Build.commandBuild(sim: Types.Sim, ids: { number }, defIndex: number, x: number, z: number, facing: number)
	local w = sim.world
	local b = sim.build
	local target = sim.defs.unitByIndex[defIndex]
	if target == nil then
		return
	end
	for _, id in ids do
		local d = def(sim, id)
		if d.buildOptions == nil or table.find(d.buildOptions, target.id) == nil then
			continue -- can't build that
		end
		if d.domain == "structure" then
			if w.buildProgress[id] >= 1 and target.domain ~= "structure" then
				local q = b.queue[id] or {}
				if #q < BuildState.MAX_QUEUE then
					table.insert(q, defIndex)
				end
				b.queue[id] = q
				b.progress[id] = b.progress[id] or 0
			end
		elseif target.domain == "structure" then
			BuildState.idle(b, id)
			b.order[id] = { defIndex = defIndex, x = x, z = z, facing = facing }
			if sim.nav then
				Nav.clearOrder(sim.nav, w, id)
			end
			approach(sim, id, x, z)
		end
	end
end

-- REPAIR: assist an unfinished structure, or a factory's production.
function Build.commandAssist(sim: Types.Sim, ids: { number }, targetId: number)
	local w = sim.world
	local b = sim.build
	if w.slot[targetId] == nil then
		return
	end
	local td = def(sim, targetId)
	local unfinished = w.buildProgress[targetId] < 1
	local factory = not unfinished and td.domain == "structure" and td.buildOptions ~= nil
	if not unfinished and not factory then
		return -- repairing damaged units: later
	end
	for _, id in ids do
		local d = def(sim, id)
		if d.buildPower == nil or d.domain == "structure" or id == targetId or w.team[id] ~= w.team[targetId] then
			continue
		end
		BuildState.idle(b, id)
		b.target[id] = targetId
		b.assist[id] = factory
		if sim.nav then
			Nav.clearOrder(sim.nav, w, id)
		end
	end
end

-- RECLAIM a wreck.
function Build.commandReclaim(sim: Types.Sim, ids: { number }, wreckId: number)
	local b = sim.build
	if sim.combat.wreckX[wreckId] == nil then
		return
	end
	for _, id in ids do
		local d = def(sim, id)
		if d.buildPower == nil or d.domain == "structure" then
			continue
		end
		BuildState.idle(b, id)
		b.reclaim[id] = wreckId
		if sim.nav then
			Nav.clearOrder(sim.nav, sim.world, id)
		end
	end
end

-- MOVE / STOP: drop build work (factories keep their queues).
function Build.commandIdle(sim: Types.Sim, ids: { number })
	for _, id in ids do
		BuildState.idle(sim.build, id)
	end
end

--------------------------------------------------------------------------------
-- Tick
--------------------------------------------------------------------------------

-- Spawns an unfinished frame of `d` for `owner` centered near (x, z).
local function startFrame(sim: Types.Sim, d: Defs.UnitDef, owner: number, x: number, z: number, facing: number): number
	local w = sim.world
	local id = World.spawn(w, sim.tick, {
		defIndex = d.index,
		team = sim.players[owner].team,
		ally = sim.allyOf[sim.players[owner].team],
		owner = owner,
		x = x,
		z = z,
		heading = facing * math.pi / 2,
		health = math.max(1, d.health * Build.START_HEALTH),
		weaponCount = #d.weapons,
		buildProgress = 0,
	})
	Placement.occupy(sim, id)
	Lifecycle.added(sim, id)
	return id
end

-- The unfinished frame of def `defIndex` (same team) standing on the cell under (x, z), or 0.
local function frameAt(sim: Types.Sim, team: number, defIndex: number, x: number, z: number): number
	local pm = sim.map
	if pm == nil then
		return 0
	end
	local g = pm.grid
	local cx, cz = g:cellAt(x, z)
	if not g:inBounds(cx, cz) then
		return 0
	end
	local occupant = buffer.readu16(pm.occupancy, g:index(cx, cz) * 2)
	local w = sim.world
	if occupant ~= 0 and w.slot[occupant] and w.team[occupant] == team and w.defIndex[occupant] == defIndex and w.buildProgress[occupant] < 1 then
		return occupant
	end
	return 0
end

-- Per-tick scratch (reused).
local targets: { number } = {}
local power: { [number]: number } = {}
local demandS: { [number]: number } = {}
local demandP: { [number]: number } = {}

local function produce(sim: Types.Sim, factory: number, unitDef: Defs.UnitDef)
	local w = sim.world
	local fd = def(sim, factory)
	local h = w.heading[factory]
	local fx, fz = math.sin(h), math.cos(h)
	local out = halfSize(fd) + Grid.CELL_SIZE
	local x, z = w.posX[factory] + fx * out, w.posZ[factory] + fz * out
	local id = Spawn.unit(sim, unitDef.id, w.owner[factory], x, z, h)
	if sim.nav and unitDef.domain ~= "structure" then
		Nav.issueMove(sim.nav, w, sim.tick, { id }, x + fx * Build.EXIT_ROLL, z + fz * Build.EXIT_ROLL)
	end
	Combat.addEvent(sim.combat, { kind = "PRODUCED", tick = sim.tick, unit = id, other = factory })
end

function Build.step(sim: Types.Sim)
	local w = sim.world
	local b = sim.build
	local eco = sim.eco
	local DT = Build.DT

	for i = #targets, 1, -1 do
		power[targets[i]] = nil
		targets[i] = nil
	end
	for _, team in eco.teams do
		demandS[team], demandP[team] = 0, 0
	end

	local function addPower(target: number, bp: number)
		if power[target] == nil then
			power[target] = 0
			table.insert(targets, target)
		end
		power[target] += bp
	end

	-- 1. builders
	for _, id in w.ids do
		local d = def(sim, id)
		local bp = d.buildPower
		if bp == nil or w.buildProgress[id] < 1 then
			continue
		end
		if d.domain == "structure" then
			local q = b.queue[id]
			if q and #q > 0 then
				addPower(id, bp)
			end
			continue
		end

		local pending = b.order[id]
		if pending then
			local sd = sim.defs.unitByIndex[pending.defIndex]
			if inRange(sim, id, pending.x, pending.z, halfSize(sd)) then
				halt(sim, id)
				b.order[id] = nil
				local existing = frameAt(sim, w.team[id], pending.defIndex, pending.x, pending.z)
				if existing ~= 0 then
					b.target[id] = existing
					b.assist[id] = false
				else
					local ok, why, _, _, cx, cz = Placement.check(sim, sd, pending.x, pending.z)
					if ok and Match.atCap(sim, w.owner[id]) then
						ok, why = false, "unit_cap"
					end
					if ok then
						local frame = startFrame(sim, sd, w.owner[id], cx, cz, pending.facing)
						b.target[id] = frame
						b.assist[id] = false
						Combat.addEvent(sim.combat, { kind = "BUILD_START", tick = sim.tick, unit = frame, other = id })
					else
						Combat.addEvent(sim.combat, { kind = "BUILD_FAILED", tick = sim.tick, unit = id, other = pending.defIndex, reason = why })
					end
				end
			else
				approach(sim, id, pending.x, pending.z)
			end
			continue
		end

		local wreck = b.reclaim[id] or 0
		if wreck ~= 0 then
			local c = sim.combat
			local wx = c.wreckX[wreck]
			if wx == nil then
				b.reclaim[id] = 0
			elseif inRange(sim, id, wx, c.wreckZ[wreck], Grid.CELL_SIZE / 2) then
				halt(sim, id)
				local amount = math.min(c.wreckSupply[wreck], bp * Build.RECLAIM_RATE * DT)
				c.wreckSupply[wreck] -= amount
				eco.accounts[w.team[id]].supply.reclaimed += amount
				if c.wreckSupply[wreck] <= 1e-9 then
					Combat.removeWreck(c, wreck)
					b.reclaim[id] = 0
					Combat.addEvent(c, { kind = "RECLAIMED", tick = sim.tick, unit = id, other = wreck })
				end
			else
				approach(sim, id, wx, c.wreckZ[wreck])
			end
			continue
		end

		local t = b.target[id] or 0
		if t ~= 0 then
			local valid = w.slot[t] ~= nil and w.team[t] == w.team[id]
			if valid then
				if b.assist[id] then
					local q = b.queue[t]
					valid = w.buildProgress[t] >= 1 and q ~= nil and #q > 0
				else
					valid = w.buildProgress[t] < 1
				end
			end
			if not valid then
				b.target[id] = 0
			elseif inRange(sim, id, w.posX[t], w.posZ[t], halfSize(def(sim, t))) then
				halt(sim, id)
				addPower(t, bp)
			else
				approach(sim, id, w.posX[t], w.posZ[t])
			end
		end
	end

	-- 2. progress, spending, demand
	for _, t in targets do
		local bp = power[t]
		local frame = w.buildProgress[t] < 1
		local itemDef = if frame then def(sim, t) else sim.defs.unitByIndex[(b.queue[t] :: { number })[1]]
		if not frame and (b.progress[t] or 0) >= 1 - 1e-9 then
			-- finished item waiting at the exit for room under the unit cap
			if not Match.atCap(sim, w.owner[t]) then
				table.remove(b.queue[t] :: { number }, 1)
				b.progress[t] = 0
				produce(sim, t, itemDef)
			end
			continue
		end
		local cost = itemDef.cost
		local team = w.team[t]
		local acc = eco.accounts[team]
		local rate = bp / cost.buildTime -- progress per second at full supply
		demandS[team] += cost.supply * rate
		demandP[team] += cost.power * rate
		local step = rate * DT * Economy.effective(acc, cost.supply, cost.power)
		-- never spend beyond what this window still allows
		if cost.supply > 0 then
			step = math.min(step, Economy.allowance(acc.supply) / cost.supply)
		end
		if cost.power > 0 then
			step = math.min(step, Economy.allowance(acc.power) / cost.power)
		end
		if step <= 0 then
			continue
		end
		if frame then
			step = math.min(step, 1 - w.buildProgress[t])
			acc.supply.spent += cost.supply * step
			acc.power.spent += cost.power * step
			local p = w.buildProgress[t] + step
			World.setHealth(w, t, math.min(itemDef.health, w.health[t] + itemDef.health * step))
			if p >= 1 - 1e-9 then
				World.setBuildProgress(w, t, 1)
				Lifecycle.completed(sim, t)
				Combat.addEvent(sim.combat, { kind = "BUILD_DONE", tick = sim.tick, unit = t, other = 0 })
			else
				World.setBuildProgress(w, t, p)
			end
		else
			local q = b.queue[t] :: { number }
			local p = b.progress[t] or 0
			step = math.min(step, 1 - p)
			acc.supply.spent += cost.supply * step
			acc.power.spent += cost.power * step
			p += step
			if p >= 1 - 1e-9 and Match.atCap(sim, w.owner[t]) then
				b.progress[t] = 1 -- done; rolls out when the owner is under the cap
			elseif p >= 1 - 1e-9 then
				table.remove(q, 1)
				b.progress[t] = 0
				produce(sim, t, itemDef)
			else
				b.progress[t] = p
			end
		end
	end

	-- 3. aircraft landing on pads and rearming (also economy consumers)
	Air.rearmStep(sim, demandS, demandP)

	-- 4. DIRCM upkeep: continuous power drain, cooldown at the stall ratio
	EW.drainStep(sim, demandP)

	for _, team in eco.teams do
		local acc = eco.accounts[team]
		acc.supply.demand = demandS[team]
		acc.power.demand = demandP[team]
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	BuildState.clearUnit(sim.build, id)
end)

return Build

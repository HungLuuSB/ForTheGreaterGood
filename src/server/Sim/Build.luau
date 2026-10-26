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

local Blockouts = require("@shared/Defs/Blockouts/Registry")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Air = require("./Air")
local Alerts = require("./Alerts")
local BuildState = require("./BuildState")
local Combat = require("./Combat/Combat")
local EW = require("./EW")
local Economy = require("./Economy")
local Features = require("./Features")
local Lifecycle = require("./Lifecycle")
local Match = require("./Match")
local Nav = require("./Nav")
local Placement = require("./Placement")
local Sensors = require("./Sensors")
local Shield = require("./Shield")
local Spawn = require("./Spawn")
local Stockpile = require("./Stockpile")
local Types = require("./Types")
local World = require("./World")

local Build = {}

Build.DT = 1 / 15
Build.START_HEALTH = 0.01 -- fraction of max health a new frame starts with
Build.RECLAIM_RATE = 0.1 -- supply per second per point of build power
Build.POWER_RECLAIM_RATE = 1 -- power per second per point of build power: trees (S-197; power is worth a tenth of supply)
Build.EXIT_ROLL = 24 -- studs a new unit drives out of its factory
-- Set by Orders (which requires this module): gives a produced unit its
-- exit roll and its factory's rally order.
Build.producedHook = nil :: ((Types.Sim, number, number, number, number) -> ())?

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

-- Where a unit braking from its speed now comes to rest, straight ahead.
local function stopPoint(sim: Types.Sim, id: number): (number, number)
	local w = sim.world
	local d = sim.defs.unitByIndex[w.defIndex[id]]
	local v = w.speed[id] or 0
	local brake = if d.movement then d.movement.brake else 0
	if v <= 0 or brake <= 0 then
		return w.posX[id], w.posZ[id]
	end
	local s = v * v / (2 * brake)
	return w.posX[id] + math.sin(w.heading[id]) * s, w.posZ[id] + math.cos(w.heading[id]) * s
end

Build.CREEP_SPEED = 3 -- studs/s: slower than this, a builder counts as stopped (S-185)
Build.STOP_INSIDE = 6 -- studs: an approaching builder stops this far inside its reach, so a nudge doesn't put it out of range

-- Drive toward (x, z) unless already moving there. With `targetHalf`, a
-- builder starts braking once its braking distance would carry it into
-- range, so it stops at the edge of its reach instead of deep inside it
-- (S-185, the playtest's F30); while it brakes it isn't sent on again.
local function approach(sim: Types.Sim, id: number, x: number, z: number, targetHalf: number?)
	local nav = sim.nav
	local w = sim.world
	if nav == nil then
		return
	end
	local v = w.speed[id] or 0
	if w.orderId[id] ~= 0 then
		local d = def(sim, id)
		local brake = if d.movement then d.movement.brake else 0
		if targetHalf and brake > 0 and v > 0 then
			local dx, dz = w.posX[id] - x, w.posZ[id] - z
			if sqrt(dx * dx + dz * dz) - v * v / (2 * brake) <= (d.buildRange or 0) + targetHalf - Build.STOP_INSIDE then
				Nav.clearOrder(nav, w, id)
				w.goalX[id], w.goalZ[id] = stopPoint(sim, id)
				sim.build.braking[id] = sim.tick
			end
		end
		return
	end
	local since = sim.build.braking[id]
	if since and v > Build.CREEP_SPEED and sim.tick - since < 45 then
		return -- still braking from its early stop
	end
	sim.build.braking[id] = nil
	Nav.issueMove(nav, w, sim.tick, { id }, x, z)
end

-- Stop moving and hold the spot it comes to rest on (a builder in range
-- of its work): where its braking takes it, not where it is now, or it
-- would coast past and drive back (S-185, the playtest's F30).
local function halt(sim: Types.Sim, id: number)
	local w = sim.world
	if sim.nav and w.orderId[id] ~= 0 then
		Nav.clearOrder(sim.nav, w, id)
		w.goalX[id], w.goalZ[id] = stopPoint(sim, id)
	end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

-- BUILD from player-owned `ids`: mobile builders get a pending structure at
-- (x, z); factories (structures with buildOptions) queue the unit, unfinished
-- ones too: they start producing when finished (S-138, client request 63).
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
			if target.domain ~= "structure" then
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

-- REPAIR: assist an unfinished structure or a factory's production, or heal
-- a finished, damaged unit (free, at the rate it was built: S-4).
function Build.commandAssist(sim: Types.Sim, ids: { number }, targetId: number)
	local w = sim.world
	local b = sim.build
	if w.slot[targetId] == nil then
		return
	end
	local td = def(sim, targetId)
	local unfinished = w.buildProgress[targetId] < 1
	local factory = not unfinished and td.domain == "structure" and td.buildOptions ~= nil
	local damaged = not unfinished and w.health[targetId] < td.health
	if not unfinished and not factory and not damaged then
		return -- nothing to do
	end
	for _, id in ids do
		local d = def(sim, id)
		if d.buildPower == nil or d.domain == "structure" or id == targetId or w.team[id] ~= w.team[targetId] then
			continue
		end
		BuildState.idle(b, id)
		b.target[id] = targetId
		b.targetGen[id] = w.gen[targetId]
		b.assist[id] = factory
		b.repair[id] = (not unfinished and not factory) or nil
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

-- RESURRECT a wreck (S-168): builders that can (`canResurrect`) refill it
-- with supply to what it held, then bring its unit back for power. Not a
-- Commander's wreck.
function Build.commandResurrect(sim: Types.Sim, ids: { number }, wreckId: number)
	local b = sim.build
	local c = sim.combat
	if c.wreckX[wreckId] == nil then
		return
	end
	if c.wreckKind[wreckId] then
		return -- a map feature: nothing to bring back (S-197)
	end
	local wd = sim.defs.unitByIndex[c.wreckDef[wreckId]]
	if table.find(wd.categories, "COMMANDER") then
		return
	end
	for _, id in ids do
		local d = def(sim, id)
		if not d.canResurrect or d.domain == "structure" then
			continue
		end
		BuildState.idle(b, id)
		b.resurrect[id] = wreckId
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
		weaponRest = Combat.restPoses(sim, d.index),
		weaponStock = Stockpile.initial(sim, d.index, false), -- built sites start empty (S-47)
		buildProgress = 0,
	})
	Placement.occupy(sim, id)
	if d.converter or d.retract or d.shield then
		World.setState(w, id, bit32.bor(w.state[id], World.State.TOGGLED_ON)) -- converters, retracting towers (S-96) and shield generators (S-154) start on
	end
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
local priorityS: { [number]: number } = {} -- missile refills' share of the demand (S-66)
local priorityP: { [number]: number } = {}
local lowPower: { [number]: number } = {} -- of `power`: from low-priority builders (S-156)
local lowS: { [number]: number } = {} -- low-priority consumers' share of the demand (S-156)
local lowP: { [number]: number } = {}
local LOW_PRIORITY = World.State.LOW_PRIORITY

Build.RESURRECT_POWER = 1 -- of the unit's power cost (S-168: resurrecting costs power only)

-- One tick of `id` resurrecting wreck `wreck` (in range): refill first, at
-- its reclaim rate, paid in supply; then progress at its build power
-- against the unit's build time, paid in power. Both are economy consumers
-- (stall ratios, priority) like building. Done: the unit stands where the
-- wreck lay, the builder's owner's, at full health; a structure waits for
-- its footprint to be free, anything for room under the unit cap.
local function resurrectStep(sim: Types.Sim, id: number, wreck: number, bp: number)
	local w = sim.world
	local c = sim.combat
	local b = sim.build
	local wd = sim.defs.unitByIndex[c.wreckDef[wreck]]
	local team = w.team[id]
	local acc = sim.eco.accounts[team]
	local low = Economy.isLow(w, id)
	local full = Combat.fullWreckSupply(wd)
	local free = sim.cheats.instabuild
	local function consume(cs: number, cp: number, rate: number): number
		if free then
			return math.huge
		end
		demandS[team] += cs * rate
		demandP[team] += cp * rate
		if low then
			lowS[team] += cs * rate
			lowP[team] += cp * rate
		end
		local step = rate * Build.DT * Economy.effective(acc, cs, cp, low)
		if cs > 0 then
			step = math.min(step, Economy.allowance(acc.supply) / cs)
		end
		if cp > 0 then
			step = math.min(step, Economy.allowance(acc.power) / cp)
		end
		acc.supply.spent += cs * step
		acc.power.spent += cp * step
		return step
	end
	local supply = c.wreckSupply[wreck]
	if supply < full - 1e-9 then
		-- the wreck was partly reclaimed: put the supply back first
		local amount = math.min(full - supply, consume(1, 0, bp * Build.RECLAIM_RATE))
		c.wreckSupply[wreck] = math.min(full, supply + amount)
		return
	end
	local rez = c.wreckRez[wreck] or 0
	if rez < 1 - 1e-9 then
		local rate = bp / wd.cost.buildTime
		rez = math.min(1, rez + consume(0, wd.cost.power * Build.RESURRECT_POWER, rate))
		c.wreckRez[wreck] = rez
		if rez < 1 - 1e-9 then
			return
		end
	end
	-- done: room for it?
	local owner = w.owner[id]
	local x, z = c.wreckX[wreck], c.wreckZ[wreck]
	if Match.atCap(sim, owner) then
		return
	end
	if wd.domain == "structure" and not Placement.check(sim, wd, x, z, owner) then
		return -- units on the footprint: wait (they walk off a frame, not a wreck)
	end
	local heading = c.wreckHeading[wreck]
	Combat.removeWreck(c, wreck)
	b.resurrect[id] = 0
	local unit = Spawn.unit(sim, wd.id, owner, x, z, heading)
	Stockpile.empty(sim, unit) -- missiles are built again, as for a produced unit (S-47)
	Combat.addEvent(c, { kind = "RESURRECTED", tick = sim.tick, unit = unit, other = wreck })
	Build.countBuilt(sim, unit)
end


-- Cancelling (guide 9.3, S-35): what was spent comes back. Spending is
-- proportional to progress, so a refund is progress × cost, credited like
-- reclaim at the next economy step (capped by storage).
local function refund(sim: Types.Sim, team: number, d: Defs.UnitDef, progress: number)
	local acc = sim.eco.accounts[team]
	if acc and progress > 0 then
		acc.supply.reclaimed += d.cost.supply * progress
		acc.power.reclaimed += d.cost.power * progress
	end
end

-- Cancels an unfinished frame: refund, and the frame is gone (no wreck).
-- False when `id` isn't an unfinished frame.
function Build.cancelFrame(sim: Types.Sim, id: number): boolean
	local w = sim.world
	if w.slot[id] == nil or w.buildProgress[id] >= 1 then
		return false
	end
	refund(sim, w.team[id], def(sim, id), w.buildProgress[id])
	Combat.addEvent(sim.combat, { kind = "BUILD_FAILED", tick = sim.tick, unit = id, other = 0, reason = "cancelled" })
	Lifecycle.remove(sim, id)
	return true
end

-- Drops item `index` (1-based; 0 = all) from a factory's queue; the item in
-- production is refunded what was spent on it.
function Build.cancelQueued(sim: Types.Sim, factory: number, index: number)
	local b = sim.build
	local q = b.queue[factory]
	if q == nil or #q == 0 or index > #q then
		return
	end
	local w = sim.world
	if index <= 1 then
		refund(sim, w.team[factory], sim.defs.unitByIndex[q[1]], b.progress[factory] or 0)
		b.progress[factory] = 0
	end
	if index == 0 then
		table.clear(q)
	else
		table.remove(q, index)
	end
end

-- A finished unit for the results screen (Stats, S-63).
function Build.countBuilt(sim: Types.Sim, id: number)
	local s = sim.playerStats[sim.world.owner[id]]
	if s then
		s.unitsBuilt += 1
	end
	Alerts.built(sim, id) -- BUILD_DONE (S-68)
end

-- A factory's build pad in its model space (x right, z back: forward is -z;
-- rig.md 8): the blockout's `buildpad` attachment (C-152), else the middle
-- of the front edge. Cached per def.
local padCache: { [string]: { number } } = {}
function Build.padOffset(d: Defs.UnitDef): (number, number)
	local c = padCache[d.id]
	if c == nil then
		c = { 0, -halfSize(d) }
		local bp = (Blockouts :: any)[d.id]
		for _, a in (bp and bp.attachments) or {} do
			if a.name == "buildpad" then
				c = { a.at[1], a.at[3] }
			end
		end
		padCache[d.id] = c
	end
	return c[1], c[2]
end

-- World position of factory `factory`'s build pad. The client turns a model
-- by heading + π about +Y (CFrame.Angles), so model (ax, az) lands at
-- (-ax cos h - az sin h, ax sin h - az cos h) from the factory's centre.
function Build.padPosition(sim: Types.Sim, factory: number): (number, number)
	local w = sim.world
	local ax, az = Build.padOffset(def(sim, factory))
	local h = w.heading[factory]
	local c, s = math.cos(h), math.sin(h)
	return w.posX[factory] - ax * c - az * s, w.posZ[factory] + ax * s - az * c
end

-- A finished unit appears on its factory's build pad, where the client drew
-- it in production (S-133, client request 61), facing the exit. Units that
-- move on the ground or water then drive straight out through the factory's
-- own footprint (BuildState.exiting, Movement) to EXIT_ROLL past the
-- front edge, then take the factory's orders.
local padBusy: { [number]: boolean } = {}

local function produce(sim: Types.Sim, factory: number, unitDef: Defs.UnitDef)
	local w = sim.world
	local fd = def(sim, factory)
	local h = w.heading[factory]
	local fx, fz = math.sin(h), math.cos(h)
	local x, z = Build.padPosition(sim, factory)
	local id = Spawn.unit(sim, unitDef.id, w.owner[factory], x, z, h)
	Stockpile.empty(sim, id) -- produced units start empty and fill up (S-47)
	if sim.nav and unitDef.domain ~= "structure" then
		-- from the pad along the heading to EXIT_ROLL past the factory's front edge
		local _, az = Build.padOffset(fd)
		local roll = halfSize(fd) + az + Grid.CELL_SIZE + Build.EXIT_ROLL
		local ex, ez = x + fx * roll, z + fz * roll
		local p = sim.nav.profiles[w.defIndex[id]]
		if p and not p.air then
			sim.build.exiting[id] = { w.posX[factory], w.posZ[factory], halfSize(fd), ex, ez, factory }
		end
		if Build.producedHook then
			Build.producedHook(sim, factory, id, ex, ez) -- exit roll, then the rally order (Orders)
		else
			Nav.issueMove(sim.nav, w, sim.tick, { id }, ex, ez)
		end
	end
	Combat.addEvent(sim.combat, { kind = "PRODUCED", tick = sim.tick, unit = id, other = factory })
	Build.countBuilt(sim, id)
end

function Build.step(sim: Types.Sim)
	local w = sim.world
	local b = sim.build
	local eco = sim.eco
	local DT = Build.DT

	for i = #targets, 1, -1 do
		power[targets[i]] = nil
		lowPower[targets[i]] = nil
		targets[i] = nil
	end
	for _, team in eco.teams do
		demandS[team], demandP[team] = 0, 0
		priorityS[team], priorityP[team] = 0, 0
		lowS[team], lowP[team] = 0, 0
	end

	-- `builder`'s power goes to `target`; a low-priority builder's is
	-- counted apart, and progresses at the low ratios (S-156)
	local function addPower(target: number, bp: number, builder: number)
		if power[target] == nil then
			power[target] = 0
			table.insert(targets, target)
		end
		power[target] += bp
		if bit32.band(w.state[builder], LOW_PRIORITY) ~= 0 then
			lowPower[target] = (lowPower[target] or 0) + bp
		end
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
				addPower(id, bp, id)
			end
			continue
		end

		local pending = b.order[id]
		if pending then
			local sd = sim.defs.unitByIndex[pending.defIndex]
			-- in range of where the frame will stand (the snapped center),
			-- the same point building is then measured from (S-19)
			local sx, sz = pending.x, pending.z
			if sim.map then
				local _, _, cx, cz = Placement.snap(sim.map.grid, sd.footprint, pending.x, pending.z)
				sx, sz = cx, cz
			end
			if inRange(sim, id, sx, sz, halfSize(sd)) then
				halt(sim, id)
				b.order[id] = nil
				local existing = frameAt(sim, w.team[id], pending.defIndex, pending.x, pending.z)
				if existing ~= 0 then
					b.target[id] = existing
					b.targetGen[id] = w.gen[existing]
					b.assist[id] = false
				else
					local ok, why, _, _, cx, cz, replaces = Placement.check(sim, sd, pending.x, pending.z, w.owner[id])
					if ok and Match.atCap(sim, w.owner[id]) then
						ok, why = false, "unit_cap"
					end
					if ok then
						local frame = startFrame(sim, sd, w.owner[id], cx, cz, pending.facing)
						if replaces ~= 0 then
							-- in-place upgrade (S-108): the old structure works on
							-- under the frame and goes when the frame is finished
							b.upgrading[frame] = replaces
							b.upgradingGen[frame] = w.gen[replaces]
						end
						b.target[id] = frame
						b.targetGen[id] = w.gen[frame]
						b.assist[id] = false
						Combat.addEvent(sim.combat, { kind = "BUILD_START", tick = sim.tick, unit = frame, other = id })
					else
						Combat.addEvent(sim.combat, { kind = "BUILD_FAILED", tick = sim.tick, unit = id, other = pending.defIndex, reason = why })
					end
				end
			else
				approach(sim, id, sx, sz, halfSize(sd))
			end
			continue
		end

		local rezWreck = b.resurrect[id] or 0
		if rezWreck ~= 0 then
			local c = sim.combat
			local wx = c.wreckX[rezWreck]
			if wx == nil then
				b.resurrect[id] = 0 -- gone (reclaimed away, or another builder finished it)
			elseif inRange(sim, id, wx, c.wreckZ[rezWreck], Grid.CELL_SIZE / 2) then
				halt(sim, id)
				resurrectStep(sim, id, rezWreck, bp)
			else
				approach(sim, id, wx, c.wreckZ[rezWreck], Grid.CELL_SIZE / 2)
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
				-- a tree pays power, at POWER_RECLAIM_RATE (S-197); wrecks and rocks supply
				local resource = Features.resource(sim, wreck)
				local rate = if resource == "power" then Build.POWER_RECLAIM_RATE else Build.RECLAIM_RATE
				local amount = math.min(c.wreckSupply[wreck], bp * rate * DT)
				c.wreckSupply[wreck] -= amount
				local acc = eco.accounts[w.team[id]]
				if resource == "power" then
					acc.power.reclaimed += amount
				else
					acc.supply.reclaimed += amount
				end
				if c.wreckSupply[wreck] <= 1e-9 then
					Features.cleared(sim, wreck) -- (a rock frees its cell)
					Combat.removeWreck(c, wreck)
					b.reclaim[id] = 0
					Combat.addEvent(c, { kind = "RECLAIMED", tick = sim.tick, unit = id, other = wreck })
				end
			else
				approach(sim, id, wx, c.wreckZ[wreck], Grid.CELL_SIZE / 2)
			end
			continue
		end

		local t = b.target[id] or 0
		if t ~= 0 then
			local valid = World.isRef(w, t, b.targetGen[id]) and w.team[t] == w.team[id] -- D109
			if valid then
				if b.assist[id] then
					local q = b.queue[t]
					valid = w.buildProgress[t] >= 1 and q ~= nil and #q > 0
				elseif b.repair[id] then
					valid = w.buildProgress[t] >= 1 and w.health[t] < def(sim, t).health
				else
					valid = w.buildProgress[t] < 1
				end
			end
			if not valid then
				b.target[id] = 0
				b.repair[id] = nil
			elseif inRange(sim, id, w.posX[t], w.posZ[t], halfSize(def(sim, t))) then
				halt(sim, id)
				if b.repair[id] then
					-- heal at the rate it was built, for free (S-4)
					local td = def(sim, t)
					World.setHealth(w, t, math.min(td.health, w.health[t] + td.health * bp / td.cost.buildTime * DT))
				else
					addPower(t, bp, id)
				end
			else
				approach(sim, id, w.posX[t], w.posZ[t], halfSize(def(sim, t)))
			end
		end
	end

	-- 2. missile stockpiles (S-47) first: refills have priority in a stall (S-66)
	Stockpile.step(sim, demandS, demandP, priorityS, priorityP, lowS, lowP)

	-- a factory waits while a unit it made still stands on its build pad
	-- (within twice its radius: the next one would appear on top of it; S-133,
	-- the user: a stuck unit holds its factory)
	table.clear(padBusy)
	for id, e in b.exiting do
		local f = e[6]
		if w.slot[f] ~= nil and w.posX[f] == e[1] and w.posZ[f] == e[2] and not padBusy[f] then
			local px, pz = Build.padPosition(sim, f)
			local p = sim.nav and sim.nav.profiles[w.defIndex[id]]
			local r = 2 * (if p then p.radius else 2) + 1
			if (w.posX[id] - px) ^ 2 + (w.posZ[id] - pz) ^ 2 < r * r then
				padBusy[f] = true
			end
		end
	end

	-- 2b. progress, spending, demand
	for _, t in targets do
		local bp = power[t]
		local frame = w.buildProgress[t] < 1
		if not frame and padBusy[t] then
			continue
		end
		local itemDef = if frame then def(sim, t) else sim.defs.unitByIndex[(b.queue[t] :: { number })[1]]
		if not frame and (b.progress[t] or 0) >= 1 - 1e-9 then
			-- finished item waiting at the exit for room under the unit cap
			if not Match.atCap(sim, w.owner[t]) then
				local q = b.queue[t] :: { number }
				table.remove(q, 1)
				if sim.orders.repeatOn[t] then
					table.insert(q, itemDef.index) -- repeat: back to the end of the queue (S-4)
				end
				b.progress[t] = 0
				produce(sim, t, itemDef)
			end
			continue
		end
		local cost = itemDef.cost
		local team = w.team[t]
		local acc = eco.accounts[team]
		local free = sim.cheats.instabuild -- (S-102) done at once, nothing spent
		local step = 1
		if not free then
			local rate = bp / cost.buildTime -- progress per second at full supply
			demandS[team] += cost.supply * rate
			demandP[team] += cost.power * rate
			local low = lowPower[t]
			if low == nil then
				step = rate * DT * Economy.effective(acc, cost.supply, cost.power)
			else
				-- low-priority builders' share at the low ratios (S-156)
				local lowRate = low / cost.buildTime
				lowS[team] += cost.supply * lowRate
				lowP[team] += cost.power * lowRate
				step = ((rate - lowRate) * Economy.effective(acc, cost.supply, cost.power) + lowRate * Economy.effective(acc, cost.supply, cost.power, true)) * DT
			end
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
		end
		if frame then
			step = math.min(step, 1 - w.buildProgress[t])
			if not free then
				acc.supply.spent += cost.supply * step
				acc.power.spent += cost.power * step
			end
			local p = w.buildProgress[t] + step
			World.setHealth(w, t, math.min(itemDef.health, w.health[t] + itemDef.health * step))
			if p >= 1 - 1e-9 then
				World.setBuildProgress(w, t, 1)
				Lifecycle.completed(sim, t)
				Build.finishUpgrade(sim, t)
				Combat.addEvent(sim.combat, { kind = "BUILD_DONE", tick = sim.tick, unit = t, other = 0 })
				Build.countBuilt(sim, t)
			else
				World.setBuildProgress(w, t, p)
			end
		else
			local q = b.queue[t] :: { number }
			local p = b.progress[t] or 0
			step = math.min(step, 1 - p)
			if not free then
				acc.supply.spent += cost.supply * step
				acc.power.spent += cost.power * step
			end
			p += step
			if p >= 1 - 1e-9 and Match.atCap(sim, w.owner[t]) then
				b.progress[t] = 1 -- done; rolls out when the owner is under the cap
			elseif p >= 1 - 1e-9 then
				table.remove(q, 1)
				if sim.orders.repeatOn[t] then
					table.insert(q, itemDef.index) -- repeat: back to the end of the queue (S-4)
				end
				b.progress[t] = 0
				produce(sim, t, itemDef)
			else
				b.progress[t] = p
			end
		end
	end

	-- 3. aircraft landing on pads and rearming (also economy consumers)
	Air.rearmStep(sim, demandS, demandP, lowS, lowP)

	-- 4. DIRCM upkeep: continuous power drain, cooldown at the stall ratio
	EW.drainStep(sim, demandP, lowP)

	-- 5. tracking radars: power drain, radius at the stall ratio (D104)
	Sensors.drainStep(sim, demandP, lowP)

	-- 6. shield domes recharging (S-79)
	Shield.drainStep(sim, demandP, lowP)

	for _, team in eco.teams do
		local acc = eco.accounts[team]
		acc.supply.demand = demandS[team]
		acc.power.demand = demandP[team]
		acc.supply.priorityDemand = priorityS[team]
		acc.power.priorityDemand = priorityP[team]
		acc.supply.lowDemand = lowS[team]
		acc.power.lowDemand = lowP[team]
	end
end

-- An in-place upgrade's frame `frame` is finished (S-108): the structure it
-- replaces goes (no wreck, no refund) if it still stands.
function Build.finishUpgrade(sim: Types.Sim, frame: number)
	local b = sim.build
	local old = b.upgrading[frame]
	if old == nil then
		return
	end
	local gen = b.upgradingGen[frame]
	b.upgrading[frame], b.upgradingGen[frame] = nil, nil
	if World.isRef(sim.world, old, gen) then
		Lifecycle.remove(sim, old)
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	local b = sim.build
	local old = b.upgrading[id]
	if old ~= nil and World.isRef(sim.world, old, b.upgradingGen[id]) then
		-- an upgrade frame cancelled or destroyed (S-108): the old structure
		-- takes its cells back (Placement freed the frame's just before)
		Placement.occupy(sim, old)
	end
	BuildState.clearUnit(b, id)
end)

return Build

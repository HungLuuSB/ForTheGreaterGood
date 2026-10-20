--!strict
-- Aircraft behavior (guide 6.7, 12.2): jet steering, altitude bands, ammo,
-- return-to-rearm and rearming through the team economy.
--
-- Jets never fly slower than movement.minSpeed and turn at their turn rate.
-- Idle (no order) they circle their goal at LOITER_RADIUS; with a weapon
-- target they chase it, overshoot and come around (circling the target);
-- with a move order they fly to the goal and start circling it.
-- Helicopters use the ordinary steering (they can hover) at their own band.
--
-- An aircraft whose ammo runs out flies to the nearest friendly rearm pad,
-- lands when within reach and a pad slot is free, rearms round by round
-- (paying ammoCost per round at the team's stall ratio, guide 8.6), then
-- takes off back to where it was going. Spent flares and chaff are restocked
-- alongside the rounds: their refillSupply is spread evenly over the rounds,
-- so they cost supply without lengthening the rearm (guide 11.6).

local AirState = require("./AirState")
local Defs = require("@shared/Defs/Defs")
local EW = require("./EW")
local Economy = require("./Economy")
local Lifecycle = require("./Lifecycle")
local Nav = require("./Nav")
local Sensors = require("./Sensors")
local Types = require("./Types")
local World = require("./World")

local Air = {}

Air.DT = 1 / 15
Air.ALTITUDE = table.freeze({ JET = 100, HELI = 35 }) -- studs above ground (guide 6.7)
Air.CLIMB_RATE = 40 -- studs per second
Air.LOITER_RADIUS = 220 -- studs; wider than a jet's turn circle at cruise speed
Air.CRUISE = 0.75 -- fraction of max speed while circling
Air.LAND_RADIUS = table.freeze({ JET = 60, HELI = 12 })
Air.EDGE_MARGIN = 60 -- studs: jets turn back toward the map before leaving it

local sqrt, atan2 = math.sqrt, math.atan2
local PI, TAU = math.pi, 2 * math.pi
local LANDED = World.State.LANDED

local function wrapAngle(a: number): number
	a = a % TAU
	if a > PI then
		a -= TAU
	end
	return a
end

local function def(sim: Types.Sim, id: number): Defs.UnitDef
	return sim.defs.unitByIndex[sim.world.defIndex[id]]
end

-- New aircraft: cruising altitude, full ammo, current spot as resume point.
function Air.onSpawn(sim: Types.Sim, id: number)
	local d = def(sim, id)
	if d.domain ~= "air" then
		return
	end
	local w = sim.world
	local a = sim.air
	w.alt[id] = Air.ALTITUDE[d.moveClass or "HELI"] or 35
	a.phase[id] = "fly"
	a.ammo[id] = d.ammo
	a.pad[id] = 0
	a.progress[id] = 0
	a.resumeX[id], a.resumeZ[id] = w.posX[id], w.posZ[id]
end

-- Nearest complete friendly rearm pad, or 0.
local function nearestPad(sim: Types.Sim, id: number): number
	local w = sim.world
	local best, bestD = 0, math.huge
	for _, other in w.ids do
		if w.team[other] == w.team[id] and w.buildProgress[other] >= 1 and def(sim, other).rearmPads then
			local d = (w.posX[other] - w.posX[id]) ^ 2 + (w.posZ[other] - w.posZ[id]) ^ 2
			if d < bestD then
				best, bestD = other, d
			end
		end
	end
	return best
end

local function headTo(sim: Types.Sim, id: number, x: number, z: number)
	if sim.nav then
		Nav.issueMove(sim.nav, sim.world, sim.tick, { id }, x, z)
	end
end

-- Out of ammo: remember where we were going, head for a pad.
function Air.onEmpty(sim: Types.Sim, id: number)
	local a = sim.air
	if a.phase[id] ~= "fly" then
		return
	end
	local w = sim.world
	a.resumeX[id], a.resumeZ[id] = w.goalX[id], w.goalZ[id]
	local pad = nearestPad(sim, id)
	if pad == 0 then
		return -- nowhere to rearm: keep flying empty
	end
	a.phase[id] = "return"
	a.pad[id] = pad
	headTo(sim, id, w.posX[pad], w.posZ[pad])
end

-- Spends one round; returns false if the unit has no ammo to fire.
function Air.useAmmo(sim: Types.Sim, id: number): boolean
	local a = sim.air
	local ammo = a.ammo[id]
	if ammo == nil then
		return true -- unlimited
	end
	if ammo <= 0 or a.phase[id] ~= "fly" then
		return false
	end
	a.ammo[id] = ammo - 1
	if ammo - 1 <= 0 then
		Air.onEmpty(sim, id)
	end
	return true
end

--------------------------------------------------------------------------------
-- Jet steering (called by Movement for JET units)
--------------------------------------------------------------------------------

-- Returns the jet's new heading and speed for this tick.
function Air.steerJet(sim: Types.Sim, id: number, p: Nav.Profile, x: number, z: number, h: number, v: number): (number, number)
	local a = sim.air
	local w = sim.world
	local phase = a.phase[id]
	if phase == "rearm" then
		return h, 0 -- parked on its pad
	end
	local nav = sim.nav :: Nav.Nav
	local tx, tz = w.goalX[id], w.goalZ[id]
	local loiter = true
	if phase == "return" and w.slot[a.pad[id]] then
		local pad = a.pad[id]
		tx, tz, loiter = w.posX[pad], w.posZ[pad], false
	else
		local target = if w.weaponCount[id] > 0 then w.wTarget[World.slotKey(id, 1)] else 0
		local kx, kz = nil, nil
		if target ~= 0 and (a.ammo[id] == nil or a.ammo[id] > 0) then
			kx, kz = Sensors.knownPosition(sim, w.team[id], target)
		end
		if kx and kz then
			tx, tz, loiter = kx, kz, false -- chase; overshoot and come around
		elseif w.orderId[id] ~= 0 then
			local dist = sqrt((tx - x) ^ 2 + (tz - z) ^ 2)
			if dist <= Air.LOITER_RADIUS then
				Nav.clearOrder(nav, w, id) -- arrived: circle the goal from now on
			else
				loiter = false
			end
		end
	end

	local dirX, dirZ
	if loiter then
		-- circle (tx, tz) clockwise at LOITER_RADIUS: tangent plus a radial correction
		local rx, rz = x - tx, z - tz
		local d = sqrt(rx * rx + rz * rz)
		if d < 1e-6 then
			rx, rz, d = 1, 0, 1
		end
		local ux, uz = rx / d, rz / d
		local radial = (Air.LOITER_RADIUS - d) / Air.LOITER_RADIUS * 1.5
		dirX, dirZ = uz + ux * radial, -ux + uz * radial
	else
		dirX, dirZ = tx - x, tz - z
	end
	-- stay over the map
	local g = nav.grid
	local cx, cz = g.originX + g.sizeX / 2, g.originZ + g.sizeZ / 2
	if math.abs(x - cx) > g.sizeX / 2 - Air.EDGE_MARGIN or math.abs(z - cz) > g.sizeZ / 2 - Air.EDGE_MARGIN then
		dirX, dirZ = cx - x, cz - z
	end

	local want = atan2(dirX, dirZ)
	local diff = wrapAngle(want - h)
	local maxTurn = p.turnRate * Air.DT
	local nh = wrapAngle(h + math.clamp(diff, -maxTurn, maxTurn))
	local minSpeed = p.minSpeed or 0
	local targetSpeed = if loiter then math.max(minSpeed, p.maxSpeed * Air.CRUISE) else p.maxSpeed
	local nv = if v < targetSpeed then math.min(targetSpeed, v + p.accel * Air.DT) else math.max(targetSpeed, v - p.brake * Air.DT)
	return nh, math.clamp(nv, minSpeed, p.maxSpeed)
end

-- Altitude: cruise band in flight, 0 when landed; climbs and descends at
-- CLIMB_RATE. Called by Movement for every aircraft.
function Air.updateAltitude(sim: Types.Sim, id: number)
	local w = sim.world
	local d = def(sim, id)
	local target = if sim.air.phase[id] == "rearm" then 0 else Air.ALTITUDE[d.moveClass or "HELI"] or 35
	local alt = w.alt[id]
	if alt ~= target then
		local step = Air.CLIMB_RATE * Air.DT
		World.setAltitude(w, id, if alt < target then math.min(target, alt + step) else math.max(target, alt - step))
	end
end

--------------------------------------------------------------------------------
-- Landing and rearming (called by Build.step: rearming is an economy consumer)
--------------------------------------------------------------------------------

local padLoad: { [number]: number } = {}
local NO_COST: { supply: number?, power: number? } = table.freeze({})

function Air.rearmStep(sim: Types.Sim, demandS: { [number]: number }, demandP: { [number]: number })
	local w = sim.world
	local a = sim.air
	local eco = sim.eco
	table.clear(padLoad)
	for _, id in w.ids do
		if a.phase[id] == "rearm" then
			padLoad[a.pad[id]] = (padLoad[a.pad[id]] or 0) + 1
		end
	end

	for _, id in w.ids do
		local phase = a.phase[id]
		if phase == "return" then
			local pad = a.pad[id]
			if w.slot[pad] == nil then
				pad = nearestPad(sim, id) -- pad destroyed: try another
				a.pad[id] = pad
				if pad == 0 then
					a.phase[id] = "fly"
					continue
				end
				headTo(sim, id, w.posX[pad], w.posZ[pad])
			end
			local d = def(sim, id)
			local reach = Air.LAND_RADIUS[d.moveClass or "HELI"] or 12
			local dist = sqrt((w.posX[pad] - w.posX[id]) ^ 2 + (w.posZ[pad] - w.posZ[id]) ^ 2)
			if dist <= reach and (padLoad[pad] or 0) < (def(sim, pad).rearmPads or 1) then
				-- land on the pad
				padLoad[pad] = (padLoad[pad] or 0) + 1
				a.phase[id] = "rearm"
				a.progress[id] = 0
				local rounds = math.max((def(sim, id).ammo or 1) - a.ammo[id], 1)
				local charges, supply = EW.missingCharges(sim, id)
				a.cmPerRound[id] = charges / rounds
				a.cmSupplyPerRound[id] = supply / rounds
				a.cmProgress[id] = 0
				if sim.nav then
					Nav.clearOrder(sim.nav, w, id)
				end
				World.setPosition(w, id, w.posX[pad], w.posZ[pad])
				w.goalX[id], w.goalZ[id] = w.posX[pad], w.posZ[pad]
				w.speed[id] = 0
				World.setState(w, id, bit32.bor(w.state[id], LANDED))
			end
		elseif phase == "rearm" then
			local d = def(sim, id)
			local pad = a.pad[id]
			if w.slot[pad] == nil then
				-- pad destroyed under us: take off and look for another
				a.phase[id] = "fly"
				World.setState(w, id, bit32.band(w.state[id], bit32.bnot(LANDED)))
				Air.onEmpty(sim, id)
				continue
			end
			local cost = d.ammoCost or NO_COST
			local cs, cp = (cost.supply or 0) + (a.cmSupplyPerRound[id] or 0), cost.power or 0
			local rate = 1 / (d.rearmTime :: number) -- rounds per second at full economy
			local team = w.team[id]
			local acc = eco.accounts[team]
			demandS[team] += cs * rate
			demandP[team] += cp * rate
			local step = rate * Air.DT * Economy.effective(acc, cs, cp)
			if cs > 0 then
				step = math.min(step, Economy.allowance(acc.supply) / cs)
			end
			if cp > 0 then
				step = math.min(step, Economy.allowance(acc.power) / cp)
			end
			if step > 0 then
				acc.supply.spent += cs * step
				acc.power.spent += cp * step
				local progress = a.progress[id] + step
				while progress >= 1 - 1e-9 and a.ammo[id] < (d.ammo :: number) do
					a.ammo[id] += 1
					progress -= 1
				end
				a.progress[id] = math.max(progress, 0)
				local perRound = a.cmPerRound[id] or 0
				if perRound > 0 then
					local cm = (a.cmProgress[id] or 0) + step * perRound
					while cm >= 1 - 1e-9 and EW.addCharge(sim, id) do
						cm -= 1
					end
					a.cmProgress[id] = math.max(cm, 0)
				end
			end
			if a.ammo[id] >= (d.ammo :: number) then
				-- full: take off and go back. The last fraction of a charge is
				-- already paid, so top the countermeasures up.
				EW.refill(sim, id)
				a.cmPerRound[id], a.cmSupplyPerRound[id], a.cmProgress[id] = nil, nil, nil
				a.phase[id] = "fly"
				a.pad[id] = 0
				a.progress[id] = 0
				World.setState(w, id, bit32.band(w.state[id], bit32.bnot(LANDED)))
				if d.movement and d.movement.minSpeed then
					w.speed[id] = d.movement.minSpeed
				end
				headTo(sim, id, a.resumeX[id], a.resumeZ[id])
			end
		end
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	AirState.clearUnit(sim.air, id)
end)

return Air

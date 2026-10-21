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
local Combat = require("./Combat/Combat")
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
Air.ALTITUDE = table.freeze({ JET = 100, HELI = 35, BOMBER = 130 }) -- studs above ground (guide 6.7)
Air.EGRESS_TICKS = 45 -- bombers fly straight this long after a release (3 s)
Air.RUN_IN = 150 -- studs beyond the release distance a bomber turns back from (about a turn radius)
Air.CLIMB_RATE = 40 -- studs per second
Air.LOITER_RADIUS = 220 -- studs; wider than a jet's turn circle at cruise speed
Air.ARRIVE_RADIUS = 40 -- studs: a jet's move ends this close to its goal, or once it flew toward it and the goal fell behind (client request 17)
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

-- Does this def carry a BOMB weapon? Cached per def.
local bomberCache: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Air.isBomber(sim: Types.Sim, d: Defs.UnitDef): boolean
	local cached = bomberCache[d]
	if cached == nil then
		cached = false
		for _, slot in d.weapons do
			if sim.defs.weaponByIndex[slot.weaponIndex].type == "BOMB" then
				cached = true
			end
		end
		bomberCache[d] = cached
	end
	return cached
end

local function cruiseAltitude(sim: Types.Sim, d: Defs.UnitDef): number
	if Air.isBomber(sim, d) then
		return Air.ALTITUDE.BOMBER
	end
	return Air.ALTITUDE[d.moveClass or "HELI"] or 35
end

-- Bomb solution for bomber `id` against `target` known at (kx, kz) (guide
-- 10.5: a bomb leaves with the bomber's velocity and falls). Returns the
-- fall time, where the bomb would land if dropped now, and where the target
-- will be by then (its velocity is only known while VISIBLE).
function Air.bombSolution(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, target: number, kx: number, kz: number, defIndex: number?): (number, number, number, number, number)
	local w = sim.world
	local c = sim.combat
	local dropY = Combat.unitBase(c, w, id) + c.profiles[w.defIndex[id]].muzzleHeight
	local _, hitY = Combat.knownAimPoint(c, w, target, defIndex, kx, kz) -- at the believed position
	local g = weapon.gravity or 60
	local t = sqrt(2 * math.max(dropY - hitY, 1) / g)
	local h, v = w.heading[id], w.speed[id]
	local ix, iz = w.posX[id] + math.sin(h) * v * t, w.posZ[id] + math.cos(h) * v * t
	local ax, az = kx, kz
	-- lead a target whose motion the team sees: VISIBLE, or tracked by its
	-- fire-control radar (D104)
	local level = if target ~= 0 then Sensors.level(sim, w.ally[id], target) else Sensors.Level.HIDDEN
	if level == Sensors.Level.VISIBLE or (level == Sensors.Level.RADAR and Sensors.isTracked(sim, w.ally[id], target)) then
		local th, tv = w.heading[target], w.speed[target]
		ax += math.sin(th) * tv * t
		az += math.cos(th) * tv * t
	end
	return t, ix, iz, ax, az
end

-- Release now? When the predicted impact is within half a tick of travel of
-- the aim point along the track, and close enough across it.
function Air.bombRelease(sim: Types.Sim, id: number, weapon: Defs.WeaponDef, target: number, kx: number, kz: number, defIndex: number?): boolean
	local w = sim.world
	local _, ix, iz, ax, az = Air.bombSolution(sim, id, weapon, target, kx, kz, defIndex)
	local h, v = w.heading[id], w.speed[id]
	local fx, fz = math.sin(h), math.cos(h)
	local dx, dz = ax - ix, az - iz
	local along = dx * fx + dz * fz
	local across = math.abs(dx * fz - dz * fx)
	local half = v * Air.DT / 2 + 0.5
	local tolerance = math.max((weapon.aoe or 0) * 0.5, 3) + (if defIndex then sim.combat.profiles[defIndex].radius else 0)
	return along <= half and along > -half and across <= tolerance
end

-- A bomb just left `id`: fly straight out, then set up the next run.
function Air.onBombRelease(sim: Types.Sim, id: number)
	sim.air.run[id] = "out"
	sim.air.egressUntil[id] = sim.tick + Air.EGRESS_TICKS
end

-- New aircraft: cruising altitude, full ammo, current spot as resume point;
-- jets already at minimum speed.
function Air.onSpawn(sim: Types.Sim, id: number)
	local d = def(sim, id)
	if d.domain ~= "air" then
		return
	end
	local w = sim.world
	local a = sim.air
	w.alt[id] = cruiseAltitude(sim, d)
	a.phase[id] = "fly"
	a.ammo[id] = d.ammo
	a.pad[id] = 0
	a.padGen[id] = 0
	a.progress[id] = 0
	a.resumeX[id], a.resumeZ[id] = w.posX[id], w.posZ[id]
	if d.moveClass == "JET" and d.movement and d.movement.minSpeed then
		w.speed[id] = d.movement.minSpeed -- jets are born flying: never parked in the air
	end
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

-- Out of ammo: remember where we were going, head for a pad: its home base
-- if it has one (S-36), else the nearest.
function Air.onEmpty(sim: Types.Sim, id: number)
	local a = sim.air
	if a.phase[id] ~= "fly" then
		return
	end
	local w = sim.world
	a.resumeX[id], a.resumeZ[id] = w.goalX[id], w.goalZ[id]
	local pad = if World.isRef(w, a.home[id] or 0, a.homeGen[id]) then a.home[id] :: number else nearestPad(sim, id)
	if pad == 0 then
		return -- nowhere to rearm: keep flying empty
	end
	a.phase[id] = "return"
	a.pad[id] = pad
	a.padGen[id] = w.gen[pad]
	headTo(sim, id, w.posX[pad], w.posZ[pad])
end

--------------------------------------------------------------------------------
-- Carriers and home bases (guide 12.3, S-36)
--------------------------------------------------------------------------------

local function takeOff(sim: Types.Sim, id: number)
	local a = sim.air
	local w = sim.world
	a.phase[id] = "fly"
	a.pad[id] = 0
	a.padGen[id] = 0
	a.progress[id] = 0
	World.setState(w, id, bit32.band(w.state[id], bit32.bnot(LANDED)))
	local d = def(sim, id)
	if d.movement and d.movement.minSpeed then
		w.speed[id] = d.movement.minSpeed
	end
end

-- Recovers aircraft `id` to `pad`, a friendly carrier or airfield (anything
-- with rearmPads): it becomes its home base, and the aircraft flies there,
-- lands, rearms and stays docked (moving with a carrier) until an order
-- launches it. False when `pad` can't take it.
function Air.recover(sim: Types.Sim, id: number, pad: number): boolean
	local a = sim.air
	local w = sim.world
	if a.phase[id] == nil or w.slot[pad] == nil or w.team[pad] ~= w.team[id] or w.buildProgress[pad] < 1 or not def(sim, pad).rearmPads then
		return false
	end
	a.home[id], a.homeGen[id] = pad, w.gen[pad]
	a.hold[id] = true
	if a.phase[id] == "fly" then
		a.resumeX[id], a.resumeZ[id] = w.posX[id], w.posZ[id]
		a.phase[id] = "return"
		a.pad[id] = pad
		a.padGen[id] = w.gen[pad]
		headTo(sim, id, w.posX[pad], w.posZ[pad])
	end
	return true
end

-- An order for aircraft `id` (Orders.give): a docked aircraft launches, one
-- flying home only to be recovered turns back to fly; an empty one still
-- rearms first.
function Air.release(sim: Types.Sim, id: number)
	local a = sim.air
	if a.phase[id] == nil then
		return
	end
	a.hold[id] = nil
	local d = def(sim, id)
	local empty = d.ammo ~= nil and (a.ammo[id] or 0) <= 0
	if a.phase[id] == "docked" or (a.phase[id] == "return" and not empty) then
		takeOff(sim, id)
	end
end

-- Does this def carry a manualFire weapon (a nuke silo, S-48)? Cached per def.
local manualCache: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
function Air.isManualFire(sim: Types.Sim, d: Defs.UnitDef): boolean
	local cached = manualCache[d]
	if cached == nil then
		cached = false
		for _, slot in d.weapons do
			if sim.defs.weaponByIndex[slot.weaponIndex].manualFire then
				cached = true
			end
		end
		manualCache[d] = cached
	end
	return cached
end

-- Attack-ground order (D100): bombers make runs on (x, z) until another
-- order replaces it; a unit with a manualFire weapon (a silo, S-48) fires
-- one shot there, then the order is done. Other units ignore it. The point
-- is kept here (AirState.groundX / groundZ) for both.
function Air.attackGround(sim: Types.Sim, id: number, x: number, z: number)
	if not Air.isBomber(sim, def(sim, id)) then
		if Air.isManualFire(sim, def(sim, id)) then
			sim.air.groundX[id], sim.air.groundZ[id] = x, z
		end
		return
	end
	local a = sim.air
	a.groundX[id], a.groundZ[id] = x, z
	a.run[id] = nil
	World.setTarget(sim.world, World.slotKey(id, 1), 0)
end

function Air.clearGround(sim: Types.Sim, id: number)
	local a = sim.air
	if a.groundX[id] ~= nil then
		a.groundX[id], a.groundZ[id] = nil, nil
		a.run[id] = nil
	end
end

-- What a bomber is bombing: (target ID or 0 for the ground, believed x, z,
-- def index or nil for the ground), or nil when it has nothing.
function Air.bombAim(sim: Types.Sim, id: number): (number?, number?, number?, number?)
	local a = sim.air
	if a.groundX[id] ~= nil then
		return 0, a.groundX[id], a.groundZ[id], nil
	end
	local w = sim.world
	local key = World.slotKey(id, 1)
	local target = if w.weaponCount[id] > 0 then w.wTarget[key] else 0
	if target == 0 then
		return nil
	end
	local kx, kz, _, defIndex = Sensors.knownTarget(sim, w.ally[id], target, w.wTargetGen[key])
	if kx == nil then
		return nil
	end
	return target, kx, kz, defIndex
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
	if phase == "rearm" or phase == "docked" then
		return h, 0 -- parked on its pad
	end
	local nav = sim.nav :: Nav.Nav
	local tx, tz = w.goalX[id], w.goalZ[id]
	local loiter = true
	if phase == "return" and World.isRef(w, a.pad[id], a.padGen[id]) then
		local pad = a.pad[id]
		tx, tz, loiter = w.posX[pad], w.posZ[pad], false
	else
		local isBomber = Air.isBomber(sim, def(sim, id))
		local target, kx, kz, defIndex = 0, nil, nil, nil
		if a.ammo[id] == nil or a.ammo[id] > 0 then
			if isBomber then
				local t: number?, x: number?, z: number?, d: number? = Air.bombAim(sim, id)
				target, kx, kz, defIndex = t or 0, x, z, d
			else
				local key = World.slotKey(id, 1)
				target = if w.weaponCount[id] > 0 then w.wTarget[key] else 0
				if target ~= 0 then
					kx, kz = Sensors.knownTarget(sim, w.ally[id], target, w.wTargetGen[key])
				end
			end
		end
		if kx and kz and isBomber then
			-- bomb run (D91): line up on the aim point from far enough out
			-- to release, fly away after a drop or a missed window
			loiter = false
			local weapon = sim.defs.weaponByIndex[def(sim, id).weapons[1].weaponIndex]
			local t, _, _, ax, az = Air.bombSolution(sim, id, weapon, target, kx, kz, defIndex)
			local lead = math.max(v, p.minSpeed or 0) * t
			local dist = sqrt((ax - x) ^ 2 + (az - z) ^ 2)
			local run = a.run[id] or "in"
			if sim.tick < (a.egressUntil[id] or 0) then
				tx, tz = x + math.sin(h) * 100, z + math.cos(h) * 100 -- straight on
			elseif run == "out" then
				tx, tz = x + (x - ax), z + (z - az) -- away from the target
				if dist >= lead + Air.RUN_IN then
					a.run[id] = "in"
				end
			else
				tx, tz = ax, az
				if dist < lead * 0.6 then
					a.run[id] = "out" -- missed the window: go round again
				end
			end
		elseif kx and kz then
			tx, tz, loiter = kx, kz, false -- chase; overshoot and come around
		elseif a.run[id] ~= nil then
			a.run[id] = nil -- target gone: the next run starts fresh
			if w.orderId[id] ~= 0 and sqrt((tx - x) ^ 2 + (tz - z) ^ 2) > Air.LOITER_RADIUS then
				loiter = false
			end
		elseif w.orderId[id] ~= 0 then
			-- fly to the goal itself; arrived within ARRIVE_RADIUS, or when it
			-- falls behind after the jet flew toward it (a goal inside the
			-- turn circle: the closest approach), then circle it (request 17)
			local dist = sqrt((tx - x) ^ 2 + (tz - z) ^ 2)
			local ahead = math.sin(h) * (tx - x) + math.cos(h) * (tz - z) > 0
			if ahead then
				a.approach[id] = w.orderId[id]
			end
			if dist <= Air.ARRIVE_RADIUS or (not ahead and a.approach[id] == w.orderId[id] and dist <= Air.LOITER_RADIUS) then
				Nav.clearOrder(nav, w, id) -- arrived: circle the goal from now on
				a.approach[id] = nil
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
	local phase = sim.air.phase[id]
	local target = if phase == "rearm" or phase == "docked" then 0 else cruiseAltitude(sim, d)
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
		if a.phase[id] == "rearm" or a.phase[id] == "docked" then
			padLoad[a.pad[id]] = (padLoad[a.pad[id]] or 0) + 1
		end
	end

	for _, id in w.ids do
		local phase = a.phase[id]
		if phase == "return" then
			local pad = a.pad[id]
			if not World.isRef(w, pad, a.padGen[id]) then
				pad = nearestPad(sim, id) -- pad destroyed (its ID may be another unit's now): try another
				a.pad[id] = pad
				a.padGen[id] = w.gen[pad] or 0
				if pad == 0 then
					a.phase[id] = "fly"
					continue
				end
				headTo(sim, id, w.posX[pad], w.posZ[pad])
			end
			local d = def(sim, id)
			local reach = Air.LAND_RADIUS[d.moveClass or "HELI"] or 12
			local dist = sqrt((w.posX[pad] - w.posX[id]) ^ 2 + (w.posZ[pad] - w.posZ[id]) ^ 2)
			if dist > reach * 2 and w.orderId[id] == 0 then
				headTo(sim, id, w.posX[pad], w.posZ[pad]) -- the pad moved (a carrier): follow it
			end
			if dist <= reach and (padLoad[pad] or 0) < (def(sim, pad).rearmPads or 1) then
				-- land on the pad
				padLoad[pad] = (padLoad[pad] or 0) + 1
				a.phase[id] = "rearm"
				a.progress[id] = 0
				local rounds = math.max((def(sim, id).ammo or 1) - (a.ammo[id] or 0), 1)
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
		elseif phase == "docked" then
			-- held on its home pad: ride along with a carrier (S-36)
			local pad = a.pad[id]
			if not World.isRef(w, pad, a.padGen[id]) then
				takeOff(sim, id) -- the carrier is gone
				a.hold[id] = nil
				continue
			end
			if w.posX[id] ~= w.posX[pad] or w.posZ[id] ~= w.posZ[pad] then
				World.setPosition(w, id, w.posX[pad], w.posZ[pad])
				w.goalX[id], w.goalZ[id] = w.posX[pad], w.posZ[pad]
			end
		elseif phase == "rearm" then
			local d = def(sim, id)
			local pad = a.pad[id]
			if not World.isRef(w, pad, a.padGen[id]) then
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
			if pad ~= 0 and World.isRef(w, pad, a.padGen[id]) and (w.posX[id] ~= w.posX[pad] or w.posZ[id] ~= w.posZ[pad]) then
				World.setPosition(w, id, w.posX[pad], w.posZ[pad]) -- a carrier carries it along (S-36)
				w.goalX[id], w.goalZ[id] = w.posX[pad], w.posZ[pad]
			end
			if d.ammo == nil or a.ammo[id] >= (d.ammo :: number) then
				-- full. The last fraction of a charge is already paid, so top the
				-- countermeasures up.
				EW.refill(sim, id)
				a.cmPerRound[id], a.cmSupplyPerRound[id], a.cmProgress[id] = nil, nil, nil
				if a.hold[id] and pad == a.home[id] then
					a.phase[id] = "docked" -- recovered: stay until launched (S-36)
					a.progress[id] = 0
				else
					takeOff(sim, id) -- and go back
					headTo(sim, id, a.resumeX[id], a.resumeZ[id])
				end
			end
		end
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	AirState.clearUnit(sim.air, id)
end)

return Air

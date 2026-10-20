--!strict
-- System 7: aim model and fire control (guide 10.3–10.4).
--
-- Each weapon has a yaw (relative to the hull) and a pitch that rotate toward
-- the target at the turret's yawRate / pitchRate. A weapon fires when it is
-- reloaded, within `tolerance` degrees on both axes, the needed pitch is
-- within [minPitch, maxPitch] (and ballistically reachable) and the target is
-- in range. Without a target the turret returns to its rest position.
-- Turret speed is therefore real gameplay; animation only displays it.
--
-- Spread: each shot draws yaw and pitch errors uniformly in ±accuracy
-- degrees from sim.rng, in system order, so replays stay exact.
--   HITSCAN / BEAM: resolved now. Hit if the shot passes within the target's
--     radius sideways and its half-height vertically at the target distance.
--   BALLISTIC / BOMB (and HOMING / TORPEDO until guidance exists, M7): spawn a
--     projectile from the muzzle. If the pool is full the shot resolves like
--     hitscan (guide 10.5 cap).

local Ballistics = require("../Combat/Ballistics")
local Combat = require("../Combat/Combat")
local Defs = require("@shared/Defs/Defs")
local Types = require("../Types")
local World = require("../World")

local DT = 1 / 15
local sqrt, sin, cos, tan, atan2, abs, rad = math.sqrt, math.sin, math.cos, math.tan, math.atan2, math.abs, math.rad
local max, min = math.max, math.min
local PI, TAU = math.pi, 2 * math.pi
local HOLD_FIRE = World.FireState.HOLD_FIRE

local function wrapAngle(a: number): number
	a = a % TAU
	if a > PI then
		a -= TAU
	end
	return a
end

local function rotateToward(current: number, target: number, maxStep: number): number
	local diff = wrapAngle(target - current)
	return wrapAngle(current + max(-maxStep, min(maxStep, diff)))
end

-- Hitscan-style resolution: does a shot with these errors hit target t?
local function hitscanHits(
	c: Combat.Combat,
	w: World.World,
	t: number,
	dist: number,
	yawErr: number,
	pitchErr: number
): boolean
	local tp = c.profiles[w.defIndex[t]]
	local lateral = dist * abs(sin(yawErr))
	local vertical = dist * abs(tan(pitchErr))
	return lateral <= tp.radius and vertical <= tp.height / 2
end

local function fire(
	sim: Types.Sim,
	id: number,
	slot: number,
	weapon: Defs.WeaponDef,
	target: number,
	worldYaw: number, -- the turret's actual aim, before spread
	pitch: number,
	muzzleY: number,
	dist: number,
	exactYaw: number, -- true direction / pitch to the target's center
	exactPitch: number
)
	local c = sim.combat
	local w = sim.world
	local acc = rad(weapon.accuracy or 0)
	local yawErr = if acc > 0 then sim.rng:nextNumber(-acc, acc) else 0
	local pitchErr = if acc > 0 then sim.rng:nextNumber(-acc, acc) else 0
	c.stats.shots += 1
	local wtype = weapon.type

	local projectile: number? = nil
	if wtype ~= "HITSCAN" and wtype ~= "BEAM" then
		local speed = weapon.projectileSpeed or 0
		local yaw, p = worldYaw + yawErr, pitch + pitchErr
		local ttl = 2 * weapon.range / math.max(speed, 1) + 1
		projectile = Combat.spawnProjectile(
			c,
			w.posX[id],
			muzzleY,
			w.posZ[id],
			cos(p) * sin(yaw) * speed,
			sin(p) * speed,
			cos(p) * cos(yaw) * speed,
			weapon.index,
			id,
			w.team[id],
			ttl
		)
		if projectile then
			Combat.addEvent(c, { kind = "SPAWN_PROJ", tick = sim.tick, unit = id, other = projectile, slot = slot })
			return
		end
	end

	-- hitscan, or a projectile shot at the pool cap: the total error is the
	-- turret's remaining aim offset (within tolerance) plus the spread
	local hit = hitscanHits(c, w, target, dist, wrapAngle(worldYaw + yawErr - exactYaw), pitch + pitchErr - exactPitch)
	Combat.addEvent(c, { kind = "FIRE", tick = sim.tick, unit = id, other = target, slot = slot, hit = hit })
	local tx, tz = w.posX[target], w.posZ[target]
	if hit then
		c.stats.hits += 1
		local tp = c.profiles[w.defIndex[target]]
		Combat.explode(c, w, tx, Combat.unitBase(c, w, target) + tp.height / 2, tz, weapon, id, w.team[id], target)
	elseif (weapon.aoe or 0) > 0 then
		-- a miss still explodes on the ground beyond/beside the target
		local mx = w.posX[id] + sin(worldYaw + yawErr) * dist
		local mz = w.posZ[id] + cos(worldYaw + yawErr) * dist
		Combat.explode(c, w, mx, Combat.groundHeight(c, mx, mz), mz, weapon, id, w.team[id], 0)
	end
end

return function(sim: Types.Sim)
	local c = sim.combat
	local w = sim.world
	local profiles = c.profiles

	for _, id in w.ids do
		local count = w.weaponCount[id]
		if count == 0 then
			continue
		end
		local p = profiles[w.defIndex[id]]
		local x, z, heading = w.posX[id], w.posZ[id], w.heading[id]
		local muzzleY = Combat.unitBase(c, w, id) + p.muzzleHeight
		local holdFire = w.fireState[id] == HOLD_FIRE

		for slot = 1, count do
			local key = id * 8 + slot - 1
			local weapon = p.weapons[slot]
			local turret = weapon.turret
			local reload = w.wReload[key]
			if reload > 0 then
				reload -= DT
				w.wReload[key] = reload
			end

			local target = w.wTarget[key]
			local wantYaw, wantPitch = 0, 0
			local canFire = false
			local dist, worldYaw = 0, 0
			if target ~= 0 and w.slot[target] ~= nil then
				local tp = profiles[w.defIndex[target]]
				local dx, dz = w.posX[target] - x, w.posZ[target] - z
				dist = sqrt(dx * dx + dz * dz)
				worldYaw = atan2(dx, dz)
				wantYaw = wrapAngle(worldYaw - heading)
				local dy = Combat.unitBase(c, w, target) + tp.height / 2 - muzzleY
				local pitch: number?
				if weapon.type == "HITSCAN" or weapon.type == "BEAM" then
					pitch = atan2(dy, dist)
				else
					pitch = Ballistics.launchPitch(weapon.projectileSpeed or 1, weapon.gravity or 0, dist, dy)
				end
				canFire = not holdFire and dist <= weapon.range + tp.radius
				if pitch == nil then
					canFire = false
					wantPitch = if turret then rad(turret.maxPitch) else 0
				else
					wantPitch = pitch
					if turret and (pitch < rad(turret.minPitch) or pitch > rad(turret.maxPitch)) then
						canFire = false
					end
				end
			end

			-- rotate the turret (fixed mounts without a turret table aim instantly)
			local yaw, pitchNow = w.wYaw[key], w.wPitch[key]
			if turret then
				yaw = rotateToward(yaw, wantYaw, rad(turret.yawRate) * DT)
				if turret.arc < 360 then
					local half = rad(turret.arc) / 2
					yaw = max(-half, min(half, yaw))
				end
				local minP, maxP = rad(turret.minPitch), rad(turret.maxPitch)
				local step = rad(turret.pitchRate) * DT
				pitchNow = max(minP, min(maxP, pitchNow + max(-step, min(step, max(minP, min(maxP, wantPitch)) - pitchNow))))
			else
				yaw, pitchNow = wantYaw, wantPitch
			end
			if yaw ~= w.wYaw[key] or pitchNow ~= w.wPitch[key] then
				w.wYaw[key] = yaw
				w.wPitch[key] = pitchNow
				w.dirty[id] = bit32.bor(w.dirty[id], World.Dirty.STATE)
			end

			if canFire and reload <= 0 then
				local tol = rad(if turret then turret.tolerance else 0)
				if abs(wrapAngle(wantYaw - yaw)) <= tol and abs(wantPitch - pitchNow) <= tol then
					-- Fire along the turret's actual aim; keep fractional reload
					-- carry while firing continuously, never bank more than one tick.
					w.wReload[key] = weapon.reload + max(reload, -DT)
					fire(sim, id, slot, weapon, target, heading + yaw, pitchNow, muzzleY, dist, worldYaw, wantPitch)
				end
			end
		end
	end
end

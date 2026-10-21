--!strict
-- System 7: aim model and fire control (guide 10.3–10.4).
--
-- Each weapon has a yaw (relative to the hull) and a pitch that rotate toward
-- the target at the turret's yawRate / pitchRate. A weapon fires when it is
-- reloaded, within `tolerance` degrees on both axes, the needed pitch is
-- within [minPitch, maxPitch] (and ballistically reachable) and the target is
-- in range. Without a target the turret keeps its aim for the turret's
-- restoreDelay, then returns to its rest pose (Shared/Combat/Aim, S-20).
-- Turret speed is therefore real gameplay; animation only displays it.
--
-- Spread: each shot draws yaw and pitch errors uniformly in ±accuracy
-- degrees from sim.rng, in system order, so replays stay exact.
--   HITSCAN / BEAM: resolved now. Hit if the shot passes within the target's
--     radius sideways and its half-height vertically at the target distance.
--   BALLISTIC / BOMB / HOMING / TORPEDO: spawn a projectile from the muzzle.
--     If the pool is full the shot resolves like hitscan (guide 10.5 cap).
--   BOMB: no turret; released when the bomb's predicted impact meets the
--     target's predicted position (Air.bombRelease); the bomb leaves with the
--     bomber's velocity and falls (guide 10.5, DECISIONS D91).
-- Guided missiles launch only with a lock (EW.canLock, guide 11.5).
-- Overkill (S-29, guide 10.2): a weapon doesn't fire at a visible target that
-- damage already on its way will kill (Combat.doomed: projectiles in flight
-- at it, damage queued this tick); it drops the target and Targeting
-- searches for another on the next tick. So a group's volley spreads over
-- several targets. Attack orders, and a doomed target with nothing else in
-- reach (Targeting marks it ALLOWED), still get fired at.
-- Line of fire (S-32, guide 10.8): hitscan, beams and ballistic shells fire
-- only when the shot clears the terrain (Combat.lineOfFire); otherwise the
-- weapon is marked blocked (World.wBlocked) and holds.

local Aim = require("@shared/Combat/Aim")
local Air = require("../Air")
local Ballistics = require("../Combat/Ballistics")
local Combat = require("../Combat/Combat")
local Defs = require("@shared/Defs/Defs")
local EW = require("../EW")
local Sensors = require("../Sensors")
local Stockpile = require("../Stockpile")
local Types = require("../Types")
local World = require("../World")

local DT = 1 / 15
local sqrt, sin, cos, tan, atan2, abs, rad = math.sqrt, math.sin, math.cos, math.tan, math.atan2, math.abs, math.rad
local max, min = math.max, math.min
local PI, TAU = math.pi, 2 * math.pi
local HOLD_FIRE = World.FireState.HOLD_FIRE
local VISIBLE = Sensors.Level.VISIBLE
local OK_RETARGET, OK_ALLOWED = World.Overkill.RETARGET, World.Overkill.ALLOWED
local aimState: Aim.State = { yaw = 0, pitch = 0, hold = 0 } -- scratch, reused for every weapon

local function wrapAngle(a: number): number
	a = a % TAU
	if a > PI then
		a -= TAU
	end
	return a
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
		local launchY = muzzleY
		local vx, vy, vz = cos(p) * sin(yaw) * speed, sin(p) * speed, cos(p) * cos(yaw) * speed
		if weapon.launch == "vertical" then
			vx, vy, vz = 0, speed, 0 -- straight up; guidance pitches it over (S-42)
		elseif wtype == "TORPEDO" then
			p = 0
			launchY = Combat.surfaceHeight(c, w.posX[id], w.posZ[id]) - Combat.TORPEDO_DEPTH
			vx, vy, vz = sin(yaw) * speed, 0, cos(yaw) * speed
		elseif wtype == "BOMB" then
			-- zero launch speed: the bomb keeps the bomber's velocity (spread on its heading)
			local h, v = w.heading[id] + yawErr, w.speed[id]
			vx, vy, vz = sin(h) * v, 0, cos(h) * v
			ttl = 8
			Air.onBombRelease(sim, id)
		end
		projectile = Combat.spawnProjectile(
			c,
			w.posX[id],
			launchY,
			w.posZ[id],
			vx,
			vy,
			vz,
			weapon.index,
			id,
			w.ally[id], -- projectile side: allies are never hit directly
			ttl,
			if wtype == "HOMING" or wtype == "TORPEDO" then target else 0,
			w,
			w.wTargetGen[World.slotKey(id, slot)]
		)
		if projectile then
			Combat.addEvent(c, { kind = "SPAWN_PROJ", tick = sim.tick, unit = id, other = projectile, slot = slot })
			if World.isRef(w, target, w.wTargetGen[World.slotKey(id, slot)]) then
				-- the damage it is expected to deal (S-29)
				local tp = c.profiles[w.defIndex[target]]
				Combat.addPending(c, w, projectile, target, weapon.damage[tp.armorClass] * Combat.hitChance(weapon, tp, dist))
			end
			return
		end
	end

	-- hitscan, or a projectile shot at the pool cap: the total error is the
	-- turret's remaining aim offset (within tolerance) plus the spread
	local hit = hitscanHits(c, w, target, dist, wrapAngle(worldYaw + yawErr - exactYaw), pitch + pitchErr - exactPitch)
	-- where the shot ends: the target's aim point, or the ground beyond or
	-- beside it on a miss (FIRE carries it for clients, guide 7.3)
	local ex, ey, ez
	if hit then
		ex, ey, ez = Combat.aimPoint(c, w, target)
	else
		ex = w.posX[id] + sin(worldYaw + yawErr) * dist
		ez = w.posZ[id] + cos(worldYaw + yawErr) * dist
		ey = Combat.groundHeight(c, ex, ez)
	end
	Combat.addEvent(c, { kind = "FIRE", tick = sim.tick, unit = id, other = target, slot = slot, hit = hit, x = ex, y = ey, z = ez, sx = w.posX[id], sy = muzzleY, sz = w.posZ[id] })
	if hit then
		c.stats.hits += 1
		Combat.explode(c, w, ex, ey, ez, weapon, id, w.ally[id], target)
	elseif (weapon.aoe or 0) > 0 then
		-- a miss still explodes on the ground beyond/beside the target
		Combat.explode(c, w, ex, ey, ez, weapon, id, w.ally[id], 0)
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
		local submerged = bit32.band(w.state[id], World.State.SUBMERGED) ~= 0
		-- an attack order (Orders) fires even on hold fire
		local holdFire = w.fireState[id] == HOLD_FIRE and sim.orders.forced[id] == nil

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
			local targetGen = w.wTargetGen[key]
			local wantYaw, wantPitch = 0, 0
			local canFire = false
			local dist, worldYaw = 0, 0
			-- Aim at where the team believes the target is (D100): the true
			-- position when visible, the wobbled one for radar contacts (guide
			-- 11.4), the ghost's for remembered structures (alive or not), the
			-- ordered spot for a bomber's attack-ground.
			local kx, kz, defIndex = nil, nil, nil
			if weapon.type == "BOMB" and sim.air.groundX[id] ~= nil then
				target, kx, kz = 0, sim.air.groundX[id], sim.air.groundZ[id]
			elseif target ~= 0 then
				local level
				kx, kz, level, defIndex = Sensors.knownTarget(sim, w.ally[id], target, targetGen)
				if kx ~= nil and not Sensors.typeKnown(sim, w.ally[id], target, level) then
					defIndex = nil -- an untracked blip's size is unknown (D107)
				end
			end
			local exactYaw, exactPitch = 0, 0
			local aimed = kx ~= nil and kz ~= nil
			if kx ~= nil and kz ~= nil then
				local radius = if defIndex then profiles[defIndex].radius else 0
				local dx, dz = kx - x, kz - z
				dist = sqrt(dx * dx + dz * dz)
				worldYaw = atan2(dx, dz)
				wantYaw = wrapAngle(worldYaw - heading)
				local _, aimY = Combat.knownAimPoint(c, w, target, defIndex, kx, kz) -- at the believed position
				local dy = aimY - muzzleY
				-- the true direction, for judging hitscan hits (only live targets are hit-checked)
				exactYaw, exactPitch = worldYaw, atan2(dy, dist)
				if World.isRef(w, target, targetGen) then
					local tx, tz = w.posX[target] - x, w.posZ[target] - z
					local trueDist = sqrt(tx * tx + tz * tz)
					exactYaw = atan2(tx, tz)
					local _, trueY = Combat.aimPoint(c, w, target)
					exactPitch = atan2(trueY - muzzleY, trueDist)
				end
				local pitch: number?
				if weapon.type == "HITSCAN" or weapon.type == "BEAM" then
					pitch = atan2(dy, dist)
				elseif weapon.type == "TORPEDO" then
					pitch = 0 -- launched level in the water; homing does the rest
				elseif weapon.type == "BOMB" then
					pitch = 0 -- dropped, not aimed
				else
					pitch = Ballistics.launchPitch(weapon.projectileSpeed or 1, weapon.gravity or 0, dist, dy)
				end
				canFire = not holdFire and dist <= weapon.range + radius
				if pitch == nil then
					canFire = false
					wantPitch = if turret then rad(turret.maxPitch) else 0
				else
					wantPitch = pitch
					if turret and (pitch < rad(turret.minPitch) or pitch > rad(turret.maxPitch)) then
						canFire = false
					end
				end
				if weapon.type == "BOMB" then
					canFire = not holdFire and Air.bombRelease(sim, id, weapon, target, kx, kz, defIndex)
				end
				if canFire and weapon.guidance and not EW.canLock(sim, id, weapon, target, dist) then
					canFire = false -- no lock, no launch
				end
				if canFire and submerged and weapon.type ~= "TORPEDO" then
					canFire = false -- under water only torpedoes fire (amphibious units, S-39)
				end
				if canFire and not Stockpile.ready(w, key) then
					canFire = false -- nothing in stock (S-47)
				end
			end

			-- rotate the turret (fixed mounts without a turret table aim
			-- instantly); without a target: hold, then back to rest
			aimState.yaw, aimState.pitch, aimState.hold = w.wYaw[key], w.wPitch[key], w.wHold[key]
			if aimed and weapon.launch ~= "vertical" then -- vertical launchers stay at rest (S-42)
				Aim.update(turret, aimState, wantYaw, wantPitch)
			else
				Aim.update(turret, aimState, nil, nil)
			end
			if Aim.observer then
				Aim.observer(key, if aimed then wantYaw else nil, if aimed then wantPitch else nil)
			end
			local yaw, pitchNow = aimState.yaw, aimState.pitch
			w.wHold[key] = aimState.hold
			if yaw ~= w.wYaw[key] or pitchNow ~= w.wPitch[key] then
				w.wYaw[key] = yaw
				w.wPitch[key] = pitchNow
				w.dirty[id] = bit32.bor(w.dirty[id], World.Dirty.STATE)
			end

			-- overkill (S-29): hits already on the way will kill a target the team
			-- sees; leave it to them and look for another (unless ordered, or
			-- nothing else is in reach)
			if
				canFire
				and reload <= 0
				and w.wOverkill[key] ~= OK_ALLOWED
				and sim.orders.forced[id] ~= target
				and World.isRef(w, target, targetGen)
				and Combat.doomed(c, w, target)
				and Sensors.level(sim, w.ally[id], target) == VISIBLE
			then
				World.setTarget(w, key, 0)
				w.wOverkill[key] = OK_RETARGET
				canFire = false
			end

			if canFire and reload <= 0 then
				local tol = rad(if turret then turret.tolerance else 0)
				-- vertical launchers need no aim: in range and locked is enough (S-42)
				local onTarget = weapon.launch == "vertical" or (abs(wrapAngle(wantYaw - yaw)) <= tol and abs(wantPitch - pitchNow) <= tol)
				-- line of fire (S-32): terrain in the way, no shot; Targeting
				-- looks for a clear target, attack-moves go on (Orders)
				if onTarget and kx ~= nil and kz ~= nil then
					local clear = Combat.unitLineOfFire(c, w, id, weapon, target, defIndex, kx, kz)
					w.wBlocked[key] = if clear then 0 else 1
					onTarget = clear
				end
				if onTarget and Air.useAmmo(sim, id) then
					-- Fire along the turret's actual aim; keep fractional reload
					-- carry while firing continuously, never bank more than one tick.
					w.wReload[key] = weapon.reload + max(reload, -DT)
					Stockpile.take(w, key)
					fire(sim, id, slot, weapon, target, heading + yaw, pitchNow, muzzleY, dist, exactYaw, exactPitch)
				end
			end
		end
	end
end

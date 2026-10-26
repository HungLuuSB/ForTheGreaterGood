--!strict
-- System 8: step projectiles, collide, impact (guide 10.5).
--
-- Exact ballistic step per tick, then a swept test of the tick's chord
-- against unit cylinders (enemies only: direct hits never hit allies, guide
-- 10.6) and against the terrain. The test runs in each unit's frame of
-- reference (the chord minus the unit's own motion this tick), so fast jets
-- can't slip between ticks either. The earliest contact is the impact; an
-- explosion applies direct and AoE damage. Projectiles expire after their
-- ttl: they burst harmlessly (an IMPACT with no unit and no damage, guide
-- 10.5 "expired homing missiles self-destruct"), so clients drop them too.
-- A projectile leaving the map bursts at the edge the same way.
--
-- HOMING / TORPEDO projectiles turn toward their target at most the weapon's
-- turnRate (deg/s) before each step: missiles by proportional navigation,
-- torpedoes by lead pursuit (Shared/Combat/Guidance, S-27; D97). HOMING
-- missiles also carry a proximity fuse: they burst at the closest approach
-- to their target when it is within their fuseRange (default: aoe) of the
-- hull; the burst damages the target by its distance over fuseRange and
-- others by AoE, and its IMPACT names the target. Guided missiles first run
-- their midcourse and terminal checks (EW.guide, guide 11.5), which may
-- break the lock or decoy them.
--
-- Strategic missiles (S-48) pass over units (only the ground stops them) and
-- their blast hurts every side. Interceptors steer at their strategic
-- missile by proportional navigation against its position and velocity, and
-- burst at the closest approach within their fuse (aoe) of it: the burst
-- destroys it with the weapon's `intercepts.chance` (sim Prng). A destroyed
-- missile is removed after the loop (removing another projectile mid-loop
-- would move an unprocessed one) with an INTERCEPTED event, no blast.

local Ballistics = require("../Combat/Ballistics")
local Guidance = require("@shared/Combat/Guidance")
local Grid = require("@shared/Grid/Grid")
local Lofted = require("@shared/Combat/Lofted")
local Combat = require("../Combat/Combat")
local ContactGrid = require("../Combat/ContactGrid")
local EW = require("../EW")
local Shield = require("../Shield")
local Types = require("../Types")
local World = require("../World")

local DT = 1 / 15
local LAUNCH_TICKS = 8 -- a radar missile's launch phase without a vertical climb (S-146)
local POINT_FUSE = 4 -- studs: a missile without a blast radius bursts this close to its spot
local TURNED = EW.Flag.TURNED
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

local candidates: { number } = {}
local killed: { number } = {}
-- start-of-tick state of the projectiles interceptors chase (S-151, client
-- request: steering and the fuse mustn't depend on which steps first)
local chasedState: { [number]: { number } } = {}

return function(sim: Types.Sim)
	local c = sim.combat
	local proj = c.proj
	if #proj == 0 then
		return
	end
	local w = sim.world
	ContactGrid.rebuild(c.contacts, w) -- positions changed in Movement
	local weapons = sim.defs.weaponByIndex
	local profiles = c.profiles

	table.clear(chasedState)
	for _, id in proj do
		local t = c.pTargetProj[id]
		if t ~= nil and t ~= 0 and chasedState[t] == nil and c.projSlot[t] ~= nil then
			chasedState[t] = { c.px[t], c.py[t], c.pz[t], c.pvx[t], c.pvy[t], c.pvz[t] }
		end
	end

	-- Backwards, so swap-removal never skips an unprocessed projectile.
	table.clear(killed)
	for k = #proj, 1, -1 do
		local id = proj[k]
		if table.find(killed, id) then
			continue -- intercepted this tick: removed below
		end
		local weapon = weapons[c.pWeapon[id]]
		local g = weapon.gravity or 0
		if weapon.guidance then
			EW.guide(sim, id, weapon)
		end
		local x0, y0, z0 = c.px[id], c.py[id], c.pz[id]
		local pvx, pvy, pvz = c.pvx[id], c.pvy[id], c.pvz[id]
		local homingTarget = c.pTarget[id]
		local projTarget = c.pTargetProj[id]
		if projTarget ~= 0 and not Combat.isProjRef(c, projTarget, c.pTargetSerial[id]) then
			projTarget = 0 -- it detonated or was destroyed: fly on
		end
		-- radar missiles (S-146): remember where the target was; once it is
		-- gone, fly to that spot if it died in the launch phase, else spiral
		local radar = weapon.type == "HOMING" and weapon.guidance == "RADAR" and projTarget == 0
		if radar then
			c.pAge[id] = (c.pAge[id] or 0) + 1
			if World.isRef(w, homingTarget, c.pTargetGen[id]) then
				local kx, ky, kz = Combat.aimPoint(c, w, homingTarget)
				c.pKnownX[id], c.pKnownY[id], c.pKnownZ[id] = kx, ky, kz
			elseif c.pPoint[id] == nil and c.pLost[id] == nil and c.pDecoy[id] == nil and (homingTarget ~= 0 or c.pKnownX[id] ~= nil) then
				-- (one fired without a target, never tracking one, flies on straight)
				local launching = if weapon.launch == "vertical"
					then bit32.band(c.pFlags[id], TURNED) == 0
					else c.pAge[id] <= LAUNCH_TICKS
				if homingTarget ~= 0 and launching and c.pKnownX[id] then
					-- died before the missile turned onto it: its last known spot
					c.pPoint[id] = { c.pKnownX[id], c.pKnownY[id] :: number, c.pKnownZ[id] :: number }
				else
					c.pLost[id] = 0
					if homingTarget ~= 0 then
						-- (a broken lock already sent its LOST_LOCK from EW)
						Combat.addEvent(c, { kind = "LOST_LOCK", tick = sim.tick, unit = homingTarget, other = id, x = x0, y = y0, z = z0 })
					end
				end
				c.pTarget[id] = 0
				homingTarget = 0
			end
		end
		if projTarget ~= 0 and weapon.turnRate then
			-- interceptor (S-48): navigate against the missile's own state
			local st = chasedState[projTarget]
			local tx, ty, tz = st[1], st[2], st[3]
			local tvx, tvy, tvz = st[4], st[5], st[6]
			local maxTurn = math.rad(weapon.turnRate) * DT
			if weapon.launch == "vertical" then
				local turned = bit32.band(c.pFlags[id], TURNED) ~= 0
				local climbLeft = Guidance.climbLeft(weapon, y0, Combat.groundHeight(c, x0, z0))
				pvx, pvy, pvz, turned = Guidance.vertical(x0, y0, z0, pvx, pvy, pvz, tx, ty, tz, tvx, tvy, tvz, maxTurn, DT, turned, climbLeft)
				if turned then
					c.pFlags[id] = bit32.bor(c.pFlags[id], TURNED)
				end
			else
				pvx, pvy, pvz = Guidance.pn(x0, y0, z0, pvx, pvy, pvz, tx, ty, tz, tvx, tvy, tvz, maxTurn, DT)
			end
		elseif World.isRef(w, homingTarget, c.pTargetGen[id]) and weapon.turnRate then
			-- missiles: proportional navigation; torpedoes: lead pursuit
			-- (Shared/Combat/Guidance, S-27)
			local tx, ty, tz = Combat.aimPoint(c, w, homingTarget)
			local tvx, tvz = Guidance.velocity(w.heading[homingTarget], w.speed[homingTarget])
			local maxTurn = math.rad(weapon.turnRate) * DT
			if weapon.type == "HOMING" and weapon.launch == "vertical" then
				-- climb, pitch over, then navigate (S-42)
				local turned = bit32.band(c.pFlags[id], TURNED) ~= 0
				local climbLeft = Guidance.climbLeft(weapon, y0, Combat.groundHeight(c, x0, z0))
				pvx, pvy, pvz, turned = Guidance.vertical(x0, y0, z0, pvx, pvy, pvz, tx - tvx * DT, ty, tz - tvz * DT, tvx, 0, tvz, maxTurn, DT, turned, climbLeft)
				if turned then
					c.pFlags[id] = bit32.bor(c.pFlags[id], TURNED)
				end
			elseif weapon.type == "HOMING" then
				-- the target already moved this tick (Movement runs first):
				-- navigate against where it was when the missile's step starts
				pvx, pvy, pvz = Guidance.pn(x0, y0, z0, pvx, pvy, pvz, tx - tvx * DT, ty, tz - tvz * DT, tvx, 0, tvz, maxTurn, DT)
			else
				pvx, pvy, pvz = Guidance.lead(x0, y0, z0, pvx, pvy, pvz, tx, ty, tz, tvx, tvz, maxTurn)
			end
		elseif c.pDecoy[id] then
			-- decoyed: follow the flare or chaff for a moment (S-28)
			local d = c.pDecoy[id]
			local follow
			pvx, pvy, pvz, follow = Guidance.decoy(x0, y0, z0, pvx, pvy, pvz, d[1], d[2], d[3], math.rad(weapon.turnRate :: number) * DT, Guidance.seekerAngle(weapon) :: number)
			d[4] -= 1
			if not follow or d[4] <= 0 then
				c.pDecoy[id] = nil
			end
		elseif radar and c.pPoint[id] then
			-- to the dead target's last known spot (S-146)
			local pt = c.pPoint[id]
			local maxTurn = math.rad(weapon.turnRate :: number) * DT
			if weapon.launch == "vertical" then
				local turned = bit32.band(c.pFlags[id], TURNED) ~= 0
				local climbLeft = Guidance.climbLeft(weapon, y0, Combat.groundHeight(c, x0, z0))
				pvx, pvy, pvz, turned = Guidance.vertical(x0, y0, z0, pvx, pvy, pvz, pt[1], pt[2], pt[3], 0, 0, 0, maxTurn, DT, turned, climbLeft)
				if turned then
					c.pFlags[id] = bit32.bor(c.pFlags[id], TURNED)
				end
			else
				pvx, pvy, pvz = Guidance.pn(x0, y0, z0, pvx, pvy, pvz, pt[1], pt[2], pt[3], 0, 0, 0, maxTurn, DT)
			end
		elseif radar and c.pLost[id] then
			-- lost its target: corkscrew and sink (S-146, Guidance.lost)
			pvx, pvy, pvz = Guidance.lost(pvx, pvy, pvz, c.pLost[id], id, DT)
			c.pLost[id] += 1
		end
		local x1, y1, z1, vx, vy, vz
		local goal = c.pGoal[id]
		if goal and weapon.apex then
			-- strategic missile: boost, pitch-over, lofted arc (S-51)
			local climbLeft = Guidance.climbLeft(weapon, y0, Combat.groundHeight(c, x0, z0))
			x1, y1, z1, vx, vy, vz = Lofted.step(x0, y0, z0, pvx, pvy, pvz, goal[1], goal[2], goal[3], goal[2] + weapon.apex, g, math.rad(weapon.turnRate :: number) * DT, climbLeft, DT)
		else
			-- shield fields (S-79): enemy domes brake, turn or let through
			local fielded, absorbed = false, false
			if #c.shieldIds > 0 and projTarget == 0 and Shield.affects(weapon) then
				x1, y1, z1, vx, vy, vz, fielded, absorbed = Shield.deflect(sim, id, weapon, x0, y0, z0, pvx, pvy, pvz, g)
				homingTarget = c.pTarget[id] -- a turned missile lost its lock
			end
			if absorbed then
				Combat.removeProjectile(c, id) -- destroyed at the dome's surface (S-85): its SHIELD_HIT says so
				continue
			end
			if not fielded then
				x1, y1, z1, vx, vy, vz = Ballistics.step(x0, y0, z0, pvx, pvy, pvz, g, DT)
			end
		end
		local grid = c.grid
		local out = Grid.OVERFLY -- (S-189: at the edge itself before protocol 38, client request 15)
		if grid and (x1 < grid.originX - out or z1 < grid.originZ - out or x1 > grid.originX + grid.sizeX + out or z1 > grid.originZ + grid.sizeZ + out) then
			-- past the overfly margin: nothing to hit out there; burst at its edge
			local ex = math.clamp(x1, grid.originX - out, grid.originX + grid.sizeX + out)
			local ez = math.clamp(z1, grid.originZ - out, grid.originZ + grid.sizeZ + out)
			Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = 0, other = id, x = ex, y = y1, z = ez })
			Combat.removeProjectile(c, id)
			continue
		end
		if weapon.bolt then
			-- the D-Gun's bolt (S-194, G5): rides the ground in a straight line
			-- and destroys every unit it passes through, once each
			local hit = c.pHit[id]
			if hit == nil then
				hit = {}
				c.pHit[id] = hit
				-- its range along the ground, flown level from here on
				local hs = sqrt(pvx * pvx + pvz * pvz)
				local speed = sqrt(hs * hs + pvy * pvy)
				if hs > 1e-6 then
					vx, vz = pvx / hs * speed, pvz / hs * speed
					x1, z1 = x0 + vx * DT, z0 + vz * DT
				end
				c.pTtl[id] = weapon.range / math.max(speed, 1)
			end
			y1, vy = Combat.groundHeight(c, x1, z1) + Combat.BOLT_HEIGHT, 0
			local owner = c.pOwner[id]
			local reach = weapon.bolt :: number
			local n = ContactGrid.query(c.contacts, w, (x0 + x1) / 2, (z0 + z1) / 2, reach + c.maxRadius + sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) / 2, 0, candidates)
			local passed = table.move(candidates, 1, n, 1, table.create(n))
			table.sort(passed) -- (in ID order: deterministic)
			local dx, dz = x1 - x0, z1 - z0
			local len2 = dx * dx + dz * dz
			for _, u in passed do
				if u == owner or hit[u] or w.slot[u] == nil then
					continue
				end
				local p = profiles[w.defIndex[u]]
				local ud = sim.defs.unitByIndex[w.defIndex[u]]
				if ud.domain == "air" and bit32.band(w.state[u], World.State.LANDED) == 0 then
					continue -- over the bolt's head
				end
				local t = if len2 > 0 then math.clamp(((w.posX[u] - x0) * dx + (w.posZ[u] - z0) * dz) / len2, 0, 1) else 0
				local ex, ez = x0 + dx * t - w.posX[u], z0 + dz * t - w.posZ[u]
				if ex * ex + ez * ez <= (reach + p.radius) ^ 2 then
					hit[u] = true
					local commander = bit32.band(p.categoryMask, Combat.COMMANDER_BIT) ~= 0
					local amount = if commander then ud.health * Combat.BOLT_COMMANDER else w.health[u] * 100 + 1
					if not commander then
						c.noWreck[u] = true
						sim.cheats.killing[u] = true -- (through god mode)
					end
					Combat.queueDamage(c, u, amount, if World.isRef(w, owner, c.pOwnerGen[id]) then owner else 0, c.pPlayer[id])
					-- (not tied to the bolt: an IMPACT with its ID would end it for
					-- the clients, and NetOut would announce it again; client-B)
					Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = u, other = 0, x = w.posX[u], y = y1, z = w.posZ[u] })
					c.stats.hits += 1
				end
			end
			local ttl = c.pTtl[id] - DT
			if ttl <= 0 then
				Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = 0, other = id, x = x1, y = y1, z = z1 })
				Combat.removeProjectile(c, id)
			else
				c.px[id], c.py[id], c.pz[id] = x1, y1, z1
				c.pvx[id], c.pvy[id], c.pvz[id] = vx, vy, vz
				c.pTtl[id] = ttl
			end
			continue
		end
		if weapon.type == "TORPEDO" then
			-- torpedoes run in water only (guide 12.3): gone at the shore,
			-- otherwise held between the sea floor and just under the surface
			if Combat.waterDepth(c, x1, z1) <= 0 then
				Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = 0, other = id, x = x1, y = y1, z = z1 })
				Combat.removeProjectile(c, id)
				continue
			end
			local surface = Combat.surfaceHeight(c, x1, z1)
			y1 = math.clamp(y1, Combat.groundHeight(c, x1, z1) + 0.5, surface - 0.5)
		end

		-- earliest unit contact along the chord
		local team = c.pTeam[id]
		local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
		local half = sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) / 2
		local n = if weapon.strategic then 0 else ContactGrid.query(c.contacts, w, mx, mz, half + c.maxRadius + c.maxSpeedStep, team, candidates)
		local bestT, bestUnit = math.huge, 0
		for i = 1, n do
			local u = candidates[i]
			local p = profiles[w.defIndex[u]]
			local base = Combat.unitBase(c, w, u)
			-- in the unit's frame: where the unit was at the start of the tick
			local h, v = w.heading[u], w.speed[u] * DT
			local ux, uz = w.posX[u], w.posZ[u]
			local sx, sz = ux - sin(h) * v, uz - cos(h) * v
			local t = Ballistics.segmentCylinder(x0 - sx, y0, z0 - sz, x1 - ux, y1, z1 - uz, 0, 0, p.radius, base, base + p.height)
			if t ~= nil and (t < bestT or (t == bestT and u < bestUnit)) then
				bestT, bestUnit = t, u
			end
		end

		-- proximity fuse (D97): a homing missile bursts at its closest
		-- approach when that is within its blast radius of the target's hull
		-- (target frame, as above); the burst deals AoE damage only
		local burst = 0
		if weapon.type == "HOMING" and World.isRef(w, homingTarget, c.pTargetGen[id]) and (weapon.aoe or 0) > 0 then
			local u = homingTarget
			local p = profiles[w.defIndex[u]]
			local base = Combat.unitBase(c, w, u)
			local h, v = w.heading[u], w.speed[u] * DT
			local ux, uz = w.posX[u], w.posZ[u]
			local ax, az = x0 - (ux - sin(h) * v), z0 - (uz - cos(h) * v)
			local dx, dy, dz = (x1 - ux) - ax, y1 - y0, (z1 - uz) - az
			local cy = base + p.height / 2
			local len2 = dx * dx + dy * dy + dz * dz
			local t = if len2 > 0 then math.clamp(-(ax * dx + (y0 - cy) * dy + az * dz) / len2, 0, 1) else 0
			local d = Ballistics.distanceToCylinder(ax + dx * t, y0 + dy * t, az + dz * t, 0, 0, p.radius, base, base + p.height)
			if d <= (weapon.aoe :: number) and t < bestT then
				bestT, bestUnit, burst = t, 0, u
			end
		end

		-- interceptor fuse against its strategic missile (S-48), in the
		-- missile's frame
		local burstProj = 0
		if projTarget ~= 0 and (weapon.aoe or 0) > 0 then
			local st = chasedState[projTarget]
			local ax, ay, az = x0 - st[1], y0 - st[2], z0 - st[3]
			local dx = (x1 - x0) - st[4] * DT
			local dy = (y1 - y0) - st[5] * DT
			local dz = (z1 - z0) - st[6] * DT
			local len2 = dx * dx + dy * dy + dz * dz
			local t = if len2 > 0 then math.clamp(-(ax * dx + ay * dy + az * dz) / len2, 0, 1) else 0
			local ex, ey, ez = ax + dx * t, ay + dy * t, az + dz * t
			if ex * ex + ey * ey + ez * ez <= (weapon.aoe :: number) ^ 2 and t < bestT then
				bestT, bestUnit, burst, burstProj = t, 0, 0, projTarget
			end
		end

		-- a missile flying to a dead target's spot bursts at its closest
		-- approach to it, within its blast radius (S-146)
		local point = if radar then c.pPoint[id] else nil
		if point then
			local dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
			local len2 = dx * dx + dy * dy + dz * dz
			local t = if len2 > 0 then math.clamp(-((x0 - point[1]) * dx + (y0 - point[2]) * dy + (z0 - point[3]) * dz) / len2, 0, 1) else 0
			local ex, ey, ez = x0 + dx * t - point[1], y0 + dy * t - point[2], z0 + dz * t - point[3]
			if ex * ex + ey * ey + ez * ez <= math.max(weapon.aoe or 0, POINT_FUSE) ^ 2 and t < bestT then
				bestT, bestUnit, burst = t, 0, 0
			end
		end

		-- terrain contact (ground treated as linear along the chord)
		local a0 = y0 - Combat.groundHeight(c, x0, z0)
		local a1 = y1 - Combat.groundHeight(c, x1, z1)
		if a1 < 0 and weapon.type ~= "TORPEDO" then
			local t = if a0 > 0 then a0 / (a0 - a1) else 0
			if t < bestT then
				bestT, bestUnit, burst, burstProj = t, 0, 0, 0
			end
		end

		if bestT <= 1 and burstProj ~= 0 then
			-- the interceptor bursts at the missile; no blast on the ground
			local ix, iy, iz = x0 + (x1 - x0) * bestT, y0 + (y1 - y0) * bestT, z0 + (z1 - z0) * bestT
			Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = 0, other = id, x = ix, y = iy, z = iz })
			local intercepts = weapon.intercepts
			if intercepts and sim.rng:chance(intercepts.chance) and not table.find(killed, burstProj) then
				table.insert(killed, burstProj)
			end
			Combat.removeProjectile(c, id)
			continue
		end

		if bestT <= 1 then
			local ix, iy, iz = x0 + (x1 - x0) * bestT, y0 + (y1 - y0) * bestT, z0 + (z1 - z0) * bestT
			Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = if burst ~= 0 then burst else bestUnit, other = id, x = ix, y = iy, z = iz })
			if bestUnit ~= 0 or burst ~= 0 then
				c.stats.hits += 1
			end
			local owner = c.pOwner[id]
			if not World.isRef(w, owner, c.pOwnerGen[id]) then
				owner = 0 -- the shooter is gone (D109)
			end
			-- a strategic blast hurts every side (S-48): team 0 is nobody's
			Combat.explode(c, w, ix, iy, iz, weapon, owner, if weapon.strategic then 0 else team, bestUnit, c.pPlayer[id])
			Combat.removeProjectile(c, id)
		else
			local ttl = c.pTtl[id] - DT
			if ttl <= 0 then
				Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = 0, other = id, x = x1, y = y1, z = z1 })
				Combat.removeProjectile(c, id)
			else
				c.px[id], c.py[id], c.pz[id] = x1, y1, z1
				c.pvx[id], c.pvy[id], c.pvz[id] = vx, vy, vz
				c.pTtl[id] = ttl
			end
		end
	end

	-- strategic missiles destroyed by interceptors this tick (S-48)
	for _, p in killed do
		if c.projSlot[p] ~= nil then
			c.stats.hits += 1
			Combat.addEvent(c, { kind = "INTERCEPTED", tick = sim.tick, unit = 0, other = p, x = c.px[p], y = c.py[p], z = c.pz[p] })
			Combat.removeProjectile(c, p)
		end
	end
end

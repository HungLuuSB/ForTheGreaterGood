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

local Ballistics = require("../Combat/Ballistics")
local Guidance = require("@shared/Combat/Guidance")
local Combat = require("../Combat/Combat")
local ContactGrid = require("../Combat/ContactGrid")
local EW = require("../EW")
local Types = require("../Types")
local World = require("../World")

local DT = 1 / 15
local TURNED = EW.Flag.TURNED
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

local candidates: { number } = {}

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

	-- Backwards, so swap-removal never skips an unprocessed projectile.
	for k = #proj, 1, -1 do
		local id = proj[k]
		local weapon = weapons[c.pWeapon[id]]
		local g = weapon.gravity or 0
		if weapon.guidance then
			EW.guide(sim, id, weapon)
		end
		local x0, y0, z0 = c.px[id], c.py[id], c.pz[id]
		local pvx, pvy, pvz = c.pvx[id], c.pvy[id], c.pvz[id]
		local homingTarget = c.pTarget[id]
		if World.isRef(w, homingTarget, c.pTargetGen[id]) and weapon.turnRate then
			-- missiles: proportional navigation; torpedoes: lead pursuit
			-- (Shared/Combat/Guidance, S-27)
			local tx, ty, tz = Combat.aimPoint(c, w, homingTarget)
			local tvx, tvz = Guidance.velocity(w.heading[homingTarget], w.speed[homingTarget])
			local maxTurn = math.rad(weapon.turnRate) * DT
			if weapon.type == "HOMING" and weapon.launch == "vertical" then
				-- climb, pitch over, then navigate (S-42)
				local turned = bit32.band(c.pFlags[id], TURNED) ~= 0
				pvx, pvy, pvz, turned = Guidance.vertical(x0, y0, z0, pvx, pvy, pvz, tx - tvx * DT, ty, tz - tvz * DT, tvx, 0, tvz, maxTurn, DT, turned)
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
		end
		local x1, y1, z1, vx, vy, vz = Ballistics.step(x0, y0, z0, pvx, pvy, pvz, g, DT)
		local grid = c.grid
		if grid and (x1 < grid.originX or z1 < grid.originZ or x1 > grid.originX + grid.sizeX or z1 > grid.originZ + grid.sizeZ) then
			-- off the map: nothing to hit out there; burst at the edge (client
			-- request 15: positions past the edge can't go on the wire)
			local ex = math.clamp(x1, grid.originX, grid.originX + grid.sizeX)
			local ez = math.clamp(z1, grid.originZ, grid.originZ + grid.sizeZ)
			Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = 0, other = id, x = ex, y = y1, z = ez })
			Combat.removeProjectile(c, id)
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
		local n = ContactGrid.query(c.contacts, w, mx, mz, half + c.maxRadius + c.maxSpeedStep, team, candidates)
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

		-- terrain contact (ground treated as linear along the chord)
		local a0 = y0 - Combat.groundHeight(c, x0, z0)
		local a1 = y1 - Combat.groundHeight(c, x1, z1)
		if a1 < 0 and weapon.type ~= "TORPEDO" then
			local t = if a0 > 0 then a0 / (a0 - a1) else 0
			if t < bestT then
				bestT, bestUnit, burst = t, 0, 0
			end
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
			Combat.explode(c, w, ix, iy, iz, weapon, owner, team, bestUnit)
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
end

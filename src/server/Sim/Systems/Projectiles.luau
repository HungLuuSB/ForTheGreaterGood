--!strict
-- System 8: step projectiles, collide, impact (guide 10.5).
--
-- Exact ballistic step per tick, then a swept test of the tick's chord
-- against unit cylinders (enemies only: direct hits never hit allies, guide
-- 10.6) and against the terrain. The test runs in each unit's frame of
-- reference (the chord minus the unit's own motion this tick), so fast jets
-- can't slip between ticks either. The earliest contact is the impact; an
-- explosion applies direct and AoE damage. Projectiles expire after their ttl.
--
-- HOMING / TORPEDO projectiles turn toward their target's center at the
-- weapon's turnRate (deg/s) before each step; guidance types, locks and
-- countermeasures come with electronic warfare (guide 11.5, M7).

local Ballistics = require("../Combat/Ballistics")
local Combat = require("../Combat/Combat")
local ContactGrid = require("../Combat/ContactGrid")
local Types = require("../Types")

local DT = 1 / 15
local sqrt, sin, cos = math.sqrt, math.sin, math.cos

-- Turns velocity (vx, vy, vz) toward direction (dx, dy, dz) by at most
-- maxAngle radians, keeping its speed.
local function steer(vx: number, vy: number, vz: number, dx: number, dy: number, dz: number, maxAngle: number): (number, number, number)
	local speed = sqrt(vx * vx + vy * vy + vz * vz)
	local dl = sqrt(dx * dx + dy * dy + dz * dz)
	if speed < 1e-9 or dl < 1e-9 then
		return vx, vy, vz
	end
	local ax, ay, az = vx / speed, vy / speed, vz / speed
	local bx, by, bz = dx / dl, dy / dl, dz / dl
	local dot = math.clamp(ax * bx + ay * by + az * bz, -1, 1)
	local angle = math.acos(dot)
	local t = if angle <= maxAngle then 1 else maxAngle / angle
	local nx, ny, nz = ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t
	local nl = sqrt(nx * nx + ny * ny + nz * nz)
	if nl < 1e-9 then
		return vx, vy, vz
	end
	return nx / nl * speed, ny / nl * speed, nz / nl * speed
end

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
		local x0, y0, z0 = c.px[id], c.py[id], c.pz[id]
		local pvx, pvy, pvz = c.pvx[id], c.pvy[id], c.pvz[id]
		local homingTarget = c.pTarget[id]
		if homingTarget ~= 0 and w.slot[homingTarget] ~= nil and weapon.turnRate then
			local tp = profiles[w.defIndex[homingTarget]]
			local ty = Combat.unitBase(c, w, homingTarget) + tp.height / 2
			pvx, pvy, pvz = steer(pvx, pvy, pvz, w.posX[homingTarget] - x0, ty - y0, w.posZ[homingTarget] - z0, math.rad(weapon.turnRate) * DT)
		end
		local x1, y1, z1, vx, vy, vz = Ballistics.step(x0, y0, z0, pvx, pvy, pvz, g, DT)

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

		-- terrain contact (ground treated as linear along the chord)
		local a0 = y0 - Combat.groundHeight(c, x0, z0)
		local a1 = y1 - Combat.groundHeight(c, x1, z1)
		if a1 < 0 then
			local t = if a0 > 0 then a0 / (a0 - a1) else 0
			if t < bestT then
				bestT, bestUnit = t, 0
			end
		end

		if bestT <= 1 then
			local ix, iy, iz = x0 + (x1 - x0) * bestT, y0 + (y1 - y0) * bestT, z0 + (z1 - z0) * bestT
			Combat.addEvent(c, { kind = "IMPACT", tick = sim.tick, unit = bestUnit, other = id, x = ix, y = iy, z = iz })
			if bestUnit ~= 0 then
				c.stats.hits += 1
			end
			Combat.explode(c, w, ix, iy, iz, weapon, c.pOwner[id], team, bestUnit)
			Combat.removeProjectile(c, id)
		else
			local ttl = c.pTtl[id] - DT
			if ttl <= 0 then
				Combat.removeProjectile(c, id)
			else
				c.px[id], c.py[id], c.pz[id] = x1, y1, z1
				c.pvx[id], c.pvy[id], c.pvz[id] = vx, vy, vz
				c.pTtl[id] = ttl
			end
		end
	end
end

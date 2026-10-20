--!strict
-- Pure math for weapons and projectiles (guide 10.3–10.5). No state.

local Ballistics = {}

local sqrt, atan, atan2 = math.sqrt, math.atan, math.atan2

-- Low-arc launch pitch (radians) to hit a point `dist` studs away
-- horizontally and `dh` studs higher, at launch speed `speed` and gravity
-- `gravity` (studs/s²). nil when out of ballistic reach.
function Ballistics.launchPitch(speed: number, gravity: number, dist: number, dh: number): number?
	if dist < 1e-6 then
		return if dh >= 0 then math.pi / 2 else -math.pi / 2
	end
	if gravity <= 0 then
		return atan2(dh, dist)
	end
	local v2 = speed * speed
	local disc = v2 * v2 - gravity * (gravity * dist * dist + 2 * dh * v2)
	if disc < 0 then
		return nil
	end
	return atan((v2 - sqrt(disc)) / (gravity * dist))
end

-- Exact ballistic step over dt: returns the new position and velocity.
function Ballistics.step(
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	gravity: number,
	dt: number
): (number, number, number, number, number, number)
	return x + vx * dt, y + vy * dt - 0.5 * gravity * dt * dt, z + vz * dt, vx, vy - gravity * dt, vz
end

-- First contact of the segment p0 → p1 with a vertical cylinder (center
-- cx, cz; radius r; from `bottom` to `top`), as t in [0, 1]; nil if none.
-- The segment is the straight chord of one tick of flight (swept test: a
-- fast projectile can't tunnel through a unit between ticks).
function Ballistics.segmentCylinder(
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number,
	cx: number,
	cz: number,
	r: number,
	bottom: number,
	top: number
): number?
	local dx, dz = x1 - x0, z1 - z0
	local fx, fz = x0 - cx, z0 - cz
	local a = dx * dx + dz * dz
	local c = fx * fx + fz * fz - r * r
	local lo, hi
	if a < 1e-12 then
		if c > 0 then
			return nil -- moving straight up/down outside the circle
		end
		lo, hi = 0, 1
	else
		local b = 2 * (fx * dx + fz * dz)
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return nil
		end
		local s = sqrt(disc)
		lo = math.max(0, (-b - s) / (2 * a))
		hi = math.min(1, (-b + s) / (2 * a))
		if lo > hi then
			return nil
		end
	end
	local dy = y1 - y0
	if math.abs(dy) < 1e-12 then
		return if y0 >= bottom and y0 <= top then lo else nil
	end
	local ta, tb = (bottom - y0) / dy, (top - y0) / dy
	local yLo, yHi = math.min(ta, tb), math.max(ta, tb)
	local t0, t1 = math.max(lo, yLo), math.min(hi, yHi)
	return if t0 <= t1 then t0 else nil
end

-- Distance from a point to a vertical cylinder's surface (0 inside).
function Ballistics.distanceToCylinder(x: number, y: number, z: number, cx: number, cz: number, r: number, bottom: number, top: number): number
	local horiz = math.max(0, sqrt((x - cx) ^ 2 + (z - cz) ^ 2) - r)
	local vert = if y < bottom then bottom - y elseif y > top then y - top else 0
	return sqrt(horiz * horiz + vert * vert)
end

-- Damage at distance d from an explosion (guide 10.6).
function Ballistics.falloff(d: number, aoe: number, edgeEffectiveness: number): number
	if aoe <= 0 then
		return if d <= 0 then 1 else 0
	end
	if d >= aoe then
		return 0
	end
	return 1 - (d / aoe) * (1 - edgeEffectiveness)
end

return Ballistics

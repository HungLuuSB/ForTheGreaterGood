--!strict
-- Strategic missile flight (S-51, client request 28; guide 10.9). Shared so
-- the server and clients fly a nuke the same way. Each phase follows from
-- the missile's own state and its goal (the ordered spot), so a client that
-- first sees it mid-flight steps it the same:
--   * boost: no horizontal velocity and still below `climbHeight` above the
--     ground under it (Guidance.climbLeft): straight up at constant speed;
--   * turn: still climbing (vy > 0): steer toward the lofted velocity
--     (Lofted.velocity: the arc from here that peaks at `peakY` and lands on
--     the goal) at most `maxTurn` radians per tick, at that velocity's speed,
--     powered (no gravity). Once within `maxTurn` of it, it takes it exactly
--     and falls from there. On the arc the lofted velocity is the current
--     one, so the rest of the climb is plain ballistic flight, re-solved
--     every tick so the landing stays exact;
--   * ballistic: descending (vy <= 0).

local Ballistics = require("./Ballistics")

local Lofted = {}

local sqrt, max, acos, sin = math.sqrt, math.max, math.acos, math.sin

-- The velocity at (x, y, z) of the ballistic arc (gravity `g`) that peaks at
-- height `peakY` and lands on (tx, ty, tz), and its time to land. Peaks at or
-- below the current point climb no further.
function Lofted.velocity(
	x: number,
	y: number,
	z: number,
	tx: number,
	ty: number,
	tz: number,
	peakY: number,
	g: number
): (number, number, number, number)
	local up = sqrt(2 * g * max(peakY - y, 0))
	local down = sqrt(2 * g * max(max(peakY, y) - ty, 0))
	local t = (up + down) / g
	if t <= 1e-6 then
		return 0, 0, 0, 0
	end
	return (tx - x) / t, up, (tz - z) / t, t
end

-- One tick of a strategic missile: returns its new position and velocity.
-- `peakY` = goal height + weapon.apex; `maxTurn` = rad(turnRate) × dt;
-- `climbLeft` = Guidance.climbLeft(weapon, y, ground height under it).
function Lofted.step(
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	tx: number,
	ty: number,
	tz: number,
	peakY: number,
	g: number,
	maxTurn: number,
	climbLeft: number,
	dt: number
): (number, number, number, number, number, number)
	if vx == 0 and vz == 0 and climbLeft > 0 then
		return x, y + vy * dt, z, vx, vy, vz -- boost
	end
	if vy > 0 then
		local dvx, dvy, dvz = Lofted.velocity(x, y, z, tx, ty, tz, peakY, g)
		local speed = sqrt(dvx * dvx + dvy * dvy + dvz * dvz)
		local cur = sqrt(vx * vx + vy * vy + vz * vz)
		if speed > 0 and cur > 0 then
			local cosA = (vx * dvx + vy * dvy + vz * dvz) / (cur * speed)
			local angle = acos(math.clamp(cosA, -1, 1))
			if angle <= maxTurn then
				vx, vy, vz = dvx, dvy, dvz -- on the arc: fall from here
			else
				-- turn: rotate the direction by maxTurn toward the arc (slerp),
				-- at the arc's speed, powered
				local s = sin(angle)
				local a = sin(angle - maxTurn) / s / cur
				local b = sin(maxTurn) / s / speed
				local ux, uy, uz = vx * a + dvx * b, vy * a + dvy * b, vz * a + dvz * b
				vx, vy, vz = ux * speed, uy * speed, uz * speed
				return x + vx * dt, y + vy * dt, z + vz * dt, vx, vy, vz
			end
		end
	end
	return Ballistics.step(x, y, z, vx, vy, vz, g, dt)
end

return Lofted

--!strict
-- Homing guidance, one tick at a time (guide 10.4, S-27). Pure math shared by
-- the server (Projectiles) and the client, which steps its own copies of
-- missiles with the same functions (client request 11b).
--
--   * Missiles (HOMING) fly proportional navigation: the velocity turns at
--     N times the line-of-sight rotation rate, about the same axis. Against
--     a turning target it needs no prediction of where the target will be,
--     and it ends on a collision course instead of a tail chase.
--   * Torpedoes (TORPEDO) keep lead pursuit: steer at where the target will
--     be after the straight-line time to go, holding its heading and speed
--     (D97). Their targets are slow ships that rarely turn hard.
-- Both turn at most `maxTurn` radians per tick (the weapon's turnRate × dt).
-- A turn-rate cap at a missile's constant speed is a G limit (a = ω v), so
-- no separate one is modelled (client request 11c).

local Ballistics = require("./Ballistics")

local Guidance = {}

Guidance.N = 4 -- navigation constant (3–5 is usual)

local sqrt, cos, sin, min = math.sqrt, math.cos, math.sin, math.min

-- New velocity after one tick of proportional navigation. Missile at
-- (px, py, pz) with velocity (vx, vy, vz); target aim point (tx, ty, tz)
-- moving at (tvx, tvy, tvz).
function Guidance.pn(
	px: number,
	py: number,
	pz: number,
	vx: number,
	vy: number,
	vz: number,
	tx: number,
	ty: number,
	tz: number,
	tvx: number,
	tvy: number,
	tvz: number,
	maxTurn: number,
	dt: number
): (number, number, number)
	local rx, ry, rz = tx - px, ty - py, tz - pz
	local r2 = rx * rx + ry * ry + rz * rz
	if r2 < 1e-6 then
		return vx, vy, vz
	end
	-- line-of-sight rotation rate: ω = r × (v_target − v_missile) / |r|²
	local ux, uy, uz = tvx - vx, tvy - vy, tvz - vz
	local ox, oy, oz = (ry * uz - rz * uy) / r2, (rz * ux - rx * uz) / r2, (rx * uy - ry * ux) / r2
	local om = sqrt(ox * ox + oy * oy + oz * oz)
	local angle = min(Guidance.N * om * dt, maxTurn)
	if angle < 1e-12 then
		return vx, vy, vz
	end
	-- rotate v about ω̂ by angle (Rodrigues)
	local kx, ky, kz = ox / om, oy / om, oz / om
	local c, s = cos(angle), sin(angle)
	local kv = kx * vx + ky * vy + kz * vz
	local cx, cy, cz = ky * vz - kz * vy, kz * vx - kx * vz, kx * vy - ky * vx
	return vx * c + cx * s + kx * kv * (1 - c), vy * c + cy * s + ky * kv * (1 - c), vz * c + cz * s + kz * kv * (1 - c)
end

-- New velocity after one tick of lead pursuit (torpedoes): steer at where the
-- target will be after the straight-line time to go.
function Guidance.lead(
	px: number,
	py: number,
	pz: number,
	vx: number,
	vy: number,
	vz: number,
	tx: number,
	ty: number,
	tz: number,
	tvx: number,
	tvz: number,
	maxTurn: number
): (number, number, number)
	local speed = sqrt(vx * vx + vy * vy + vz * vz)
	local tgo = sqrt((tx - px) ^ 2 + (ty - py) ^ 2 + (tz - pz) ^ 2) / math.max(speed, 1)
	return Ballistics.steer(vx, vy, vz, tx + tvx * tgo - px, ty - py, tz + tvz * tgo - pz, maxTurn)
end

-- Whether the target is inside the seeker's cone: within `halfAngle` radians
-- of the missile's velocity.
function Guidance.inCone(px: number, py: number, pz: number, vx: number, vy: number, vz: number, tx: number, ty: number, tz: number, halfAngle: number): boolean
	local rx, ry, rz = tx - px, ty - py, tz - pz
	local rl = sqrt(rx * rx + ry * ry + rz * rz)
	local vl = sqrt(vx * vx + vy * vy + vz * vz)
	if rl < 1e-6 or vl < 1e-6 then
		return true
	end
	return (rx * vx + ry * vy + rz * vz) / (rl * vl) >= cos(halfAngle)
end

-- A target's velocity from the state the wire and the sim share: heading
-- (0 = +Z) and ground speed. Aircraft climbs are left out.
function Guidance.velocity(heading: number, speed: number): (number, number)
	return sin(heading) * speed, cos(heading) * speed
end

return Guidance

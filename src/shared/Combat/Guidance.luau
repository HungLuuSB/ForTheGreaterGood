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

-- Seeker half-angle in degrees by guidance, unless the weapon sets
-- seekerAngle; COMMAND guidance (the launcher steers) has none (S-27).
Guidance.SEEKER_ANGLE = table.freeze({ IR = 60, RADAR = 70 } :: { [string]: number })

function Guidance.seekerAngle(weapon: { seekerAngle: number?, guidance: string? }): number?
	return weapon.seekerAngle or (if weapon.guidance then Guidance.SEEKER_ANGLE[weapon.guidance] else nil)
end

-- A decoyed missile (S-28, client request 13d) follows the flare or chaff:
-- for at most DECOY_TICKS ticks after the DECOYED roll it turns toward the
-- decoy point at its turnRate, while that point stays in its seeker cone;
-- then it flies straight to the end of its lifetime.
Guidance.DECOY_TICKS = 15 -- 1 s

-- One tick toward the decoy point (dx, dy, dz): the new velocity and whether
-- the seeker still follows it (false: the point left the cone; fly straight).
function Guidance.decoy(px: number, py: number, pz: number, vx: number, vy: number, vz: number, dx: number, dy: number, dz: number, maxTurn: number, coneDeg: number): (number, number, number, boolean)
	if not Guidance.inCone(px, py, pz, vx, vy, vz, dx, dy, dz, math.rad(coneDeg)) then
		return vx, vy, vz, false
	end
	local nx, ny, nz = Ballistics.steer(vx, vy, vz, dx - px, dy - py, dz - pz, maxTurn)
	return nx, ny, nz, true
end

-- Vertically launched missiles (S-42, client request 20; IRIS-T SLM style)
-- leave the launcher straight up. Until their target is first within
-- HANDOVER degrees of the nose they turn straight toward it at PITCH_OVER times their
-- turnRate (thrust vectoring during the boost: at plain turnRate a 360
-- studs/s missile turning 90°/s needs a 229-stud radius and can't reach a
-- target closer than that); from then on, proportional navigation at
-- turnRate. `turned` is that
-- state: false at launch, and the function returns its new value, so a
-- client stepping its own copy keeps it per missile. Target position at the
-- start of the step, as for `pn`.
-- First the boost climb (S-44, client request 22): while a missile is still
-- flying straight up (no horizontal velocity) and `climbLeft` (studs still to
-- climb: Guidance.climbLeft) is above 0, it doesn't steer. Both are read
-- from the missile's own state, so a client that first sees it mid-flight
-- decides the same; nil `climbLeft` = no climb.
Guidance.PITCH_OVER = 3 -- turn-rate factor while a vertical launch pitches over
Guidance.HANDOVER = 15 -- degrees: a vertical launch hands over to proportional navigation once the target is this close to its nose

function Guidance.vertical(
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
	dt: number,
	turned: boolean,
	climbLeft: number?
): (number, number, number, boolean)
	if not turned and vx == 0 and vz == 0 and (climbLeft or 0) > 0 then
		return vx, vy, vz, false -- still in the boost climb
	end
	if not turned then
		if not Guidance.inCone(px, py, pz, vx, vy, vz, tx, ty, tz, math.rad(Guidance.HANDOVER)) then
			local nx, ny, nz = Ballistics.steer(vx, vy, vz, tx - px, ty - py, tz - pz, maxTurn * Guidance.PITCH_OVER)
			return nx, ny, nz, false
		end
		turned = true
	end
	local nx, ny, nz = Guidance.pn(px, py, pz, vx, vy, vz, tx, ty, tz, tvx, tvy, tvz, maxTurn, dt)
	return nx, ny, nz, true
end

-- Studs a vertical launch at height `py` over ground `groundY` (Layers.heightAt
-- under it) still climbs before it may pitch over: the weapon's climbHeight
-- above that ground (S-44).
function Guidance.climbLeft(weapon: { climbHeight: number? }, py: number, groundY: number): number
	return (weapon.climbHeight or 0) - (py - groundY)
end

-- A target's velocity from the state the wire and the sim share: heading
-- (0 = +Z) and ground speed. Aircraft climbs are left out.
function Guidance.velocity(heading: number, speed: number): (number, number)
	return sin(heading) * speed, cos(heading) * speed
end

return Guidance

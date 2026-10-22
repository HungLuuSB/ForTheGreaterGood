--!strict
-- Shield dome field (S-79, client request 40; the user's rules through the
-- client's C-87 prototype). Shared so the server and clients step a shell
-- through a dome's field the same way.
--
-- Since S-93 (the user, client request 42) every enemy shell is destroyed
-- where it reaches the dome (ABSORB_MASS is infinite); the field described
-- below acts only for a finite ABSORB_MASS.
--
-- A dome is a sphere of `radius` round its generator's base. The field
-- fills the outer BAND_SHARE of it (S-83, the user: shells pass through the
-- dome's surface and are slowed and turned inside it); the core within is
-- what it protects. It takes hold of a shell that crosses the surface moving
-- in. Then (S-82, the user's drawing):
--   * it slows the shell along its path, the more the more head-on its line
--     is (the line's closest approach to the centre against the radius;
--     GLANCE_SLOW of it for one that grazes), stronger deeper in;
--   * it steers the shell toward the dome's curve (the tangent where it is):
--     a shell off the centre bends round inside the dome and carries on;
--   * when the shell no longer closes in it turns (the hit, on the dome
--     over it) and is thrown out through the surface: hard for one that
--     stopped or came head-on (straight back), a lift for one sliding round.
-- A shell lighter than ABSORB_MASS is destroyed where it crosses the
-- surface instead (S-85, the user: "small/light shots -> get destroyed
-- instantly"): the step stops there with the ABSORB event.
-- A shell still closing in when it reaches the core breaks through (the
-- breach) and carries on, slowed. Gravity acts throughout, and in the field
-- the dome pulls the shell down by FIELD_GRAVITY more (S-84, the user), so
-- turned shells arc down to land.
--
-- The field's force is `force` (0..1: Shield's charge over FULL_FORCE, so
-- full at 50% charge and above) over the shell's mass to MASS_EXP: a heavy
-- shell takes longer to stop and turn, and a weak dome lets it through. A
-- dome that goes down (force 0) under a shell lets it carry on: a braking
-- shell then counts as through, without a breach event.

local ShieldField = {}

ShieldField.BAND_SHARE = 0.4 -- of the radius: the field's depth inside the dome's surface (S-83)
ShieldField.FULL_FORCE = 0.5 -- charge at and above which the field is at full force
ShieldField.BRAKE = 750 -- studs/s² of braking at full force, mass 1, mid-band, head-on (1.5× C-87's prototype; S-82)
ShieldField.DRAG = 13.5 -- 1/s of drag on the same terms (prototype: 9)
ShieldField.PUSH = 700 -- studs/s² outward after the turn, at full force, mass 1, at the dome, head-on (S-82)
ShieldField.MASS_EXP = 0.6
ShieldField.TANGENT_DRAG = 0.3 -- 1/s on the speed along the surface while thrown out (S-80)
ShieldField.STEER = 8 -- rad/s of steering at full force, mass 1, mid-band (S-82)
ShieldField.GLANCE_SLOW = 0.05 -- the share of the braking and the push for a shell whose line misses the dome (S-82)
ShieldField.HEAD_ON_EXP = 2
-- Shells lighter than this are destroyed where they reach the surface. S-93
-- (the user, client request 42): every shell is, whatever its mass: no
-- braking field, no turning back, no breach. The field below stays for a
-- finite ABSORB_MASS (S-85 had 0.5: heavier shells braked and turned).
ShieldField.ABSORB_MASS = math.huge
ShieldField.FIELD_GRAVITY = 60 -- studs/s² pulling a shell down while it is in the field, whatever its mass (S-84, the user)
ShieldField.STOPPED = 60 -- studs/s: slower than this a shell is thrown out more like a head-on one (S-82)

-- The share of the braking (and of the push out) for a shell whose line
-- passes sqrt(b2) radii from the centre: 1 head-on, cos² of its incidence
-- on the dome, GLANCE_SLOW at least.
function ShieldField.headOn(b2: number): number
	local c = math.sqrt(math.max(0, 1 - b2))
	return math.max(c ^ ShieldField.HEAD_ON_EXP, ShieldField.GLANCE_SLOW)
end

ShieldField.SUBSTEP = 10 -- studs a shell moves per substep at most (8 substeps at most)

-- Phases of a shell against one dome.
ShieldField.FREE = 0 -- not in the field (yet)
ShieldField.BRAKING = 1
ShieldField.REPELLED = 2 -- turned; being thrown out
ShieldField.DONE = 3 -- out of the band after the turn, or through: this dome is done with it

-- Events of a step.
ShieldField.NONE = 0
ShieldField.TURN = 1
ShieldField.BREACH = 2
ShieldField.ABSORB = 3 -- a light shell destroyed where it crossed the surface (S-85)

local sqrt, exp, ceil = math.sqrt, math.exp, math.ceil
local clamp = math.clamp

-- The field's force at `charge` (0..1), before the shell's mass.
function ShieldField.force(charge: number): number
	return clamp(charge / ShieldField.FULL_FORCE, 0, 1)
end

ShieldField.MASS_PER_DAMAGE = 1 / 150 -- a shell's mass from its best damage
ShieldField.MIN_MASS = 0.2
ShieldField.MAX_MASS = 8

-- A weapon's shells' mass: its `shieldMass`, else its best damage over 150
-- (a 150-damage cannon shell is 1), within MIN_MASS..MAX_MASS.
function ShieldField.mass(weapon: { damage: { [string]: number }, shieldMass: number? }): number
	if weapon.shieldMass then
		return weapon.shieldMass
	end
	local best = 0
	for _, d in weapon.damage do
		best = math.max(best, d)
	end
	return clamp(best * ShieldField.MASS_PER_DAMAGE, ShieldField.MIN_MASS, ShieldField.MAX_MASS)
end

-- Steps a shell (position, velocity, gravity `g`) by `dt` against the dome
-- round (cx, cy, cz) of `radius`, with field `force` (0 = down) and the
-- shell's `mass` (1 = a typical shell), from `phase`. Returns the new
-- position, velocity and phase, the event (NONE, TURN, BREACH or ABSORB) and, with
-- an event, the point on the dome's surface over the shell (on its radial
-- line), where the client draws the hit.
function ShieldField.step(
	x: number,
	y: number,
	z: number,
	vx: number,
	vy: number,
	vz: number,
	g: number,
	cx: number,
	cy: number,
	cz: number,
	radius: number,
	force: number,
	mass: number,
	phase: number,
	dt: number
): (number, number, number, number, number, number, number, number, number, number, number)
	local core = radius * (1 - ShieldField.BAND_SHARE)
	local band = radius - core
	local speed = sqrt(vx * vx + vy * vy + vz * vz)
	local n = clamp(ceil(speed * dt / ShieldField.SUBSTEP), 1, 8)
	local h = dt / n
	local k = force / mass ^ ShieldField.MASS_EXP
	local tangentKeep = exp(-ShieldField.TANGENT_DRAG * h)
	local event, hx, hy, hz = ShieldField.NONE, 0, 0, 0
	for _ = 1, n do
		local rx, ry, rz = x - cx, y - cy, z - cz
		local r = sqrt(rx * rx + ry * ry + rz * rz)
		if r > 1e-9 and phase ~= ShieldField.DONE then
			local nx, ny, nz = rx / r, ry / r, rz / r
			local vr = vx * nx + vy * ny + vz * nz
			if force <= 0 and phase ~= ShieldField.FREE then
				phase = ShieldField.DONE -- the dome went down under it
			elseif force > 0 and phase == ShieldField.FREE and r <= radius and r > core and vr < 0 then
				if mass < ShieldField.ABSORB_MASS then
					-- a light shell is destroyed where it crosses the surface (S-85)
					phase = ShieldField.DONE
					event, hx, hy, hz = ShieldField.ABSORB, cx + nx * radius, cy + ny * radius, cz + nz * radius
					break
				end
				phase = ShieldField.BRAKING -- through the surface, moving in (S-83)
			end
			if phase == ShieldField.BRAKING or phase == ShieldField.REPELLED then
				local depth = clamp((radius - r) / band, 0, 1)
				if phase == ShieldField.BRAKING then
					-- slowed along its path, the more the more head-on it comes
					-- in; steered away from the dome, the more the more glancing
					-- (S-82: the user's drawing)
					local sp = sqrt(vx * vx + vy * vy + vz * vz)
					if sp > 1e-9 then
						local ux, uy, uz = vx / sp, vy / sp, vz / sp
						local c = clamp(-vr / sp, 0, 1)
						-- how head-on against the dome itself: its line's closest
						-- approach to the centre, b, against the radius
						local qx, qy, qz = ry * uz - rz * uy, rz * ux - rx * uz, rx * uy - ry * ux
						local b2 = (qx * qx + qy * qy + qz * qz) / (radius * radius)
						local headOn = ShieldField.headOn(b2)
						sp = math.max(0, sp - k * (0.4 + depth) * (ShieldField.BRAKE + ShieldField.DRAG * sp) * headOn * h)
						-- steered toward the dome's curve: the path turns away from the
						-- centre (the outward normal's part across it), at most to the
						-- tangent where it is
						local px, py, pz = nx + c * ux, ny + c * uy, nz + c * uz
						local pl = sqrt(px * px + py * py + pz * pz)
						if pl > 1e-9 then
							local angle = math.min(k * (0.4 + depth) * ShieldField.STEER * h, math.asin(c))
							local ca, sa = math.cos(angle), math.sin(angle) / pl
							ux, uy, uz = ux * ca + px * sa, uy * ca + py * sa, uz * ca + pz * sa
						end
						vx, vy, vz = ux * sp, uy * sp, uz * sp
					end
					-- the turn: it no longer closes in (steering toward the tangent
					-- also turns a shell slowed to almost nothing and bent down by
					-- gravity)
					if event == ShieldField.NONE and vx * nx + vy * ny + vz * nz >= -1e-9 then
						phase = ShieldField.REPELLED
						event, hx, hy, hz = ShieldField.TURN, cx + nx * radius, cy + ny * radius, cz + nz * radius
					end
				else
					-- thrown out: hard for a shell coming straight back, a lift
					-- for one sliding round the dome (S-82)
					local sp = sqrt(vx * vx + vy * vy + vz * vz)
					-- a shell all but stopped counts as head-on
					local headOn = clamp(1 - sp / ShieldField.STOPPED, 0, 1)
					if sp > 1e-6 then
						local qx, qy, qz = ry * vz - rz * vy, rz * vx - rx * vz, rx * vy - ry * vx
						headOn = math.max(headOn, ShieldField.headOn((qx * qx + qy * qy + qz * qz) / (sp * sp * radius * radius)))
					end
					local tx, ty, tz = (vx - nx * vr) * tangentKeep, (vy - ny * vr) * tangentKeep, (vz - nz * vr) * tangentKeep
					vr += k * ShieldField.PUSH * (0.2 + depth) * headOn * h
					vx, vy, vz = nx * vr + tx, ny * vr + ty, nz * vr + tz
					if r > radius then
						phase = ShieldField.DONE -- back out through the surface
					end
				end
			end
		end
		-- exact ballistic substep; in the field the dome pulls down too (S-84)
		local gg = if phase == ShieldField.BRAKING or phase == ShieldField.REPELLED then g + ShieldField.FIELD_GRAVITY else g
		x += vx * h
		y += vy * h - 0.5 * gg * h * h
		z += vz * h
		vy -= gg * h
		if phase == ShieldField.BRAKING then
			local ax, ay, az = x - cx, y - cy, z - cz
			local r2 = ax * ax + ay * ay + az * az
			if r2 <= core * core then
				phase = ShieldField.DONE
				if event == ShieldField.NONE then
					local r = sqrt(r2)
					local s = if r > 1e-9 then radius / r else 0 -- on the surface over it
					event, hx, hy, hz = ShieldField.BREACH, cx + ax * s, cy + ay * s, cz + az * s
				end
			end
		end
	end
	return x, y, z, vx, vy, vz, phase, event, hx, hy, hz
end

-- Is a shell at (x, y, z) moving at (vx, vy, vz) closing in on the dome
-- round (cx, cy, cz) on a line that hits it? (The field takes hold only of
-- such a shell; S-82.)
function ShieldField.onCourse(x: number, y: number, z: number, vx: number, vy: number, vz: number, cx: number, cy: number, cz: number, radius: number): boolean
	local rx, ry, rz = x - cx, y - cy, z - cz
	if rx * vx + ry * vy + rz * vz >= 0 then
		return false
	end
	local qx, qy, qz = ry * vz - rz * vy, rz * vx - rx * vz, rx * vy - ry * vx
	return qx * qx + qy * qy + qz * qz < (vx * vx + vy * vy + vz * vz) * radius * radius
end

-- Can a shell at (x, y, z) moving at `speed` reach the field of a dome
-- round (cx, cy, cz) within `dt`, from outside its core? (A cheap pre-test.)
function ShieldField.near(x: number, y: number, z: number, speed: number, cx: number, cy: number, cz: number, radius: number, dt: number): boolean
	local dx, dy, dz = x - cx, y - cy, z - cz
	local reach = radius + speed * dt + 1
	local core = radius * (1 - ShieldField.BAND_SHARE)
	local d2 = dx * dx + dy * dy + dz * dz
	return d2 <= reach * reach and d2 > core * core
end

return ShieldField

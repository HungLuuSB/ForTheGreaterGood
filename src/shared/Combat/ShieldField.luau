--!strict
-- Shield dome field (S-79, client request 40; the user's rules through the
-- client's C-87 prototype). Shared so the server and clients step a shell
-- through a dome's field the same way.
--
-- A dome is a sphere of `radius` round its generator's base; the field is a
-- band BAND studs deep outside it. An inbound shell that enters the band
-- (outside the dome, moving in) brakes: the field takes off its speed along
-- the dome's normal (a constant part plus drag, stronger deeper in). When
-- that radial speed reaches 0 the shell turns (the hit), and the same field
-- throws it back out, harder the deeper it got, until it leaves the band.
-- A shell still moving in when it reaches the dome breaks through (the
-- breach) and carries on inside, slowed. Speed along the surface bleeds off
-- a little while in the field. Gravity acts throughout.
--
-- The field's force is `force` (0..1: Shield's charge over FULL_FORCE, so
-- full at 50% charge and above) over the shell's mass to MASS_EXP: a heavy
-- shell takes longer to stop, and a weak dome lets it through. A dome that
-- goes down (force 0) under a shell lets it carry on: a braking shell then
-- counts as through, without a breach event.

local ShieldField = {}

ShieldField.BAND = 50 -- studs outside the dome
ShieldField.FULL_FORCE = 0.5 -- charge at and above which the field is at full force
ShieldField.BRAKE = 1000 -- studs/s² of radial braking at full force, mass 1, mid-band (C-87's prototype: 500)
ShieldField.DRAG = 20 -- 1/s of radial drag at full force, mass 1, mid-band (prototype: 9)
ShieldField.PUSH = 1400 -- studs/s² outward after the turn, at full force, mass 1, at the dome
ShieldField.MASS_EXP = 0.6
ShieldField.TANGENT_DRAG = 1.5 -- 1/s on the speed along the surface while in the field
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

local sqrt, exp, abs, ceil = math.sqrt, math.exp, math.abs, math.ceil
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
-- position, velocity and phase, the event (NONE, TURN or BREACH) and, with
-- an event, the point on the dome where it happened (the dome point on the
-- shell's radial line).
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
	local edge = radius + ShieldField.BAND
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
			elseif force > 0 and phase == ShieldField.FREE and r <= edge and r > radius and vr < 0 then
				phase = ShieldField.BRAKING
			end
			if phase == ShieldField.BRAKING or phase == ShieldField.REPELLED then
				local tx, ty, tz = vx - nx * vr, vy - ny * vr, vz - nz * vr
				local depth = clamp((edge - r) / ShieldField.BAND, 0, 1)
				if phase == ShieldField.BRAKING then
					vr += k * (0.4 + depth) * (ShieldField.BRAKE + ShieldField.DRAG * abs(vr)) * h
					if vr >= 0 and event == ShieldField.NONE then
						vr = 0
						phase = ShieldField.REPELLED
						event, hx, hy, hz = ShieldField.TURN, cx + nx * radius, cy + ny * radius, cz + nz * radius
					end
				else
					vr += k * ShieldField.PUSH * (0.2 + depth) * h
					if r > edge then
						phase = ShieldField.DONE
					end
				end
				tx, ty, tz = tx * tangentKeep, ty * tangentKeep, tz * tangentKeep
				vx, vy, vz = nx * vr + tx, ny * vr + ty, nz * vr + tz
			end
		end
		-- exact ballistic substep
		x += vx * h
		y += vy * h - 0.5 * g * h * h
		z += vz * h
		vy -= g * h
		if phase == ShieldField.BRAKING then
			local ax, ay, az = x - cx, y - cy, z - cz
			local r2 = ax * ax + ay * ay + az * az
			if r2 <= radius * radius then
				phase = ShieldField.DONE
				if event == ShieldField.NONE then
					local r = sqrt(r2)
					local s = if r > 1e-9 then radius / r else 0
					event, hx, hy, hz = ShieldField.BREACH, cx + ax * s, cy + ay * s, cz + az * s
				end
			end
		end
	end
	return x, y, z, vx, vy, vz, phase, event, hx, hy, hz
end

-- Can a shell at (x, y, z) moving at `speed` reach the band of a dome round
-- (cx, cy, cz) within `dt` from outside the dome? (A cheap pre-test.)
function ShieldField.near(x: number, y: number, z: number, speed: number, cx: number, cy: number, cz: number, radius: number, dt: number): boolean
	local dx, dy, dz = x - cx, y - cy, z - cz
	local reach = radius + ShieldField.BAND + speed * dt + 1
	local d2 = dx * dx + dy * dy + dz * dz
	return d2 <= reach * reach and d2 > radius * radius
end

return ShieldField

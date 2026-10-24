--!strict
-- How a unit dies on screen (guide 14.6, C-34). Visual only, from the DEATH
-- event: severity (overkill as a fraction of max health, 0..255) and the
-- wreck the server left (wreckId; the server leaves one only when severity
-- ≤ 0.5, Combat.WRECK_MAX_SEVERITY).
--   * a wreck was left: the hull shakes for SHAKE_SECONDS, then the wreck
--     takes its place;
--   * no wreck (a big overkill): 1–3 jointed pieces fly off on ballistic
--     arcs, spinning, for FLING_SECONDS, while the death burst (Effects)
--     plays, and the unit is gone.
-- Velocities come from Shared/Util/Prng seeded by the unit ID, so the same
-- death plays the same way. Pure Luau (C-7); Render/Deaths plays it.

local Prng = require("@shared/Util/Prng")

local Deaths = {}

Deaths.SHAKE_SECONDS = 0.4
Deaths.SHAKE_STUDS = 0.35
Deaths.FLING_SECONDS = 1.0
Deaths.GRAVITY = 60 -- studs/s²
Deaths.MAX_PIECES = 3

export type Piece = { name: string, vx: number, vy: number, vz: number, spin: { number } } -- studs/s in the unit's frame, radians/s
export type Plan = { kind: "shake" | "fling" | "crash", duration: number, wreck: boolean, pieces: { Piece } }

-- muzzles are attachments, not parts to fling: `muzzle`, `muzzle2`, and
-- prefixed ones like Bulwark's `laser_muzzle1` (models-C's Blockout rule)
local function isAttachment(name: string): boolean
	return string.match(name, "^muzzle%d*$") ~= nil or string.match(name, "^%a+_muzzle%d*$") ~= nil
end

-- The animation for a death of unit `id` (a def with `pieces`).
function Deaths.plan(id: number, def: any, severity: number, wreckId: number): Plan
	if wreckId ~= 0 then
		return { kind = "shake", duration = Deaths.SHAKE_SECONDS, wreck = true, pieces = {} }
	end
	local rng = Prng.new(id * 7919 + severity)
	local candidates = {}
	for _, name in def.pieces or {} do
		if name ~= "base" and not isAttachment(name) then
			table.insert(candidates, name)
		end
	end
	local count = math.min(#candidates, rng:nextInteger(1, Deaths.MAX_PIECES))
	local pieces: { Piece } = {}
	for i = 1, count do
		-- the top pieces first (turret, then what hangs from it), the rest shuffled in
		local k = if i == 1 then 1 else rng:nextInteger(1, #candidates)
		local name = table.remove(candidates, k) :: string
		local angle = rng:nextNumber(0, 2 * math.pi)
		local out = rng:nextNumber(6, 16)
		table.insert(pieces, {
			name = name,
			vx = math.cos(angle) * out,
			vy = rng:nextNumber(22, 36),
			vz = math.sin(angle) * out,
			spin = { rng:nextNumber(-9, 9), rng:nextNumber(-9, 9), rng:nextNumber(-9, 9) },
		})
	end
	return { kind = "fling", duration = Deaths.FLING_SECONDS, wreck = false, pieces = pieces }
end

-- Where a flung piece is `t` seconds in (offset from its joint, and its
-- rotation), in the unit's frame.
function Deaths.pieceAt(p: Piece, t: number): (number, number, number, number, number, number)
	return p.vx * t, p.vy * t - 0.5 * Deaths.GRAVITY * t * t, p.vz * t, p.spin[1] * t, p.spin[2] * t, p.spin[3] * t
end

-- Aircraft fall out of the sky (C-48): a unit of the air domain that dies
-- above MIN_CRASH_ALT keeps its momentum and falls, jets diving nose-first
-- and rolling, helicopters spinning down, until it hits the ground, where
-- the crash explodes (Effects) and nothing is left (no wreck, whatever the
-- server says: request 19). The path is fixed by the death record and the
-- unit ID, so the model (Render/Deaths) and the ground explosion
-- (Core/Effects) agree on where and when it hits.
Deaths.MIN_CRASH_ALT = 3 -- studs: lower (landed, on a pad) dies like a ground unit
Deaths.MAX_CRASH_SECONDS = 5
Deaths.CRASH_STEP = 1 / 30 -- seconds: the ground is looked for in these steps, then refined
-- After the hit the wreck keeps falling through the ground out of sight, and
-- the model stays this long, so its smoke trail (particles of the model's
-- emitters) fades out in the air instead of vanishing with it (C-52).
Deaths.CRASH_LINGER = 3
local CRASH = {
	jet = { gravity = 45, drag = 1.0, vy = -4, roll = 4.5, spin = 0 },
	heli = { gravity = 35, drag = 2.2, vy = 0, roll = 0, spin = 7 },
}

export type Crash = {
	x: number, -- where it died
	y: number,
	z: number,
	vx: number, -- its velocity then (studs/s)
	vz: number,
	vy: number,
	heading: number,
	heli: boolean,
	gravity: number,
	drag: number,
	roll: number, -- radians/s (signed)
	spin: number, -- radians/s of yaw (helicopters; signed)
	duration: number, -- seconds until it hits the ground
	ex: number, -- where it hits
	ey: number,
	ez: number,
}

local function crashPos(c: Crash, t: number): (number, number, number)
	local k = c.drag
	local f = (1 - math.exp(-k * t)) / k
	return c.x + c.vx * f, c.y + c.vy * t - 0.5 * c.gravity * t * t, c.z + c.vz * f
end

-- The fall of an aircraft that died (`death`: x, z, heading, alt, vx, vz;
-- `groundAt(x, z)`: the ground height), or nil when it doesn't fall (not an
-- aircraft, or at the ground already).
function Deaths.crash(death: any, def: any, groundAt: (number, number) -> number): Crash?
	if def == nil or def.domain ~= "air" then
		return nil
	end
	local ground0 = groundAt(death.x, death.z)
	local alt = death.alt or 0
	if alt < Deaths.MIN_CRASH_ALT then
		return nil
	end
	local heli = table.find(def.categories or {}, "HELI") ~= nil
	local look = if heli then CRASH.heli else CRASH.jet
	local vx, vz = death.vx or 0, death.vz or 0
	if not heli and vx * vx + vz * vz < 1 then
		-- no speed on record: a jet still flies at its cruise speed
		local speed = ((def.movement or {}).maxSpeed or 150) * 0.7
		vx, vz = math.sin(death.heading) * speed, math.cos(death.heading) * speed
	end
	local rng = Prng.new(death.id * 104729 + 17)
	local sign = if rng:nextNumber(0, 1) < 0.5 then -1 else 1
	local c: Crash = {
		x = death.x,
		y = ground0 + alt,
		z = death.z,
		vx = vx,
		vz = vz,
		vy = look.vy,
		heading = death.heading,
		heli = heli,
		gravity = look.gravity,
		drag = look.drag,
		roll = look.roll * sign,
		spin = look.spin * sign,
		duration = Deaths.MAX_CRASH_SECONDS,
		ex = 0,
		ey = 0,
		ez = 0,
	}
	-- the first step below the ground, then halve the bracket
	local t0, t1 = 0, nil
	local t = 0
	while t < Deaths.MAX_CRASH_SECONDS do
		t += Deaths.CRASH_STEP
		local x, y, z = crashPos(c, t)
		if y <= groundAt(x, z) then
			t1 = t
			break
		end
		t0 = t
	end
	if t1 then
		local lo, hi = t0, t1 :: number
		for _ = 1, 12 do
			local mid = (lo + hi) / 2
			local x, y, z = crashPos(c, mid)
			if y <= groundAt(x, z) then
				hi = mid
			else
				lo = mid
			end
		end
		c.duration = hi
	end
	local x, _, z = crashPos(c, c.duration)
	c.ex, c.ey, c.ez = x, groundAt(x, z), z
	return c
end

-- Where a falling aircraft is `t` seconds in, and how it is turned: x, y, z,
-- heading, pitch (> 0 lifts the nose), roll (> 0 lifts the right side).
-- Past `duration` it goes on falling under the ground (CRASH_LINGER).
function Deaths.crashAt(c: Crash, t: number): (number, number, number, number, number, number)
	local tt = math.clamp(t, 0, c.duration + Deaths.CRASH_LINGER)
	local x, y, z = crashPos(c, tt)
	local h = math.sqrt(c.vx * c.vx + c.vz * c.vz) * math.exp(-c.drag * tt)
	local vy = c.vy - c.gravity * tt
	if c.heli then
		-- spinning down, nose and side dipping more as it goes
		local tip = math.min(1, tt / 1.2)
		return x, y, z, c.heading + c.spin * tt, -0.35 * tip, 0.25 * tip * math.sin(tt * 3)
	end
	return x, y, z, c.heading, math.atan2(vy, math.max(h, 1)), c.roll * tt
end

-- The hull's shake offset at `t` seconds (x, z), easing out.
function Deaths.shakeAt(id: number, t: number): (number, number)
	local fade = math.max(0, 1 - t / Deaths.SHAKE_SECONDS)
	local a = Deaths.SHAKE_STUDS * fade
	return a * math.sin(t * 61 + id), a * math.cos(t * 53 + id * 2)
end

return Deaths

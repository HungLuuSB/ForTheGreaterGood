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
export type Plan = { kind: "shake" | "fling", duration: number, wreck: boolean, pieces: { Piece } }

local function isAttachment(name: string): boolean
	return string.match(name, "^muzzle%d*$") ~= nil
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

-- The hull's shake offset at `t` seconds (x, z), easing out.
function Deaths.shakeAt(id: number, t: number): (number, number)
	local fade = math.max(0, 1 - t / Deaths.SHAKE_SECONDS)
	local a = Deaths.SHAKE_STUDS * fade
	return a * math.sin(t * 61 + id), a * math.cos(t * 53 + id * 2)
end

return Deaths

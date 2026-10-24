--!strict
-- The shield's energy look v4 over time (C-187; models-C's ShieldPreview,
-- fx.md "Shield energy", approved by the user): the pure parts of a frame,
-- ported from the reference's setFrame so Render/ShieldEnergy only moves,
-- shows and fades instances. Values come from Meshes.shieldEnergy.
-- Pure Luau (C-7), tested in tests/client/ShieldEnergyLook.spec.
--
-- v4 states: "off" (the beam fading out), "pre" (the beam lights, the flare
-- swells), "raise" (the dome forms from the apex down), "idle", "collapse"
-- (the reverse, draining up into the apex, a last flash).

local ShieldEnergyLook = {}

export type Timing = { pre: number, raise: number, collapse: number, off: number, pulsePeriod: number, waveCycle: number, jitterStep: number, hitLife: number }

local PI = math.pi

local function frac(x: number): number
	return x - math.floor(x)
end

-- the mock-up's in-out quadratic
function ShieldEnergyLook.ease(x: number): number
	return if x < 0.5 then 2 * x * x else 1 - (-2 * x + 2) ^ 2 / 2
end
local ease = ShieldEnergyLook.ease

-- a cheap repeatable pseudo-random number in 0..1 for an integer-ish seed
-- (the reference's Random.new per step; this allocates nothing per frame)
function ShieldEnergyLook.hash(n: number): number
	return frac(math.sin(n) * 43758.5453)
end
local hash = ShieldEnergyLook.hash

-- ShieldFx's state (ShieldLook: "down" | "deploying" | "up" | "collapsing")
-- `since` seconds in, as the v4 state and the seconds in it.
function ShieldEnergyLook.stateOf(state: string, since: number, t: Timing): (string, number)
	if state == "deploying" then
		if since < t.pre then
			return "pre", since
		end
		return "raise", since - t.pre
	elseif state == "up" then
		return "idle", since
	elseif state == "collapsing" then
		return "collapse", since
	end
	return "off", since
end

-- How long ShieldFx's deploying and collapsing last with v4.
function ShieldEnergyLook.durations(t: Timing): (number, number)
	return t.pre + t.raise, t.collapse
end

-- A frame's envelope: the beam's strength (0..1), the formed front (0 apex
-- .. 1 ground; 1.2 when fully up), the raise/collapse edge crackle's
-- strength (0..1) and the flare's extra size.
function ShieldEnergyLook.envelope(state: string, tState: number, t: Timing): (number, number, number, number)
	if state == "off" then
		return math.max(0, 1 - tState / t.off), 0, 0, 0
	elseif state == "pre" then
		local on = math.min(1, tState / t.pre)
		return on, 0, 0, on
	elseif state == "raise" then
		local p = math.min(1, tState / t.raise)
		return 1, ease(p) * 1.05, 1 - math.max(0, (p - 0.85) / 0.15), 0.6
	elseif state == "idle" then
		return 1, 1.2, 0, 0
	elseif state == "collapse" then
		local p = math.min(1, tState / t.collapse)
		local flash = if p > 0.85 then 2.4 * (p - 0.85) / 0.15 else 0.4
		return 1, 1.05 * (1 - ease(p)), 1, flash
	end
	return 0, 0, 0, 0
end

-- How much of raise/collapse band `k` (1 = at the apex) of `n` shows for a front.
function ShieldEnergyLook.bandReveal(front: number, k: number, n: number): number
	return math.clamp((front - (k - 1) / n) * n / 1.6, 0, 1)
end

-- Wave `i` (0-based) of `count` at time `time`: its age (0..1 of the
-- cycle), its position (0 apex .. 1 ground, accelerating down) and its
-- fade (in over the first 10%, out over the last 22%).
function ShieldEnergyLook.wave(i: number, count: number, time: number, cycle: number): (number, number, number)
	local age = frac(time / cycle + i / count)
	local pos = 0.04 + 0.94 * age ^ 1.3
	local fade = math.min(1, age / 0.1) * (1 - math.max(0, (age - 0.78) / 0.22))
	return age, pos, fade
end

-- A wave joint's polar angle (radians from the apex) at angle `phi` round
-- the dome: never a level circle (the mock-up's wobble × 1.4) plus a
-- little jitter (`seed` changes every jitter step).
function ShieldEnergyLook.waveTheta(pos: number, phi: number, i: number, time: number, seed: number): number
	local wob = 0.03 * math.sin(3 * phi + 2.1 * i + 1.3 * time) + 0.017 * math.sin(7 * phi - 2 * time + i)
	local jitter = (hash(seed) * 2 - 1) * 0.01
	return math.clamp((pos + wob) * PI / 2 + jitter, 0.02, PI / 2 - 0.01)
end

-- A wave joint's brightness round the ring, with small gaps.
function ShieldEnergyLook.waveAlpha(phi: number, i: number, time: number, waveSeed: number, fade: number): number
	local gap = if math.sin(phi * 6 + waveSeed + i * 3 + time * 0.5) > 0.7 then 0.12 else 1
	return fade * gap * (0.45 + 0.55 * math.max(0, math.sin(phi * 4 + i * 1.7 + time * 0.8)))
end

-- How strongly a packet is arriving at the apex (peaks once a period).
function ShieldEnergyLook.arrive(time: number, period: number): number
	local phase = frac(time / period)
	return math.exp(-(phase / 0.1) ^ 2) + math.exp(-((phase - 1) / 0.1) ^ 2)
end

-- A circular arc's Bezier handle length for an arc of `angle` radians on a
-- circle of radius `r` (a curved Beam's CurveSize0/1).
function ShieldEnergyLook.handle(angle: number, r: number): number
	return 4 / 3 * math.tan(angle / 4) * r
end

return ShieldEnergyLook

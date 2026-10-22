--!strict
-- How bright each glow part shines (C-103), pure: the unit glow states of
-- docs/contracts/fx.md ("Unit glow", M-22). Every BAR mesh carries glow
-- parts per channel with a resting strength (GlowStrength); the client
-- drives only their SurfaceAppearance.EmissiveStrength:
--   running  sensor strips, tail lights, exhausts: on while the unit is
--   head     headlights: on
--   power    structures' cores and bands: dim with the team's power on an
--            energy stall (resting × ratio, floor POWER_FLOOR); factories
--            pulse while producing (PULSE_LOW..PULSE_HIGH at PULSE_HZ)
--   weapon   muzzle rings, rails, seekers: flash to FLASH on each shot,
--            back to resting over FLASH_SECONDS
-- A unit still being built is dark (inert until complete, C-99).

local Glow = {}

Glow.POWER_FLOOR = 0.3
Glow.PULSE_LOW = 1.5
Glow.PULSE_HIGH = 4
Glow.PULSE_HZ = 1
Glow.FLASH = 6
Glow.FLASH_SECONDS = 0.3
Glow.EPSILON = 0.02 -- smaller changes aren't written

export type Context = {
	built: boolean, -- complete (build progress 1)
	ratio: number, -- the team's power stall ratio 0..1 (1: no stall; enemies: 1)
	producing: boolean, -- a factory with something in production
	sinceShot: number, -- seconds since its last shot (math.huge: none)
	now: number, -- seconds, for the pulse
	phase: number, -- 0..1, so factories don't pulse in step
}

-- The factory pulse at `now`: PULSE_LOW..PULSE_HIGH, a smooth 1 Hz wave.
function Glow.pulse(now: number, phase: number): number
	local w = 0.5 - 0.5 * math.cos(2 * math.pi * (Glow.PULSE_HZ * now + phase))
	return Glow.PULSE_LOW + (Glow.PULSE_HIGH - Glow.PULSE_LOW) * w
end

-- The strength of a glow part of `channel` resting at `rest`.
function Glow.strength(channel: string, rest: number, c: Context): number
	if not c.built then
		return 0
	end
	if channel == "power" then
		local base = if c.producing then Glow.pulse(c.now, c.phase) else rest
		return math.max(base * math.clamp(c.ratio, 0, 1), Glow.POWER_FLOOR)
	elseif channel == "weapon" then
		local t = c.sinceShot / Glow.FLASH_SECONDS
		if t >= 1 then
			return rest
		end
		local k = (1 - t) * (1 - t) -- quick fall, soft landing
		return rest + (Glow.FLASH - rest) * k
	end
	return rest -- running, head
end

-- Whether a part shown at `shown` needs writing for `target`.
function Glow.changed(shown: number, target: number): boolean
	return math.abs(shown - target) >= Glow.EPSILON or (target == 0) ~= (shown == 0)
end

return Glow

--!strict
-- How bright each glow part shines (C-103), pure: the unit glow states of
-- docs/contracts/fx.md ("Unit glow", M-22). Every BAR mesh carries glow
-- parts per channel with a resting strength (GlowStrength); the client
-- drives only their SurfaceAppearance.EmissiveStrength:
--   running  sensor strips, tail lights, exhausts: on while the unit is
--   head     headlights: on
--   power    structures' cores and bands: dim with the team's power on an
--            energy stall (resting × ratio, floor POWER_FLOOR); factories
--            pulse while producing (PULSE_LOW..PULSE_HIGH at PULSE_HZ; 1.5..3)
--   weapon   muzzle rings, rails, seekers: flash to FLASH on each shot,
--            back to resting over FLASH_SECONDS
-- A `pulse` piece's glow (rig.md section 9: fusion cores, converter coils
-- and crucibles, capacitor cells; models-C) breathes slowly about its
-- resting strength (CORE_LOW..CORE_HIGH × rest at CORE_HZ), dimmed by the
-- stall as its channel is.
-- A unit still being built is dark (inert until complete, C-99).
-- The graphics setting's level (C-106): "off" all dark; "low" the resting
-- glow with the stall dimming (rare writes); "high" also the factory pulse
-- and the weapon flash.

local Glow = {}

Glow.POWER_FLOOR = 0.3
Glow.PULSE_LOW = 1.5
Glow.PULSE_HIGH = 3 -- 4 blew the Order vehicle plant door out to a white block under the night bloom (C-106)
Glow.PULSE_HZ = 1
Glow.FLASH = 6
Glow.FLASH_SECONDS = 0.3
Glow.EPSILON = 0.02 -- smaller changes aren't written
Glow.CORE_LOW, Glow.CORE_HIGH = 0.55, 1.45 -- a pulse piece's breath, × its resting strength
Glow.CORE_HZ = 0.5

-- Team colors that clash with a faction's glow (docs/contracts/fx.md, C's
-- check of the 8 lobby colors): there the unit's running and power glow
-- turn white, strengths unchanged; head and weapon stay (C-106).
Glow.CLASH_WHITE = table.freeze({ 235, 240, 245 })
Glow.CLASHES = table.freeze({
	order = table.freeze({ [7] = true }), -- cyan team on Order's cyan glow
	chaos = table.freeze({ [6] = true }), -- orange team on Chaos's amber and orange glow
}) :: { [string]: { [number]: boolean } }

-- Whether a `faction` unit of team `team` shows its `channel` glow white.
function Glow.clashes(faction: string?, team: number, channel: string): boolean
	if channel ~= "running" and channel ~= "power" then
		return false
	end
	local teams = faction and Glow.CLASHES[faction]
	return teams ~= nil and teams[team] == true
end

export type Context = {
	built: boolean, -- complete (build progress 1)
	ratio: number, -- the team's power stall ratio 0..1 (1: no stall; enemies: 1)
	producing: boolean, -- a factory with something in production
	sinceShot: number, -- seconds since its last shot (math.huge: none)
	now: number, -- seconds, for the pulse
	phase: number, -- 0..1, so factories don't pulse in step
	level: string?, -- "off" | "low" | "high" (nil: high)
	retracted: boolean?, -- a beam tower switched off (S-96): power at its floor, weapon dark (C-114, models-C's note)
}

-- The factory pulse at `now`: PULSE_LOW..PULSE_HIGH, a smooth 1 Hz wave.
function Glow.pulse(now: number, phase: number): number
	local w = 0.5 - 0.5 * math.cos(2 * math.pi * (Glow.PULSE_HZ * now + phase))
	return Glow.PULSE_LOW + (Glow.PULSE_HIGH - Glow.PULSE_LOW) * w
end

-- A pulse piece's breath at `now`: CORE_LOW..CORE_HIGH, a smooth wave.
function Glow.breath(now: number, phase: number): number
	local w = 0.5 - 0.5 * math.cos(2 * math.pi * (Glow.CORE_HZ * now + phase))
	return Glow.CORE_LOW + (Glow.CORE_HIGH - Glow.CORE_LOW) * w
end

-- The strength of a glow part of `channel` resting at `rest`; `pulsing`
-- for a part on a `pulse` piece.
function Glow.strength(channel: string, rest: number, c: Context, pulsing: boolean?): number
	if not c.built or c.level == "off" then
		return 0
	end
	local full = c.level ~= "low"
	if c.retracted and (channel == "power" or channel == "weapon") then
		return if channel == "power" then Glow.POWER_FLOOR else 0
	end
	if pulsing and full and channel ~= "weapon" then
		rest *= Glow.breath(c.now, c.phase)
	end
	if channel == "power" then
		local base = if c.producing and full then Glow.pulse(c.now, c.phase) else rest
		return math.max(base * math.clamp(c.ratio, 0, 1), Glow.POWER_FLOOR)
	elseif channel == "weapon" then
		local t = if full then c.sinceShot / Glow.FLASH_SECONDS else 1
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

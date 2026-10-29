--!strict
-- Juggernaut's heat ray (S-209, H40; BAR corkorg): an immensely powerful
-- single-target laser, red outside with an orange-white core; charged while
-- it reloads (S-205).
return {
	id = "chs_juggernaut_heatray",
	type = "BEAM",
	range = 230, -- shorter T3 range (S-213, the user): was 300
	closeDamage = 1.5,
	reload = 3,
	accuracy = 0,
	damage = { LIGHT = 2400, ARMORED = 2400, STRUCTURE = 1800, SHIP = 2400, AIR = 0, SUB = 0 }, -- over the whole beam
	beamDuration = 1.5,
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 300 },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 1, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy", color = { r = 255, g = 40, b = 20 } }, -- red outside, orange-white core (client)
}

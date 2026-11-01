--!strict
-- Ravener's ray (S-233, batch 2; BAR's cortermite).
return {
	id = "chs_ravener_ray",
	type = "HITSCAN",
	range = 120,
	reload = 1,
	damage = { LIGHT = 290, ARMORED = 260, STRUCTURE = 230, SHIP = 250, AIR = 0, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 180, pitchRate = 90, tolerance = 3, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_hum", color = { r = 255, g = 120, b = 30 } },
}

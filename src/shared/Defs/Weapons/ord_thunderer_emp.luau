--!strict
-- Thunderer's EMP projector (S-229; BAR's armthor EMP lasers, both in one):
-- its hits fill the target's stun bar instead of taking health (Paralyze).
return {
	id = "ord_thunderer_emp",
	type = "HITSCAN",
	range = 260,
	reload = 1,
	paralyzer = true,
	paralyzeSeconds = 6,
	damage = { LIGHT = 1000, ARMORED = 1000, STRUCTURE = 1000, SHIP = 1000, AIR = 0, SUB = 0 },
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 4, minPitch = -10, maxPitch = 20, arc = 360 },
	fx = { muzzle = "flash_small", impact = "explosion_small", sound = "laser" },
}

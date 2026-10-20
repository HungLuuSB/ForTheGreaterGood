--!strict
-- Bomber bomb: released at the computed lead point, falls with the bomber's velocity.
return {
	id = "ord_bomb",
	type = "BOMB",
	range = 800, -- acquisition radius; release is computed (D91)
	reload = 1.5,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 378, ARMORED = 342, STRUCTURE = 450, SHIP = 360, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	fx = { impact = "explosion_large", sound = "bomb" },
}

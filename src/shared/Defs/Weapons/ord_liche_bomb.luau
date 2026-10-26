--!strict
-- Liche's bomb: one devastating blast (S-181, the playtest's new units).
return {
	id = "ord_liche_bomb",
	type = "BOMB",
	range = 800, -- acquisition radius; release is computed (D91)
	canTargetRadar = true,
	reload = 1,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 3000, ARMORED = 2800, STRUCTURE = 4000, SHIP = 3000, AIR = 0, SUB = 0 },
	aoe = 55,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	fx = { impact = "explosion_huge", sound = "bomb_heavy" },
}

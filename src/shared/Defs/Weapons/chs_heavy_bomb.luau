--!strict
-- Strategic bomber payload: released at the computed lead point.
return {
	id = "chs_heavy_bomb",
	type = "BOMB",
	range = 800, -- acquisition radius; release is computed (D91)
	canTargetRadar = true, -- radar contacts (wobbled position) and structure ghosts (D96)
	reload = 2.5,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 990, ARMORED = 880, STRUCTURE = 1320, SHIP = 990, AIR = 0, SUB = 0 },
	aoe = 22,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	fx = { impact = "explosion_huge", sound = "bomb_heavy" },
}

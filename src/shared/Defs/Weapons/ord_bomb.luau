--!strict
-- Bomber bomb: released at the computed lead point, falls with the bomber's velocity.
-- S-179, the playtest's balance notes: T1 bombers' damage × 0.8
return {
	id = "ord_bomb",
	type = "BOMB",
	range = 800, -- acquisition radius; release is computed (D91)
	canTargetRadar = true, -- radar contacts (wobbled position) and structure ghosts (D96)
	salvo = { count = 3, delay = 0.2 }, -- a carpet: three bombs along the heading (S-178, F33)
	reload = 1.5,
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 151, ARMORED = 137, STRUCTURE = 180, SHIP = 144, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	fx = { impact = "explosion_large", sound = "bomb" },
}

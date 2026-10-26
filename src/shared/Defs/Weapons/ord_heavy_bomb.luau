--!strict
-- Strategic bomber payload: released at the computed lead point.
return {
	id = "ord_heavy_bomb",
	type = "BOMB",
	range = 800, -- acquisition radius; release is computed (D91)
	canTargetRadar = true, -- radar contacts (wobbled position) and structure ghosts (D96)
	salvo = { count = 3, delay = 0.25 }, -- a carpet: three bombs along the heading (S-178, F33)
	reload = 6.5, -- 2.5 + the 4 s rearm per round it no longer flies home for (S-194, G17: no ammo)
	gravity = 60,
	accuracy = 2,
	damage = { LIGHT = 405, ARMORED = 360, STRUCTURE = 540, SHIP = 405, AIR = 0, SUB = 0 },
	aoe = 22,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	fx = { impact = "explosion_huge", sound = "bomb_heavy" },
}

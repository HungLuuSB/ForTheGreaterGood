--!strict
-- Juggernaut's heavy cannon: the heavy turret gun, carried on arms that rest
-- lowered (guide 14.4, S-20). Raising them from rest to a level shot takes
-- ~0.8 s, and they stay up 3 s after the last target before lowering.
return {
	id = "chs_goliath_cannon",
	type = "BALLISTIC",
	range = 195, -- faction pass (S-62)
	reload = 2.2, -- faction pass, tuned (S-62)
	projectileSpeed = 420,
	gravity = 60,
	accuracy = 0.6,
	damage = { LIGHT = 285, ARMORED = 266, STRUCTURE = 228, SHIP = 209, AIR = 0, SUB = 0 }, -- +15%, tier rebalance (S-157, the user)
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 70, pitchRate = 80, tolerance = 3, minPitch = -65, maxPitch = 20, arc = 360, restPitch = -65, restoreDelay = 3 },
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "cannon_heavy" },
}

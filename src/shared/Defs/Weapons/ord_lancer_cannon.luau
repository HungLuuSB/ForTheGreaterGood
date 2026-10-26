--!strict
-- Split from ord_light_cannon (S-179, the playtest's balance notes) so its users can be balanced apart.
-- Order T1 tank gun: longer range and tighter spread than Chaos, less damage.
-- S-179, the playtest's balance notes: a T1 unit's range halved, damage × 0.8 (four Lancer shells no longer kill an extractor)
return {
	id = "ord_lancer_cannon",
	type = "BALLISTIC",
	range = 95, -- tier rebalance (S-157, the user): was 210; faction pass (S-62)
	reload = 1.75, -- faction pass, tuned (S-62)
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 380,
	gravity = 60,
	accuracy = 0.4, -- faction pass (S-62)

	damage = { LIGHT = 132, ARMORED = 113, STRUCTURE = 94, SHIP = 85, AIR = 0, SUB = 0 },
	aoe = 3,
	edgeEffectiveness = 0.4,

	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },

	turret = { yawRate = 100, pitchRate = 60, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },

	fx = { muzzle = "flash_small", impact = "explosion_small", sound = "cannon_light" },
}

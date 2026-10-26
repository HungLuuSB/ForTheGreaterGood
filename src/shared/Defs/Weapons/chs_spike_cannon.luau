--!strict
-- Split from chs_light_cannon (S-179, the playtest's balance notes) so its users can be balanced apart.
-- Chaos T1 tank gun: shorter range and wider spread, harder hitting, faster reload.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "chs_spike_cannon",
	type = "BALLISTIC",
	range = 155, -- tier rebalance (S-157, the user): was 170; faction pass (S-62)
	reload = 1.4, -- faction pass, tuned (S-62)
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 340,
	gravity = 60,
	accuracy = 1.45, -- faction pass, tuned (S-62)

	damage = { LIGHT = 261, ARMORED = 219, STRUCTURE = 192, SHIP = 165, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.3,

	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },

	turret = { yawRate = 130, pitchRate = 50, tolerance = 4, minPitch = -10, maxPitch = 20, arc = 360 },

	fx = { muzzle = "flash_small", impact = "explosion_small", sound = "cannon_heavy" },
}

--!strict
-- Locust's autocannon (S-75): short range, fast and light rounds.
-- S-179, the playtest's balance notes: a T1 unit's range halved, damage × 0.8 (four Lancer shells no longer kill an extractor)
return {
	id = "chs_autocannon",
	type = "BALLISTIC",
	range = 55, -- tier rebalance (S-157, the user): was 120
	reload = 0.5,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 420,
	gravity = 60,
	accuracy = 2.2,
	damage = { LIGHT = 30, ARMORED = 23, STRUCTURE = 18, SHIP = 16, AIR = 0, SUB = 0 }, -- +10% (S-112: the Locust's punch)
	aoe = 2,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 160, pitchRate = 80, tolerance = 5, minPitch = -10, maxPitch = 25, arc = 360 },
	fx = { muzzle = "flash_small", impact = "impact_small", sound = "autocannon" },
}

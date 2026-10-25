--!strict
-- Split from ord_naval_gun (S-179, the playtest's balance notes) so its users can be balanced apart.
-- Ship gun: ballistic, against ships, the coast and structures.
-- S-179, the playtest's balance notes: a T1 unit's range halved, damage × 0.8 (four Lancer shells no longer kill an extractor)
return {
	id = "ord_sentry_gun",
	type = "BALLISTIC",
	range = 130,
	reload = 2.2,
	projectileSpeed = 360,
	gravity = 60,
	accuracy = 0.8,
	damage = { LIGHT = 128, ARMORED = 112, STRUCTURE = 128, SHIP = 136, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.3,
	targets = { "NAVAL", "GROUND", "STRUCTURE" },
	priority = { "NAVAL", "STRUCTURE", "GROUND" },
	turret = { yawRate = 70, pitchRate = 40, tolerance = 3, minPitch = -10, maxPitch = 35, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_medium", sound = "naval_gun" },
}

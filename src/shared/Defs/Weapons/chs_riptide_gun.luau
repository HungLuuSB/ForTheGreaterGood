--!strict
-- Split from chs_naval_gun (S-179, the playtest's balance notes) so its users can be balanced apart.
-- Ship gun: ballistic, against ships, the coast and structures.
-- S-179, the playtest's balance notes: a T1 defence's damage × 2 (too weak against T1 units)
return {
	id = "chs_riptide_gun",
	type = "BALLISTIC",
	range = 240,
	reload = 2.2,
	projectileSpeed = 360,
	gravity = 60,
	accuracy = 0.8,
	damage = { LIGHT = 360, ARMORED = 320, STRUCTURE = 360, SHIP = 380, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.3,
	targets = { "NAVAL", "GROUND", "STRUCTURE" },
	priority = { "NAVAL", "STRUCTURE", "GROUND" },
	turret = { yawRate = 70, pitchRate = 40, tolerance = 3, minPitch = -10, maxPitch = 35, arc = 360 },
	fx = { muzzle = "flash_medium", impact = "explosion_medium", sound = "naval_gun" },
}

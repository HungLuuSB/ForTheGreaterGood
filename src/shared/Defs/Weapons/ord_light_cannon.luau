--!strict
-- Order T1 tank gun: longer range and tighter spread than Chaos, less damage.
return {
	id = "ord_light_cannon",
	type = "BALLISTIC",
	range = 200,
	reload = 1.6,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 380,
	gravity = 60,
	accuracy = 0.5,

	damage = { LIGHT = 140, ARMORED = 120, STRUCTURE = 100, SHIP = 90, AIR = 0, SUB = 0 },
	aoe = 3,
	edgeEffectiveness = 0.4,

	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },

	turret = { yawRate = 120, pitchRate = 60, tolerance = 3, minPitch = -10, maxPitch = 20, arc = 360 },

	fx = { muzzle = "flash_small", impact = "explosion_small", sound = "cannon_light" },
}

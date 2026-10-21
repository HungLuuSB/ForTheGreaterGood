--!strict
-- Chaos T1 tank gun: shorter range and wider spread, harder hitting, faster reload.
return {
	id = "chs_light_cannon",
	type = "BALLISTIC",
	range = 170, -- faction pass (S-62)
	reload = 1.4, -- faction pass, tuned (S-62)
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 340,
	gravity = 60,
	accuracy = 1.45, -- faction pass, tuned (S-62)

	damage = { LIGHT = 131, ARMORED = 109, STRUCTURE = 96, SHIP = 83, AIR = 0, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.3,

	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },

	turret = { yawRate = 130, pitchRate = 50, tolerance = 4, minPitch = -10, maxPitch = 20, arc = 360 },

	fx = { muzzle = "flash_small", impact = "explosion_small", sound = "cannon_heavy" },
}

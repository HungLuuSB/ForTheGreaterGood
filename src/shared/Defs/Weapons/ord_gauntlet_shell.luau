--!strict
-- Gauntlet's lobbed shell (S-157, the user: "shoot high trajectory
-- projectile, medium range"): the high arc, over walls and ridges; slow to
-- land, so it hits what stands still.
return {
	id = "ord_gauntlet_shell",
	type = "BALLISTIC",
	range = 420,
	reload = 3.6,
	projectileSpeed = 165,
	gravity = 60,
	highArc = true,
	accuracy = 1.5,
	damage = { LIGHT = 230, ARMORED = 210, STRUCTURE = 270, SHIP = 180, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARTILLERY", "STRUCTURE", "GROUND" },
	turret = { yawRate = 45, pitchRate = 35, tolerance = 2, minPitch = 20, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_large", trail = "smoke_small", impact = "explosion_medium", sound = "mortar" },
}

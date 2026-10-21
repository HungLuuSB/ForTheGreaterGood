--!strict
-- Locust's autocannon (S-75): short range, fast and light rounds.
return {
	id = "chs_autocannon",
	type = "BALLISTIC",
	range = 120,
	reload = 0.5,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 420,
	gravity = 60,
	accuracy = 2.2,
	damage = { LIGHT = 34, ARMORED = 26, STRUCTURE = 20, SHIP = 18, AIR = 0, SUB = 0 },
	aoe = 2,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 160, pitchRate = 80, tolerance = 5, minPitch = -10, maxPitch = 25, arc = 360 },
	fx = { muzzle = "flash_small", impact = "impact_small", sound = "autocannon" },
}

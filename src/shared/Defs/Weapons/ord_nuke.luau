--!strict
-- Reckoning warhead (S-48, client request 26): strategic missile, fired only
-- on an attack-ground order, anywhere on the map. Lofted to 300 studs, ~12.7 s
-- in the air whatever the distance, so radar SAMs get time to intercept it.
return {
	id = "ord_nuke",
	type = "BALLISTIC",
	range = 8192, -- anywhere on the map
	reload = 10,
	projectileSpeed = 300, -- nominal: `apex` sets the launch velocity
	gravity = 15,
	apex = 300, -- low enough to stay on screen (S-49, the user asked)
	accuracy = 0,
	strategic = true,
	manualFire = true,
	stockpile = { capacity = 2, buildTime = 120, cost = { supply = 1500, power = 40000 } },
	damage = { LIGHT = 8000, ARMORED = 8000, STRUCTURE = 10000, SHIP = 8000, AIR = 4000, SUB = 3000 },
	aoe = 150,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	fx = { muzzle = "nuke_launch", trail = "smoke_huge", impact = "explosion_nuke", sound = "nuke_launch" },
}

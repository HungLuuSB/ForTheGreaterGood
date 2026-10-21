--!strict
-- Ragnarok warhead (S-48, client request 26): strategic missile, fired only
-- on an attack-ground order, anywhere on the map. Same flight as Order's.
return {
	id = "chs_nuke",
	type = "BALLISTIC",
	range = 8192, -- anywhere on the map
	reload = 10,
	projectileSpeed = 300, -- nominal: `apex` sets the launch velocity
	gravity = 40,
	apex = 800,
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

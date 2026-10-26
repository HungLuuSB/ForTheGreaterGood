--!strict
-- Cyclops's siege mortar (S-75): structures only, from 520 studs; it may
-- shell remembered structures (ghosts) and radar contacts of them.
-- S-179, the playtest's balance notes: T2 artillery: damage × 0.8
return {
	id = "chs_siege_mortar",
	type = "BALLISTIC",
	range = 520,
	reload = 8,
	salvo = { count = 1, delay = 0 },
	projectileSpeed = 240,
	gravity = 60,
	accuracy = 1.0,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 1104, SHIP = 0, AIR = 0, SUB = 0 }, -- +15%, tier rebalance (S-157, the user)
	aoe = 10,
	edgeEffectiveness = 0.3,
	targets = { "STRUCTURE" },
	priority = { "STRUCTURE" },
	canTargetRadar = true,
	turret = { yawRate = 30, pitchRate = 25, tolerance = 2, minPitch = -5, maxPitch = 60, arc = 360 },
	fx = { muzzle = "flash_large", impact = "explosion_large", sound = "mortar_heavy" },
}

--!strict
-- MLRS rockets: long-range saturation, inaccurate; can fire at radar contacts.
-- S-179, the playtest's balance notes: T2 artillery: damage × 0.8
return {
	id = "ord_mlrs",
	type = "BALLISTIC",
	rocket = true, -- point defence intercepts it (S-149)
	range = 560, -- faction pass (S-62)
	reload = 7.15, -- faction pass, tuned (S-62)
	projectileSpeed = 260,
	gravity = 60,
	accuracy = 1.32, -- faction pass, tuned (S-62)
	salvo = { count = 4, delay = 0.3 }, -- 4 precise rockets (S-69)
	damage = { LIGHT = 46, ARMORED = 36, STRUCTURE = 43, SHIP = 36, AIR = 0, SUB = 0 }, -- per rocket: 90% of what one shot did (S-69, tuned)
	aoe = 16,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 3, minPitch = 0, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "rocket_launch", trail = "smoke_thick", impact = "explosion_medium", sound = "mlrs" },
}

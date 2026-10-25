--!strict
-- Verdict's gun: long-range ballistic artillery that may target radar contacts.
-- S-179, the playtest's balance notes: T1 artillery: range halved, damage × 0.6 (it was far too strong)
return {
	id = "ord_howitzer",
	type = "BALLISTIC",
	range = 240, -- faction pass (S-62)
	reload = 4.4, -- faction pass (S-62)
	projectileSpeed = 130, -- (S-179) slower with the halved range, so the shell still arcs about 30° at full range and clears hills (peaks ~35 studs up)
	gravity = 60,
	accuracy = 0.5, -- faction pass (S-62)
	damage = { LIGHT = 223, ARMORED = 197, STRUCTURE = 276, SHIP = 171, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 40, pitchRate = 30, tolerance = 2, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "howitzer" },
}

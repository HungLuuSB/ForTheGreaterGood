--!strict
-- Hellmouth's gun: heavy, inaccurate ballistic mortar that may target radar contacts.
-- S-179, the playtest's balance notes: T1 artillery: range halved, damage × 0.6 (it was far too strong)
return {
	id = "chs_mortar",
	type = "BALLISTIC",
	range = 190, -- faction pass (S-62)
	reload = 3, -- faction pass (S-62)
	projectileSpeed = 112, -- (S-179) slower with the halved range, so the lob still arcs about 35° at full range and clears hills (peaks ~33 studs up)
	gravity = 60,
	accuracy = 2, -- faction pass (S-62)
	damage = { LIGHT = 177, ARMORED = 157, STRUCTURE = 216, SHIP = 137, AIR = 0, SUB = 0 },
	aoe = 14,
	edgeEffectiveness = 0.3,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARTILLERY", "GROUND" },
	turret = { yawRate = 35, pitchRate = 28, tolerance = 2.5, minPitch = -5, maxPitch = 60, arc = 360 },
	canTargetRadar = true,
	fx = { muzzle = "flash_large", impact = "explosion_medium", sound = "mortar" },
}

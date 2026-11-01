--!strict
-- Firebrand's rocket (S-233, batch 2; BAR's corstorm).
return {
	id = "chs_firebrand_rocket",
	type = "HOMING",
	range = 170,
	reload = 4.8,
	projectileSpeed = 160,
	accuracy = 1,
	turnRate = 60,
	guidance = "IR",
	lockRange = 170,
	terminalRange = 30,
	damage = { LIGHT = 170, ARMORED = 150, STRUCTURE = 140, SHIP = 140, AIR = 0, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 60, arc = 360 },
	fx = { muzzle = "rocket_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rocket" },
}

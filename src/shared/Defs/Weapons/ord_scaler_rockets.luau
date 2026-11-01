--!strict
-- Scaler's rockets (S-233, batch 2; BAR's armsptk).
return {
	id = "ord_scaler_rockets",
	type = "HOMING",
	range = 200,
	reload = 4.8,
	salvo = { count = 3, delay = 0.2 },
	projectileSpeed = 200,
	accuracy = 1,
	turnRate = 60,
	guidance = "IR",
	lockRange = 200,
	terminalRange = 30,
	damage = { LIGHT = 220, ARMORED = 200, STRUCTURE = 180, SHIP = 190, AIR = 0, SUB = 0 },
	aoe = 10,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 60, arc = 360 },
	fx = { muzzle = "rocket_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rocket" },
}

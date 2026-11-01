--!strict
-- Skyguard's long (S-233, batch 2; BAR's armaak).
return {
	id = "ord_skyguard_long",
	type = "HOMING",
	range = 300,
	reload = 1.7,
	projectileSpeed = 420,
	accuracy = 0.5,
	turnRate = 180,
	guidance = "IR",
	lockRange = 300,
	terminalRange = 40,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 170, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "HELI", "JET", "AIR" },
	turret = { yawRate = 240, pitchRate = 240, tolerance = 15, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "sam_ir" },
}

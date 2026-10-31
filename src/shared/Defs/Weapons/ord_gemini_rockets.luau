--!strict
-- Gemini's twin guided rockets (S-230; BAR's armjanus).
return {
	id = "ord_gemini_rockets",
	type = "HOMING",
	range = 110,
	reload = 2.5,
	salvo = { count = 2, delay = 0.25 },
	projectileSpeed = 260,
	accuracy = 1,
	turnRate = 80,
	guidance = "IR",
	lockRange = 110,
	terminalRange = 30,
	damage = { LIGHT = 80, ARMORED = 95, STRUCTURE = 76, SHIP = 81, AIR = 0, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 60, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rocket" },
}

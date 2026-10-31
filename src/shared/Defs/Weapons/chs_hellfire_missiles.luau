--!strict
-- Hellfire's heavy guided missiles (S-230; BAR's corban).
return {
	id = "chs_hellfire_missiles",
	type = "HOMING",
	range = 240,
	reload = 3,
	salvo = { count = 2, delay = 0.25 },
	projectileSpeed = 260,
	accuracy = 1,
	turnRate = 80,
	guidance = "IR",
	lockRange = 280,
	terminalRange = 30,
	damage = { LIGHT = 150, ARMORED = 180, STRUCTURE = 170, SHIP = 153, AIR = 0, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 60, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rocket" },
}

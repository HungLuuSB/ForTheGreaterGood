--!strict
-- Widowmaker's missiles (S-233, batch 2; BAR's corkarg).
return {
	id = "chs_widowmaker_missiles",
	type = "HOMING",
	range = 210,
	reload = 0.75,
	projectileSpeed = 270,
	accuracy = 1,
	turnRate = 90,
	guidance = "IR",
	lockRange = 210,
	terminalRange = 30,
	damage = { LIGHT = 390, ARMORED = 350, STRUCTURE = 310, SHIP = 330, AIR = 0, SUB = 0 },
	aoe = 7,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 60, arc = 360 },
	fx = { muzzle = "rocket_launch", trail = "smoke_thin", impact = "explosion_small", sound = "rocket" },
}

--!strict
-- Pandemonium's rockets (S-233, batch 2; BAR's corcat).
return {
	id = "chs_pandemonium_rockets",
	type = "HOMING",
	range = 360,
	reload = 19,
	salvo = { count = 10, delay = 0.15 },
	projectileSpeed = 240,
	accuracy = 1,
	turnRate = 60,
	guidance = "IR",
	lockRange = 360,
	terminalRange = 30,
	damage = { LIGHT = 1000, ARMORED = 900, STRUCTURE = 800, SHIP = 850, AIR = 0, SUB = 0 },
	aoe = 11,
	edgeEffectiveness = 0.4,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "STRUCTURE", "ARMORED", "GROUND" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 60, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_medium", sound = "rockets" },
}

--!strict
-- Skua's anti-air missiles (S-230; BAR's corah).
return {
	id = "chs_skua_aa",
	type = "HOMING",
	range = 220,
	reload = 2.5,
	projectileSpeed = 450,
	accuracy = 0.5,
	turnRate = 200,
	guidance = "IR",
	lockRange = 220,
	terminalRange = 40,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 200, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "HELI", "JET", "AIR" },
	turret = { yawRate = 240, pitchRate = 240, tolerance = 15, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "sam_ir" },
}

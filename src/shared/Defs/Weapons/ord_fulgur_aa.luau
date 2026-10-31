--!strict
-- Fulgur's light anti-air missile (S-230; BAR's armlatnk).
return {
	id = "ord_fulgur_aa",
	type = "HOMING",
	range = 190,
	reload = 2.5,
	projectileSpeed = 450,
	accuracy = 0.5,
	turnRate = 200,
	guidance = "IR",
	lockRange = 190,
	terminalRange = 40,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 160, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "HELI", "JET", "AIR" },
	turret = { yawRate = 240, pitchRate = 240, tolerance = 15, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "sam_ir" },
}

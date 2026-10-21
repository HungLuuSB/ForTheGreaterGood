--!strict
-- Vigil missile: IR homing, unaffected by jamming; flares and DIRCM defeat it.
return {
	id = "ord_ir_sam",
	type = "HOMING",
	range = 147, -- −30% twice (S-55, S-56; the user asked)
	reload = 2.5,
	projectileSpeed = 420,
	accuracy = 1,
	turnRate = 160,
	guidance = "IR",
	lockRange = 147,
	terminalRange = 30,
	stockpile = { capacity = 8, buildTime = 6, cost = { supply = 15, power = 300 } }, -- missiles in stock (S-47); Hornet / Halo carry 4
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 220, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "HELI", "JET", "AIR" },
	turret = { yawRate = 180, pitchRate = 120, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "sam_ir" },
}

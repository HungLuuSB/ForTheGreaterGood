--!strict
-- Thorn missile: IR homing, cheaper and faster-firing than Vigil.
return {
	id = "chs_ir_sam",
	type = "HOMING",
	range = 165, -- faction pass (S-62)
	reload = 1.7, -- faction pass (S-62)
	projectileSpeed = 500,
	accuracy = 1,
	turnRate = 160,
	guidance = "IR",
	lockRange = 165, -- faction pass (S-62)
	terminalRange = 30,
	stockpile = { capacity = 10, buildTime = 6, cost = { supply = 12, power = 240 } }, -- missiles in stock (S-47; Chaos 10 at 12 + 240, S-62); Hornet carries 5
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 180, SUB = 0 },
	aoe = 12,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "HELI", "JET", "AIR" },
	turret = { yawRate = 180, pitchRate = 120, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "sam_ir" },
}

--!strict
-- Crusader's naval SAM: radar-guided, medium range (fleet air defence, D97);
-- jamming blocks it beyond burn-through, chaff decoys it.
return {
	id = "ord_naval_sam",
	type = "HOMING",
	range = 380,
	reload = 3.5,
	projectileSpeed = 380,
	accuracy = 1,
	turnRate = 110,
	guidance = "RADAR",
	lockRange = 380,
	burnThrough = 0.35,
	terminalRange = 40,
	canTargetRadar = true,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 300, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.4,
	targets = { "AIR" },
	priority = { "JET", "HELI", "AIR" },
	turret = { yawRate = 120, pitchRate = 80, tolerance = 10, minPitch = -5, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch", trail = "smoke_thick", impact = "explosion_air", sound = "sam_radar" },
}

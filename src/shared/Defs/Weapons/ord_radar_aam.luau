--!strict
-- Archon missile: radar-guided, long range; chaff and jamming defeat it.
return {
	id = "ord_radar_aam",
	type = "HOMING",
	range = 420,
	reload = 2,
	projectileSpeed = 520,
	accuracy = 0.5,
	turnRate = 160,
	guidance = "RADAR",
	lockRange = 420,
	burnThrough = 0.35,
	terminalRange = 50,
	canTargetRadar = true,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 300, SUB = 0 },
	aoe = 5,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "JET", "AIR", "HELI" },
	turret = { yawRate = 360, pitchRate = 360, tolerance = 15, minPitch = -60, maxPitch = 60, arc = 120 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "aam" },
}

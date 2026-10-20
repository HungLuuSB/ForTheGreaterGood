--!strict
-- Wyvern missile: radar-guided, long range; jamming blocks it beyond burn-through, chaff decoys it.
return {
	id = "chs_radar_sam",
	type = "HOMING",
	range = 560,
	reload = 4,
	projectileSpeed = 360,
	accuracy = 1,
	turnRate = 90,
	guidance = "RADAR",
	lockRange = 560,
	burnThrough = 0.35,
	terminalRange = 50,
	canTargetRadar = true,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 400, SUB = 0 },
	aoe = 8,
	edgeEffectiveness = 0.4,
	targets = { "AIR" },
	priority = { "JET", "AIR", "HELI" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_air_large", sound = "sam_radar" },
}

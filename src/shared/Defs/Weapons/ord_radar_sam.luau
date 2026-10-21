--!strict
-- Aegis missile: radar-guided, long range; jamming blocks it beyond burn-through, chaff decoys it.
return {
	id = "ord_radar_sam",
	type = "HOMING",
	range = 600,
	reload = 4,
	projectileSpeed = 360,
	accuracy = 1,
	turnRate = 90,
	launch = "vertical", -- IRIS-T SLM style: straight up, then over (S-42)
	guidance = "RADAR",
	lockRange = 600,
	burnThrough = 0.35,
	terminalRange = 50,
	canTargetRadar = true,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 380, SUB = 0 },
	aoe = 20, -- heavy warhead (client request 20, the user asked)
	edgeEffectiveness = 0.4,
	targets = { "AIR" },
	priority = { "JET", "AIR", "HELI" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_air_large", sound = "sam_radar" },
}

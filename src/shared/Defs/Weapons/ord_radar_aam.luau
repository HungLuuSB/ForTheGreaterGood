--!strict
-- Archon missile: radar-guided, long range; chaff and jamming defeat it.
return {
	id = "ord_radar_aam",
	type = "HOMING",
	range = 396, -- faction pass, tuned (S-62)
	reload = 4.4, -- 2.4 + the 2 s rearm per round it no longer flies home for (S-194, G17: no ammo)
	projectileSpeed = 520,
	accuracy = 0.5,
	turnRate = 160,
	guidance = "RADAR",
	lockRange = 396, -- faction pass, tuned (S-62)
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

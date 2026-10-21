--!strict
-- Aegis missile: radar-guided, long range; jamming blocks it beyond burn-through, chaff decoys it.
return {
	id = "ord_radar_sam",
	type = "HOMING",
	range = 1800, -- ×3 (S-45, the user asked)
	reload = 4,
	projectileSpeed = 360,
	accuracy = 1,
	turnRate = 90,
	launch = "vertical", -- IRIS-T SLM style: straight up, then over (S-42)
	climbHeight = 100, -- studs above the ground it climbs straight first (S-44, the user asked)
	stockpile = { capacity = 15, buildTime = 6, cost = { supply = 40, power = 900 } }, -- missiles in stock (S-47; 15 and 6 s since S-52, the user asked); Gorgon / Seraph carry 3
	guidance = "RADAR",
	intercepts = { chance = 0.2 }, -- shoots at enemy strategic missiles first (S-48); 0.2 (S-50, the user)
	lockRange = 1800,
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

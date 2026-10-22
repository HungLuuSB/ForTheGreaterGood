--!strict
-- Aegis missile: radar-guided, long range; jamming blocks it beyond burn-through, chaff decoys it.
return {
	id = "ord_radar_sam",
	type = "HOMING",
	range = 1100, -- faction pass (S-62)
	reload = 3.7, -- faction pass, tuned (S-62); -10% (S-112: Aegis vs Wyvern)
	projectileSpeed = 360,
	accuracy = 1,
	turnRate = 90,
	launch = "vertical", -- IRIS-T SLM style: straight up, then over (S-42)
	climbHeight = 100, -- studs above the ground it climbs straight first (S-44, the user asked)
	stockpile = { capacity = 15, buildTime = 6, cost = { supply = 40, power = 900 } }, -- missiles in stock (S-47; 15 and 6 s since S-52, the user asked); Seraph carries 3
	guidance = "RADAR",
	lockRange = 1100, -- faction pass (S-62)
	burnThrough = 0.35,
	terminalRange = 50,
	canTargetRadar = true,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 1150, SUB = 0 }, -- T2: one-shots any T1 aircraft (the Plague has 1,000; client request 46)
	shieldMass = 2.5, -- its weight against domes stays where it was before the T2 damage raise (S-111)
	aoe = 20, -- heavy warhead (client request 20, the user asked)
	edgeEffectiveness = 0.4,
	targets = { "AIR" },
	priority = { "JET", "AIR", "HELI" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 10, minPitch = -10, maxPitch = 85, arc = 360 },
	fx = { muzzle = "missile_launch_large", trail = "smoke_thick", impact = "explosion_air_large", sound = "sam_radar" },
}

--!strict
-- Falcon air-to-air missile: IR homing, few and accurate.
return {
	id = "ord_aam",
	type = "HOMING",
	range = 393, -- faction pass, tuned (S-62); +5% (S-112: the Falcon's standoff)
	reload = 3.4, -- 1.4 + the 2 s rearm per round it no longer flies home for (S-194, G17: no ammo)
	projectileSpeed = 480,
	accuracy = 0.5,
	turnRate = 200,
	guidance = "IR",
	lockRange = 393, -- (S-112)
	terminalRange = 40,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 280, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "JET", "HELI", "AIR" },
	turret = { yawRate = 360, pitchRate = 360, tolerance = 15, minPitch = -60, maxPitch = 60, arc = 120 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "aam" },
}

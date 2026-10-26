--!strict
-- Harpy air-to-air missile: IR homing, cheap and plentiful.
return {
	id = "chs_aam",
	type = "HOMING",
	range = 234, -- faction pass, tuned (S-62)
	reload = 2.3, -- 0.8 + the 1.5 s rearm per round it no longer flies home for (S-194, G17: no ammo)
	projectileSpeed = 440,
	accuracy = 1.4, -- faction pass (S-62)
	turnRate = 160,
	guidance = "IR",
	lockRange = 234, -- faction pass, tuned (S-62)
	terminalRange = 40,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 190, SUB = 0 },
	aoe = 4,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "JET", "HELI", "AIR" },
	turret = { yawRate = 360, pitchRate = 360, tolerance = 15, minPitch = -60, maxPitch = 60, arc = 120 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "aam" },
}

--!strict
-- Manticore missile: heavy IR missile, many carried.
return {
	id = "chs_heavy_aam",
	type = "HOMING",
	range = 350, -- faction pass, tuned (S-62)
	reload = 2.3, -- 0.9 + the 1.4 s rearm per round it no longer flies home for (S-194, G17: no ammo)
	projectileSpeed = 460,
	accuracy = 1,
	turnRate = 180,
	guidance = "IR",
	lockRange = 350, -- faction pass, tuned (S-62)
	terminalRange = 40,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 300, SUB = 0 },
	aoe = 6,
	edgeEffectiveness = 0.5,
	targets = { "AIR" },
	priority = { "JET", "HELI", "AIR" },
	turret = { yawRate = 360, pitchRate = 360, tolerance = 15, minPitch = -60, maxPitch = 60, arc = 120 },
	fx = { muzzle = "missile_launch", trail = "smoke_thin", impact = "explosion_air", sound = "aam" },
}

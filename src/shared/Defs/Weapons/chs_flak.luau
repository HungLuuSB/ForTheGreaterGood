--!strict
-- Point-defense flak against aircraft (hitscan bursts).
return {
	id = "chs_flak",
	type = "HITSCAN",
	range = 260,
	reload = 0.5,
	accuracy = 1.5,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 0, SHIP = 0, AIR = 77, SUB = 0 },
	aoe = 0,
	targets = { "AIR" },
	priority = { "HELI", "JET", "AIR" },
	turret = { yawRate = 180, pitchRate = 120, tolerance = 5, minPitch = 0, maxPitch = 85, arc = 360 },
	fx = { muzzle = "flash_small", impact = "flak_burst", sound = "flak" },
}

--!strict
-- Minotaur's demolition charge (S-64): placed against a structure at 30
-- studs, one 3,000 blast every 20 s; structures only.
return {
	id = "chs_demolition",
	type = "HITSCAN",
	range = 30,
	reload = 20,
	salvo = { count = 1, delay = 0 },
	accuracy = 0,
	damage = { LIGHT = 0, ARMORED = 0, STRUCTURE = 3000, SHIP = 0, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "STRUCTURE" },
	priority = { "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 90, tolerance = 30, minPitch = -30, maxPitch = 30, arc = 120 },
	fx = { muzzle = "demolition", impact = "explosion_large", sound = "demolition" },
}

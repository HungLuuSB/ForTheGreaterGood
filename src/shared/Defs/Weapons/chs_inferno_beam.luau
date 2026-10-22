--!strict
-- Inferno's beam (S-96, client request 43): Radiance's Chaos counterpart,
-- shorter and lighter, on a quicker and cheaper cycle.
return {
	id = "chs_inferno_beam",
	type = "BEAM",
	range = 560,
	reload = 7,
	accuracy = 0,
	damage = { LIGHT = 2000, ARMORED = 2000, STRUCTURE = 1600, SHIP = 2000, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 500 },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 1, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy" },
}

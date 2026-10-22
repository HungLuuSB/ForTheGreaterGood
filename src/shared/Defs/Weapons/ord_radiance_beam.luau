--!strict
-- Radiance's beam (S-96, client request 43; BAR's Pulsar): precise, long,
-- one very heavy hit on a long reload, each shot paid in power from the
-- team's stores. Visible targets only: weak against radar contacts.
return {
	id = "ord_radiance_beam",
	type = "BEAM",
	range = 650,
	reload = 9,
	accuracy = 0,
	damage = { LIGHT = 2600, ARMORED = 2600, STRUCTURE = 2000, SHIP = 2600, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 700 },
	turret = { yawRate = 45, pitchRate = 30, tolerance = 1, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy" },
}

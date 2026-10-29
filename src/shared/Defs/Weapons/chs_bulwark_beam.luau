--!strict
-- Bulwark's beam (S-157, the user: Chaos's counterpart to Radiance, in
-- Inferno's place): Radiance's style with Inferno's numbers (S-113).
return {
	id = "chs_bulwark_beam",
	type = "BEAM",
	range = 384, -- -20% (S-203, the user's H7; was 480)
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 7,
	accuracy = 0,
	damage = { LIGHT = 1700, ARMORED = 1700, STRUCTURE = 1350, SHIP = 1700, AIR = 0, SUB = 0 }, -- over the whole beam
	beamDuration = 1.5,
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 500 },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 1, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy" },
}

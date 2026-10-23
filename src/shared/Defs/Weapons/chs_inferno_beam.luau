--!strict
-- Inferno's beam (S-96, client request 43): Radiance's Chaos counterpart,
-- shorter and lighter, on a quicker and cheaper cycle. S-113 (client
-- request 47): a smaller range and a weaker beam than Radiance's, lingering
-- 1.5 s; visible targets only.
return {
	id = "chs_inferno_beam",
	type = "BEAM",
	range = 480, -- (S-113: was 560)
	reload = 7,
	accuracy = 0,
	damage = { LIGHT = 1700, ARMORED = 1700, STRUCTURE = 1350, SHIP = 1700, AIR = 0, SUB = 0 }, -- over the whole beam (S-113)
	beamDuration = 1.5,
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 500 },
	turret = { yawRate = 60, pitchRate = 40, tolerance = 1, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy" },
}

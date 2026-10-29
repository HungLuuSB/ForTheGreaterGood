--!strict
-- Titan's tachyon beam (S-209, H40): Radiance's beam on a walker, against
-- heavies; charged while it reloads (S-205).
return {
	id = "ord_titan_beam",
	type = "BEAM",
	range = 420,
	closeDamage = 1.5,
	reload = 7,
	accuracy = 0,
	damage = { LIGHT = 2600, ARMORED = 2600, STRUCTURE = 2000, SHIP = 2600, AIR = 0, SUB = 0 }, -- over the whole beam
	beamDuration = 2,
	pierce = true,
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 500 },
	turret = { yawRate = 45, pitchRate = 30, tolerance = 1, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy", color = { r = 60, g = 150, b = 255 } },
}

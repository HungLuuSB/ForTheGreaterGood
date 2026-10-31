--!strict
-- Luminary's tachyon beam (S-230; BAR's armmanni): pierces a line.
return {
	id = "ord_luminary_beam",
	type = "BEAM",
	range = 300,
	closeDamage = 1.5,
	reload = 4,
	accuracy = 0,
	damage = { LIGHT = 1840, ARMORED = 1840, STRUCTURE = 1500, SHIP = 1564, AIR = 0, SUB = 0 }, -- over the whole beam
	beamDuration = 1.5,
	pierce = true,
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	shotCost = { power = 300 },
	turret = { yawRate = 50, pitchRate = 35, tolerance = 1, minPitch = -15, maxPitch = 30, arc = 360 },
	fx = { muzzle = "beam_charge", impact = "beam_impact", sound = "beam_heavy", color = { r = 60, g = 150, b = 255 } },
}

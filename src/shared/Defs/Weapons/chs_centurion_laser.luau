--!strict
-- Centurion's red laser: a hit-ray through everything on its line (S-181, the playtest's new units).
return {
	id = "chs_centurion_laser",
	type = "BEAM",
	range = 280,
	closeDamage = 1.5,
	reload = 3,
	shotCost = { power = 150 }, -- lasers cost energy per shot (S-187, the user)
	accuracy = 0,
	damage = { LIGHT = 600, ARMORED = 450, STRUCTURE = 300, SHIP = 450, AIR = 0, SUB = 0 }, -- over the whole beam
	beamDuration = 1.2,
	pierce = true,
	fullLength = true, -- on through the whole line to full range
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND", "STRUCTURE" },
	turret = { yawRate = 90, pitchRate = 60, tolerance = 1, minPitch = -20, maxPitch = 30, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 30, b = 30 }, impact = "beam_impact", sound = "beam_heavy" },
}

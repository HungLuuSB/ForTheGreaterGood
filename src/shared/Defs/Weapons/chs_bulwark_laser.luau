--!strict
-- Split from chs_geryon_laser (S-179, the playtest's balance notes) so its users can be balanced apart.
-- Geryon's green laser (S-157): Overwatch's Chaos counterpart, harder
-- hitting and shorter. Three barrels on a drum; the top one fires, then the
-- drum turns the next one up (client). Bulwark carries it too.
return {
	id = "chs_bulwark_laser",
	type = "HITSCAN",
	range = 215,
	closeDamage = 1.5, -- lasers hit harder up close (S-178, the user)
	reload = 0.5,
	accuracy = 0.3,
	damage = { LIGHT = 84, ARMORED = 78, STRUCTURE = 52, SHIP = 64, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "ARMORED", "GROUND", "STRUCTURE" },
	turret = { yawRate = 110, pitchRate = 80, tolerance = 3, minPitch = -60, maxPitch = 60, arc = 360 },
	fx = { tracer = "laser", color = { r = 60, g = 255, b = 90 }, impact = "laser_hit", sound = "laser" },
}

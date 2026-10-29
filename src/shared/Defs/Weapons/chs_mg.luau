--!strict
-- Scout laser (S-203, the user's H11: "Scout from both factions now use a hot-yellow
-- laser hit-scan weapon"; the machine gun until then, the id kept): fast, light, short range.
-- S-179, the playtest's balance notes: a T1 unit's range halved, damage × 0.8 (four Lancer shells no longer kill an extractor)
return {
	id = "chs_mg",
	type = "HITSCAN",
	range = 35, -- halved (S-152, the user: "Scout attack range's is too big"); 140 since the faction pass (S-62)
	reload = 0.35, -- faction pass (S-62)
	closeDamage = 1.5, -- lasers hit harder up close (S-178)
	shotCost = { power = 1 }, -- lasers cost energy per shot (S-187)
	accuracy = 1.65, -- faction pass, tuned (S-62)
	damage = { LIGHT = 27, ARMORED = 11, STRUCTURE = 7, SHIP = 6, AIR = 0, SUB = 0 },
	aoe = 0,
	targets = { "GROUND", "NAVAL", "STRUCTURE" },
	priority = { "LIGHT", "GROUND" },
	turret = { yawRate = 240, pitchRate = 120, tolerance = 6, minPitch = -10, maxPitch = 30, arc = 360 },
	fx = { tracer = "laser", color = { r = 255, g = 214, b = 40 }, impact = "laser_hit", sound = "laser" }, -- hot yellow
}

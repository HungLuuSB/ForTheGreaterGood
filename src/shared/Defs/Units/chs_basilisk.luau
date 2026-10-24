--!strict
local Templates = require("../Templates")

-- Chaos point defence (S-149, the user): a T2 launcher that shoots
-- down enemy missiles and rockets flying over its cover, never units. Its
-- own short radar spots them. Placeholder numbers.
return Templates.extend(Templates.Structure, {
	id = "chs_basilisk",
	name = "Basilisk",
	description = "Point defence. Shoots down enemy missiles and rockets over its cover with a large stock of interceptors; never fires at units.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 340, power = 4600, buildTime = 8500 },
	health = 2600,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 160, radar = 480, radarError = 30 },
	weapons = { { def = "chs_point_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "antinuke",
	model = "chs_basilisk",
})

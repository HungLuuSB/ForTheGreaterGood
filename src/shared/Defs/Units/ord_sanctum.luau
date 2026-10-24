--!strict
local Templates = require("../Templates")

-- Order point defence (S-149, the user): a T2 launcher that shoots
-- down enemy missiles and rockets flying over its cover, never units. Its
-- own short radar spots them. Placeholder numbers.
return Templates.extend(Templates.Structure, {
	id = "ord_sanctum",
	name = "Sanctum",
	description = "Point defence. Shoots down enemy missiles and rockets over its cover with interceptors; never fires at units.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 380, power = 5200, buildTime = 9000 },
	health = 2200,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 160, radar = 500, radarError = 15 },
	weapons = { { def = "ord_point_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "antinuke",
	model = "ord_sanctum",
})

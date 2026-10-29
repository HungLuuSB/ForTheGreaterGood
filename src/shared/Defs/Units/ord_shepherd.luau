--!strict
local Templates = require("../Templates")

-- Order mobile point defence (S-149, the user): a T2 vehicle that
-- escorts an army and shoots down enemy missiles and rockets flying near
-- it, on the move too. Fewer interceptors and less reach than the
-- structure. Its own short radar spots them. Placeholder numbers.
return Templates.extend(Templates.Unit, {
	id = "ord_shepherd",
	name = "Shepherd",
	description = "Mobile point defence. Shoots down enemy missiles and rockets near it; never fires at units.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 260, power = 3600, buildTime = 6500 },
	health = 900,
	movement = { maxSpeed = 20.4, accel = 12, brake = 24, turnRate = 100 },
	sensors = { sight = 150, radar = 380, radarError = 15 },
	weapons = { { def = "ord_mobile_point_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "antinuke",
	model = "ord_shepherd",
})

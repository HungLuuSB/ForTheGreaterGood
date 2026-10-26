--!strict
local Templates = require("../Templates")

-- Chaos mobile point defence (S-149, the user): a T2 vehicle that
-- escorts an army and shoots down enemy missiles and rockets flying near
-- it, on the move too. Fewer interceptors and less reach than the
-- structure. Its own short radar spots them. Placeholder numbers.
return Templates.extend(Templates.Unit, {
	id = "chs_griffin",
	name = "Griffin",
	description = "Mobile point defence. Shoots down enemy missiles and rockets near it with a deep stock of interceptors; never fires at units.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 230, power = 3200, buildTime = 6000 },
	health = 820,
	movement = { maxSpeed = 20.4, accel = 12, brake = 24, turnRate = 100 },
	sensors = { sight = 150, radar = 360, radarError = 30 },
	weapons = { { def = "chs_mobile_point_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	icon = "antinuke",
	model = "chs_griffin",
})

--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile jammer", T2): long-range jammer.
return Templates.extend(Templates.Unit, {
	id = "chs_shroud",
	name = "Shroud",
	description = "Mobile jammer. Hides friendly units from enemy radar over a wide radius.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "JAMMER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 130, power = 2000, buildTime = 4000 },
	health = 480,
	movement = { maxSpeed = 34, accel = 13, brake = 26, turnRate = 120 },
	sensors = { sight = 110, jam = 450 },
	pieces = { "base", "array" },
	model = "chs_shroud",
	icon = "jammer",
})

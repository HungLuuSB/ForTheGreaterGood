--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile jammer", T2): short-range jammer.
return Templates.extend(Templates.Unit, {
	id = "ord_veil",
	name = "Veil",
	description = "Mobile jammer. Hides nearby friendly units from enemy radar (short range).",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "JAMMER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 140, power = 2200, buildTime = 4200 },
	health = 420,
	movement = { maxSpeed = 36, accel = 14, brake = 28, turnRate = 130 },
	sensors = { sight = 120, jam = 300 },
	pieces = { "base", "array" },
	model = "ord_veil",
	icon = "jammer",
})

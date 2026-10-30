--!strict
local Templates = require("../Templates")

-- Placeholder (S-219, the user: transports); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_courier",
	name = "Courier",
	description = "Air transport. Carries one light unit or a Commander.",
	faction = "order",
	tier = 1,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 2,
	cost = { supply = 110, power = 1800, buildTime = 3600 },
	health = 650,
	movement = { maxSpeed = 54, accel = 26, brake = 34, turnRate = 160 },
	sensors = { sight = 140 },
	transport = { slots = 2, maxUnits = 1, maxTier = 1, maxFootprint = 2 }, -- one light unit: T1 or a Commander
	pieces = { "base" },
	icon = "transport",
	model = "ord_courier",
})

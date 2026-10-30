--!strict
local Templates = require("../Templates")

-- Placeholder (S-219, the user: transports); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_ark",
	name = "Ark",
	description = "Heavy air transport. Carries one unit, heavy ones included.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 3,
	cost = { supply = 340, power = 6500, buildTime = 9000 },
	health = 2000,
	movement = { maxSpeed = 44, accel = 26, brake = 34, turnRate = 160 },
	sensors = { sight = 140 },
	transport = { slots = 4, maxUnits = 1, maxTier = 2, maxFootprint = 3 }, -- one unit, up to T2 and footprint 3 (S-220, the user: one unit for T1 and T2)
	pieces = { "base" },
	icon = "transport",
	model = "ord_ark",
})

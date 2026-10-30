--!strict
local Templates = require("../Templates")

-- Placeholder (S-219, the user: transports); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_ark",
	name = "Ark",
	description = "Heavy air transport. Carries up to four units, heavy ones included.",
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
	transport = { slots = 4, maxUnits = 4, maxTier = 2, maxFootprint = 3 }, -- footprint 1 takes 1 slot, 2 takes 2, 3 takes 4
	pieces = { "base" },
	icon = "transport",
	model = "ord_ark",
})

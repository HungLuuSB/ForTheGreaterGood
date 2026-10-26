--!strict
-- Liche: Order's strategic bomber (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_liche",
	name = "Liche",
	description = "Strategic bomber. One devastating bomb per sortie, a long rearm; fast but turns slowly.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 2,
	cost = { supply = 800, power = 14000, buildTime = 26000 },
	health = 2400,
	movement = { maxSpeed = 156, minSpeed = 96, accel = 90, brake = 60, turnRate = 40 },
	sensors = { sight = 220 },
	weapons = { { def = "ord_liche_bomb", muzzle = "muzzle" } },
	pieces = { "base", "bay", "muzzle" },
	rearmTime = 20,
	countermeasures = { chaff = { charges = 3, chance = 0.5, refillSupply = 4 } },
	icon = "bomber_heavy",
	model = "ord_liche",
})

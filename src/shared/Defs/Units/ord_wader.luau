--!strict
-- Wader: Order's T1 amphibious tank (S-230, the BAR roster program's batch 1;
-- BAR's armpincer). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_wader",
	name = "Wader",
	description = "Amphibious tank. A light gun; drives along the seafloor and climbs out on any shore.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "AMPHIB",
	footprint = 1, -- (C's blockout)
	cost = { supply = 140, power = 1400, buildTime = 3900 },
	health = 780,
	movement = { maxSpeed = 17, accel = 12, brake = 24, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "ord_wader_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "ord_wader",
})

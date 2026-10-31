--!strict
-- Courser: Order's fast T1 raider tank (S-230, the BAR roster program's batch 1;
-- BAR's armflash). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_courser",
	name = "Courser",
	description = "Fast assault tank. A rapid-fire light gun on a quick hull: a raider.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1, -- (C's blockout)
	cost = { supply = 76, power = 760, buildTime = 2100 },
	health = 410,
	movement = { maxSpeed = 26, accel = 18, brake = 36, turnRate = 130 },
	sensors = { sight = 170 },
	weapons = { { def = "ord_courser_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "scout",
	model = "ord_courser",
})

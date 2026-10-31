--!strict
-- Luminary: Order's T2 mobile tachyon beam (S-230, the BAR roster program's batch 1;
-- BAR's armmanni). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_luminary",
	name = "Luminary",
	description = "Tachyon tank. A long beam that pierces a line of units, at a power cost a shot.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HEAVY_TRACKED",
	footprint = 2, -- (C's blockout)
	cost = { supply = 700, power = 9000, buildTime = 18000 },
	health = 2200,
	movement = { maxSpeed = 11, accel = 8, brake = 15, turnRate = 80 },
	sensors = { sight = 250 },
	weapons = { { def = "ord_luminary_beam", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "beam",
	model = "ord_luminary",
})

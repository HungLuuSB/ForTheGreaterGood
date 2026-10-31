--!strict
-- Fulgur: Order's T2 lightning raider (S-230, the BAR roster program's batch 1;
-- BAR's armlatnk). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_fulgur",
	name = "Fulgur",
	description = "Lightning tank. A fast raider with a close lightning gun and an anti-air missile.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "TRACKED",
	footprint = 2, -- (C's blockout)
	cost = { supply = 230, power = 2800, buildTime = 5800 },
	health = 840,
	movement = { maxSpeed = 24, accel = 17, brake = 34, turnRate = 80 },
	sensors = { sight = 195 },
	weapons = { { def = "ord_fulgur_lightning", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" }, { def = "ord_fulgur_aa", turretPiece = "turret", muzzle = "aa_muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle", "aa_muzzle" },
	icon = "tank_light",
	model = "ord_fulgur",
})

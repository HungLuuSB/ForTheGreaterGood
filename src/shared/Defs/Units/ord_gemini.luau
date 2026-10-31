--!strict
-- Gemini: Order's T1 twin-rocket tank (S-230, the BAR roster program's batch 1;
-- BAR's armjanus). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_gemini",
	name = "Gemini",
	description = "Rocket tank. Twin guided rockets that out-reach the gun tanks.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1, -- (C's blockout)
	cost = { supply = 170, power = 1700, buildTime = 4800 },
	health = 580,
	movement = { maxSpeed = 15, accel = 10, brake = 21, turnRate = 100 },
	sensors = { sight = 170 },
	weapons = { { def = "ord_gemini_rockets", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "tank_light",
	model = "ord_gemini",
})

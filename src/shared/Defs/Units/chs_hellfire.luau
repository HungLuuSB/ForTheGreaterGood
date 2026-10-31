--!strict
-- Hellfire: Chaos's T2 heavy missile tank (S-230, the BAR roster program's batch 1;
-- BAR's corban). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_hellfire",
	name = "Hellfire",
	description = "Heavy missile tank. Long-range guided missiles that hunt armor.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HEAVY_TRACKED",
	footprint = 2, -- (C's blockout)
	cost = { supply = 600, power = 8000, buildTime = 15000 },
	health = 1950,
	movement = { maxSpeed = 14, accel = 10, brake = 20, turnRate = 80 },
	sensors = { sight = 250 },
	weapons = { { def = "chs_hellfire_missiles", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "tank_heavy",
	model = "chs_hellfire",
})

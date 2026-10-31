--!strict
-- Grendel: Chaos's T2 very heavy amphibious tank (S-230, the BAR roster program's batch 1;
-- BAR's corparrow). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_grendel",
	name = "Grendel",
	description = "Heavy amphibious tank. A huge armored hull and a heavy cannon; walks the seafloor.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "AMPHIB",
	footprint = 2, -- (C's blockout)
	cost = { supply = 650, power = 8000, buildTime = 16000 },
	health = 5000,
	movement = { maxSpeed = 13, accel = 9, brake = 18, turnRate = 80 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_grendel_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_heavy",
	model = "chs_grendel",
})

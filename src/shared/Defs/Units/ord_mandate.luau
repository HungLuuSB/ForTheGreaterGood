--!strict
-- Mandate: Order's T2 mobile artillery (S-230, the BAR roster program's batch 1;
-- BAR's armmart). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_mandate",
	name = "Mandate",
	description = "Mobile artillery. Lobs plasma shells far beyond the front line.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARTILLERY" },
	armorClass = "LIGHT",
	moveClass = "TRACKED",
	footprint = 2, -- (C's blockout)
	cost = { supply = 220, power = 2600, buildTime = 5500 },
	health = 850,
	movement = { maxSpeed = 16, accel = 11, brake = 22, turnRate = 80 },
	sensors = { sight = 170 },
	weapons = { { def = "ord_mandate_shell", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "artillery",
	model = "ord_mandate",
})

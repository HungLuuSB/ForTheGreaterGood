--!strict
-- Hurler: Chaos's T2 mobile artillery (S-230, the BAR roster program's batch 1;
-- BAR's cormart). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_hurler",
	name = "Hurler",
	description = "Mobile artillery. Lobs plasma shells far beyond the front line.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARTILLERY" },
	armorClass = "LIGHT",
	moveClass = "TRACKED",
	footprint = 2, -- (C's blockout)
	cost = { supply = 280, power = 3000, buildTime = 7000 },
	health = 930,
	movement = { maxSpeed = 15, accel = 10, brake = 21, turnRate = 80 },
	sensors = { sight = 170 },
	weapons = { { def = "chs_hurler_shell", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "artillery",
	model = "chs_hurler",
})

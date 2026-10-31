--!strict
-- Typhon: Chaos's T3 heavy laser hovertank from the gantry (S-230, the BAR roster program's batch 1;
-- BAR's corsok). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_typhon",
	name = "Typhon",
	description = "Heavy laser hovertank. Twin heavy lasers on a hull that crosses land and water.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HOVER",
	footprint = 3, -- (C's blockout)
	cost = { supply = 660, power = 9000, buildTime = 18000 },
	health = 3300,
	movement = { maxSpeed = 12, accel = 8, brake = 17, turnRate = 80 },
	sensors = { sight = 250 },
	weapons = { { def = "chs_typhon_laser", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_heavy",
	model = "chs_typhon",
})

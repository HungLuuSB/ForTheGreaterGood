--!strict
-- Glaive: Chaos's heavy assault hovertank (S-230, the BAR roster program's batch 1;
-- BAR's corhal). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_glaive",
	name = "Glaive",
	description = "Assault hovertank. A heavy laser on a thick hull: the Skim Yard's line breaker.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HOVER",
	footprint = 2, -- (C's blockout)
	cost = { supply = 440, power = 5000, buildTime = 11000 },
	health = 2460,
	movement = { maxSpeed = 12, accel = 8, brake = 17, turnRate = 100 },
	sensors = { sight = 170 },
	weapons = { { def = "chs_glaive_laser", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_heavy",
	model = "chs_glaive",
})

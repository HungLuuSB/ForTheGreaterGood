--!strict
-- Sling: Chaos's T1 hover rocket artillery (S-230, the BAR roster program's batch 1;
-- BAR's cormh). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_sling",
	name = "Sling",
	description = "Hover rocket artillery. A barrage of unguided rockets from the water's edge.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARTILLERY" },
	armorClass = "LIGHT",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 140, power = 1400, buildTime = 3900 },
	health = 310,
	movement = { maxSpeed = 17, accel = 12, brake = 24, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_sling_rockets", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "artillery",
	model = "chs_sling",
})

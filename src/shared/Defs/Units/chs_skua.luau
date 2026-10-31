--!strict
-- Skua: Chaos's T1 hover anti-air (S-230, the BAR roster program's batch 1;
-- BAR's corah). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_skua",
	name = "Skua",
	description = "Hover anti-air. Missiles against aircraft, over land and water.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "ANTIAIR" },
	armorClass = "LIGHT",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 170, power = 1900, buildTime = 4700 },
	health = 600,
	movement = { maxSpeed = 23, accel = 16, brake = 32, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_skua_aa", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "aa",
	model = "chs_skua",
})

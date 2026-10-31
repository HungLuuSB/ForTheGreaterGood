--!strict
-- Gnat: Chaos's T1 fast hover raider (S-230, the BAR roster program's batch 1;
-- BAR's corsh). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_gnat",
	name = "Gnat",
	description = "Fast hover raider. A machine gun on the quickest hull on land or water.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 52, power = 520, buildTime = 1450 },
	health = 145,
	movement = { maxSpeed = 29, accel = 20, brake = 41, turnRate = 130 },
	sensors = { sight = 210 },
	weapons = { { def = "chs_gnat_mg", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "scout",
	model = "chs_gnat",
})

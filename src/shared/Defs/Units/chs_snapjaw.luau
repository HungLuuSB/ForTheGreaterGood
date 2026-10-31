--!strict
-- Snapjaw: Chaos's T1 hover tank (S-230, the BAR roster program's batch 1;
-- BAR's corsnap). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_snapjaw",
	name = "Snapjaw",
	description = "Hover tank. A plasma gun on a hull that crosses land and water.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HOVER",
	footprint = 1, -- (C's blockout)
	cost = { supply = 210, power = 2100, buildTime = 5800 },
	health = 960,
	movement = { maxSpeed = 18, accel = 13, brake = 25, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_snapjaw_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "chs_snapjaw",
})

--!strict
-- Mudskipper: Chaos's T1 amphibious tank (S-230, the BAR roster program's batch 1;
-- BAR's corgarp). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_mudskipper",
	name = "Mudskipper",
	description = "Amphibious tank. A light gun; drives along the seafloor and climbs out on any shore.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "AMPHIB",
	footprint = 1, -- (C's blockout)
	cost = { supply = 150, power = 1500, buildTime = 4200 },
	health = 780,
	movement = { maxSpeed = 15, accel = 10, brake = 21, turnRate = 100 },
	sensors = { sight = 200 },
	weapons = { { def = "chs_mudskipper_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "chs_mudskipper",
})

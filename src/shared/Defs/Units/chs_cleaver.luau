--!strict
-- Cleaver: Chaos's T1 riot tank (S-230, the BAR roster program's batch 1;
-- BAR's corlevlr). First-draft numbers from the README's suggested
-- conversion, scaled to our tanks (docs/decisions/sim.md S-230).
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_cleaver",
	name = "Cleaver",
	description = "Riot tank. A slow riot cannon whose wide blast shreds light units.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "TRACKED",
	footprint = 1, -- (C's blockout)
	cost = { supply = 150, power = 1500, buildTime = 4200 },
	health = 780,
	movement = { maxSpeed = 10, accel = 7, brake = 14, turnRate = 100 },
	sensors = { sight = 170 },
	weapons = { { def = "chs_cleaver_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "chs_cleaver",
})

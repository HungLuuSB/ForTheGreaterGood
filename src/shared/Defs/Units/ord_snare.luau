--!strict
-- Snare: Order's all-terrain emp spider (S-233, the BAR roster program's batch 2;
-- BAR's armspid). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_snare",
	name = "Snare",
	description = "All-terrain EMP spider. Stuns units with its laser and reclaims; invisible to radar.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "SPIDER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "ARMORED", "STEALTH" },
	armorClass = "ARMORED",
	cost = { supply = 220, power = 2800, buildTime = 5500 },
	health = 950,
	movement = { maxSpeed = 30.8, accel = 43, brake = 55, turnRate = 360 },
	sensors = { sight = 230, radarSignature = 0 },
	buildPower = 120,
	buildRange = 48,
	assistOnly = true, -- repairs, assists and reclaims; builds nothing
	weapons = {
		{ def = "ord_snare_emp", turretPiece = "torso", muzzle = "muzzle" },
	},
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_light",
	model = "ord_snare",
})

--!strict
-- Widowmaker: Chaos's all-terrain assault mech (S-233, the BAR roster program's batch 2;
-- BAR's corkarg). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_widowmaker",
	name = "Widowmaker",
	description = "All-terrain assault mech. Climbs anything; a storm of missiles at ground and air.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "SPIDER",
	footprint = 3, -- (C's blockout)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 1500, power = 22000, buildTime = 50000 },
	health = 12000,
	movement = { maxSpeed = 12, accel = 17, brake = 22, turnRate = 180 },
	sensors = { sight = 200 },
	weapons = {
		{ def = "chs_widowmaker_missiles", turretPiece = "torso", muzzle = "muzzle" },
		{ def = "chs_widowmaker_sam", turretPiece = "torso", muzzle = "muzzle2" },
	},
	pieces = { "base", "torso", "muzzle", "muzzle2" },
	icon = "experimental",
	model = "chs_widowmaker",
})

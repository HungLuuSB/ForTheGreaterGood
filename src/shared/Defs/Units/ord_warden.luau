--!strict
local Templates = require("../Templates")

-- Order faction-only unit (docs/design/factions.md section 4; S-64): a
-- tracked heavy gun that unpacks into a fortified emplacement whenever it
-- stands still (Sim/Deploy). Packed it moves but can't fire; deployed it
-- fires, can't move, and takes damage / 1.5. Stats to balance.
return Templates.extend(Templates.TankT1, {
	id = "ord_warden",
	name = "Warden",
	description = "Deployable gun. Unpacks in 4 s into a fortified emplacement: long range, 1.5× armor, immobile. Can't fire while packed.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HEAVY_TRACKED",
	footprint = 2, -- size shows tech level (S-104)
	cost = { supply = 300, power = 3000, buildTime = 7500 },
	health = 2200,
	movement = { maxSpeed = 13.2, accel = 8, brake = 18, turnRate = 70 },
	sensors = { sight = 280 },
	weapons = { { def = "ord_warden_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	deploy = { time = 4, armor = 1.5 },
	pieces = { "base", "spades", "turret", "barrel", "muzzle" },
	icon = "tank_heavy",
	model = "ord_warden",
})

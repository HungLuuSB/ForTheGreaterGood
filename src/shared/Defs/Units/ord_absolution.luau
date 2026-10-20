--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Bomber", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_absolution",
	name = "Absolution",
	description = "Bomber. Drops heavy bombs on ground targets.",
	faction = "order",
	tier = 1,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 200, power = 3600, buildTime = 7000 },
	health = 900,
	movement = { maxSpeed = 200, minSpeed = 120, accel = 80, brake = 60, turnRate = 50 },
	sensors = { sight = 200 },
	weapons = { { def = "ord_bomb", turretPiece = "bay", muzzle = "muzzle" } },
	pieces = { "base", "pylon", "muzzle" },
	icon = "bomber",
	ammo = 4,
	ammoCost = { supply = 15, power = 120 },
	rearmTime = 2,
	countermeasures = { chaff = { charges = 2, chance = 0.5, refillSupply = 3 } },
	model = "ord_absolution",
})

--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Air superiority fighter", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_archon",
	name = "Archon",
	description = "Air superiority fighter. Stealthy (0.35), DIRCM, radar missiles.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET", "STEALTH" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 360, power = 7000, buildTime = 11000 },
	health = 800,
	movement = { maxSpeed = 300, minSpeed = 160, accel = 80, brake = 60, turnRate = 85 },
	sensors = { sight = 240, airSight = 480, radarSignature = 0.35 },
	weapons = { { def = "ord_radar_aam", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "pylon", "muzzle" },
	icon = "fighter",
	ammo = 6,
	ammoCost = { supply = 14, power = 200 },
	rearmTime = 2,
	countermeasures = { dircm = { chance = 0.75, cooldown = 2.5, powerDrain = 20 } },
	model = "ord_archon",
})

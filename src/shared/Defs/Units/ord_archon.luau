--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "Air superiority fighter", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_archon",
	name = "Archon",
	description = "Air superiority fighter. A stealthy fighter with radar-guided missiles and DIRCM.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET", "STEALTH" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 395, power = 8050, buildTime = 12400 },
	health = 900, -- faction pass (S-62)
	movement = { maxSpeed = 168, minSpeed = 96, accel = 80, brake = 60, turnRate = 128 },
	sensors = { sight = 240, airSight = 480, radarSignature = 0.6 }, -- 0.35 before (S-46, the user asked)
	weapons = { { def = "ord_radar_aam", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "pylon", "muzzle" },
	icon = "fighter",
	rearmTime = 2,
	countermeasures = { dircm = { chance = 0.68, cooldown = 2.5, powerDrain = 20 } },
	model = "ord_archon",
})

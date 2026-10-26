--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "ASW helicopter", T2); stats to balance in M8.
-- Dipping sonar; drops homing torpedoes into the water below it. As a
-- helicopter that can target SUB it also detects submerged submarines
-- within 40 studs (Sensors.CLOSE_SONAR).
return Templates.extend(Templates.Unit, {
	id = "ord_tidewatch",
	name = "Tidewatch",
	description = "ASW helicopter. Dipping sonar and air-dropped torpedoes against submarines.",
	faction = "order",
	tier = 2,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 220, power = 3600, buildTime = 7600 },
	health = 720,
	movement = { maxSpeed = 39, accel = 25, brake = 35, turnRate = 165 },
	sensors = { sight = 180, airSight = 240, sonar = 170 },
	weapons = { { def = "ord_asw_torpedo", turretPiece = "rack", muzzle = "muzzle" } },
	ammo = 4,
	ammoCost = { supply = 12, power = 120 },
	rearmTime = 2,
	pieces = { "base", "rack", "muzzle" },
	model = "ord_tidewatch",
	icon = "heli_asw",
})

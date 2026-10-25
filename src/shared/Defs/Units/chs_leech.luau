--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.3 "ASW helicopter", T2); stats to balance in M8.
-- Dipping sonar; drops homing torpedoes into the water below it. As a
-- helicopter that can target SUB it also detects submerged submarines
-- within 40 studs (Sensors.CLOSE_SONAR).
return Templates.extend(Templates.Unit, {
	id = "chs_leech",
	name = "Leech",
	description = "ASW helicopter. Dipping sonar and air-dropped torpedoes against submarines.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 1,
	cost = { supply = 200, power = 3300, buildTime = 7200 },
	health = 760,
	movement = { maxSpeed = 60, accel = 25, brake = 35, turnRate = 165 },
	sensors = { sight = 180, airSight = 240, sonar = 150 },
	weapons = { { def = "chs_asw_torpedo", turretPiece = "rack", muzzle = "muzzle" } },
	ammo = 4,
	ammoCost = { supply = 12, power = 120 },
	rearmTime = 2,
	pieces = { "base", "rack", "muzzle" },
	model = "chs_leech",
	icon = "heli_asw",
})

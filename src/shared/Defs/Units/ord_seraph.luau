--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile radar SAM", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_seraph",
	name = "Seraph",
	description = "Mobile radar SAM. Long-range anti-air with its own radar; can be jammed.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "ANTIAIR", "RADAR_EMITTER" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 280, power = 3600, buildTime = 7600 },
	health = 800,
	movement = { maxSpeed = 32, accel = 12, brake = 24, turnRate = 110 },
	sensors = { sight = 150, radar = 1560, radarError = 20 },
	weapons = { { def = "ord_radar_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "sam_radar",
	model = "ord_seraph",
})

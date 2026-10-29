--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile IR SAM", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_hornet",
	name = "Hornet",
	description = "Mobile IR SAM. Short-range heat-seeking missiles against aircraft; jamming can't stop them.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "ANTIAIR" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 120, power = 1600, buildTime = 3200 },
	health = 480, -- faction pass, tuned (S-62)
	movement = { maxSpeed = 22.8, accel = 16, brake = 30, turnRate = 130 },
	sensors = { sight = 160, airSight = 165 },
	weapons = { { def = "chs_ir_sam", turretPiece = "turret", pitchPiece = "launcher", muzzle = "muzzle", stockpile = 5 } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "sam_ir",
	model = "chs_hornet",
})

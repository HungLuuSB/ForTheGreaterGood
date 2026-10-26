--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Mobile IR SAM", T1); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "ord_halo",
	name = "Halo",
	description = "Mobile IR SAM. Short-range anti-air, ignores jamming.",
	faction = "order",
	tier = 1,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "ANTIAIR" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 120, power = 1600, buildTime = 3200 },
	health = 660, -- faction pass, tuned (S-62)
	movement = { maxSpeed = 22.8, accel = 16, brake = 30, turnRate = 130 },
	sensors = { sight = 160, airSight = 206 },
	weapons = { { def = "ord_ir_sam", turretPiece = "turret", pitchPiece = "launcher", muzzle = "muzzle", stockpile = 4 } },
	pieces = { "base", "launcher", "turret", "muzzle" },
	icon = "sam_ir",
	model = "ord_halo",
})

--!strict
-- Needle: an anti-air bot (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_needle",
	name = "Needle",
	description = "Anti-air bot. Heat-seeking missiles from the shoulder; nothing against the ground.",
	faction = "chaos",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "LIGHT", "ANTIAIR" },
	armorClass = "LIGHT",
	cost = { supply = 95, power = 1250, buildTime = 2700 },
	health = 460,
	movement = { maxSpeed = 40, accel = 36, brake = 46, turnRate = 420 },
	sensors = { sight = 150, airSight = 210 },
	weapons = { { def = "chs_ir_sam", turretPiece = "torso", pitchPiece = "launcher", muzzle = "muzzle", stockpile = 4 } },
	pieces = { "base", "torso", "launcher", "muzzle" },
	icon = "aa",
	model = "chs_needle",
})

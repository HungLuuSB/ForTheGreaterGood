--!strict
-- Mace: Order's skirmisher bot, long-range plasma (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_mace",
	name = "Mace",
	description = "Skirmisher bot. Fires slow plasma shots from range.",
	faction = "order",
	tier = 1,
	domain = "ground",
	moveClass = "WALKER", -- bots climb steep slopes and turn on the spot
	footprint = 1,
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	cost = { supply = 120, power = 1500, buildTime = 3200 },
	health = 650,
	movement = { maxSpeed = 24, accel = 36, brake = 46, turnRate = 420 },
	sensors = { sight = 150 },
	weapons = { { def = "ord_mace_plasma", turretPiece = "torso", muzzle = "muzzle" } },
	pieces = { "base", "torso", "muzzle" },
	icon = "tank_light",
	model = "ord_mace",
})

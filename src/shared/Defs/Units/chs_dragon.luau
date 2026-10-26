--!strict
-- Dragon: Chaos's flying fortress (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_dragon",
	name = "Dragon",
	description = "Flying fortress. Huge, tough and fast; pours fire straight down and fires two green lasers.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "HELI" },
	armorClass = "AIR",
	moveClass = "HELI",
	footprint = 3,
	cost = { supply = 900, power = 16000, buildTime = 30000 },
	health = 9000,
	movement = { maxSpeed = 70, accel = 24, brake = 30, turnRate = 90 },
	sensors = { sight = 220, airSight = 260 },
	weapons = {
		{ def = "chs_dragon_flame", turretPiece = "belly", muzzle = "flame" },
		{ def = "chs_dragon_laser", turretPiece = "laser_l", muzzle = "laser_l_muzzle" },
		{ def = "chs_dragon_laser", turretPiece = "laser_r", muzzle = "laser_r_muzzle" },
	},
	pieces = { "base", "belly", "flame", "laser_l", "laser_l_muzzle", "laser_r", "laser_r_muzzle" },
	countermeasures = { flares = { charges = 6, chance = 0.5, refillSupply = 3 } },
	icon = "heli",
	model = "chs_dragon",
})

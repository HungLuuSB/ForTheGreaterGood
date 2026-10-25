--!strict
-- Fatboy: Order's heavy plasma bot (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_fatboy",
	name = "Fatboy",
	description = "Heavy plasma bot. Slow; its huge cannon flattens bases from long range.",
	faction = "order",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 2,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 600, power = 7000, buildTime = 16000 },
	health = 4800,
	movement = { maxSpeed = 18, accel = 12, brake = 24, turnRate = 300 },
	sensors = { sight = 180 },
	weapons = { { def = "ord_fatboy_cannon", turretPiece = "cannon", muzzle = "muzzle" } },
	pieces = { "base", "cannon", "muzzle" },
	icon = "artillery",
	model = "ord_fatboy",
})

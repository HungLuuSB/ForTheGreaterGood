--!strict
-- Tzar: Chaos's heavy plasma tank, the Fatboy's counterpart (S-181, the playtest's new units).
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_tzar",
	name = "Tzar",
	description = "Heavy plasma tank. A little less range than the Fatboy; hits harder and reloads faster.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "HEAVY_TRACKED",
	footprint = 2,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 620, power = 7200, buildTime = 16000 },
	health = 4200,
	movement = { maxSpeed = 22, accel = 10, brake = 20, turnRate = 70 },
	sensors = { sight = 170 },
	weapons = { { def = "chs_tzar_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "artillery",
	model = "chs_tzar",
})

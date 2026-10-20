--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_ravager",
	name = "Ravager",
	description = "Light tank. Cheap and tough, hits hard up close.",
	faction = "chaos",

	cost = { supply = 130, power = 1200, buildTime = 4000 },
	health = 1300,

	movement = { maxSpeed = 30, accel = 12, brake = 24, turnRate = 100 },

	sensors = { sight = 100 },

	weapons = {
		{ def = "chs_light_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	model = "chs_ravager",
})

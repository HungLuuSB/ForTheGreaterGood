--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_ravager",
	name = "Ravager",
	description = "Light tank. Cheap and tough, hits hard up close.",
	faction = "chaos",

	cost = { supply = 130, power = 1300, buildTime = 3700 },
	health = 1000, -- faction pass (S-62)

	movement = { maxSpeed = 36, accel = 12, brake = 24, turnRate = 100 },

	sensors = { sight = 180 },

	weapons = {
		{ def = "chs_light_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	model = "chs_ravager",
})

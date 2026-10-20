--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_lancer",
	name = "Lancer",
	description = "Light tank. Precise long-range cannon, light armor.",
	faction = "order",

	cost = { supply = 150, power = 1500, buildTime = 4500 },
	health = 1100,

	movement = { maxSpeed = 34, accel = 14, brake = 28, turnRate = 120 },

	sensors = { sight = 200 },

	weapons = {
		{ def = "ord_light_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	model = "ord_lancer",
})

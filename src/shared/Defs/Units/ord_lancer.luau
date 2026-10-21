--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_lancer",
	name = "Lancer",
	description = "Light tank. Precise long-range cannon, light armor.",
	faction = "order",

	cost = { supply = 170, power = 1700, buildTime = 5100 },
	health = 1300, -- faction pass (S-62)

	movement = { maxSpeed = 28, accel = 14, brake = 28, turnRate = 120 },

	sensors = { sight = 200 },

	weapons = {
		{ def = "ord_light_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	model = "ord_lancer",
})

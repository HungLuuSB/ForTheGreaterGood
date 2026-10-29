--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_lancer",
	name = "Lancer",
	description = "Light tank. A precise long-range cannon.",
	faction = "order",

	cost = { supply = 170, power = 1700, buildTime = 5100 },
	health = 1050, -- tier rebalance (S-157, the user): was 1300; faction pass (S-62)

	movement = { maxSpeed = 16.8, accel = 14, brake = 28, turnRate = 120 },

	sensors = { sight = 200 },

	weapons = {
		{ def = "ord_lancer_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	model = "ord_lancer",
})

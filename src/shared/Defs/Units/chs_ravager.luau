--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "chs_ravager",
	name = "Ravager",
	description = "Light tank. A short cannon for close fights.",
	faction = "chaos",

	cost = { supply = 130, power = 1300, buildTime = 3700 },
	health = 800, -- tier rebalance (S-157, the user): was 1000; faction pass (S-62)

	movement = { maxSpeed = 21.6, accel = 12, brake = 24, turnRate = 100 },

	sensors = { sight = 180 },

	weapons = {
		{ def = "chs_ravager_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
	},

	model = "chs_ravager",
})

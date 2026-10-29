--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.2 "Main battle tank", T2); stats to balance in M8.
return Templates.extend(Templates.TankT1, {
	id = "chs_juggernaut",
	name = "Goliath", -- (S-203) was Juggernaut: the name went to the Chaos T3 bot (chs_korgoth, the user's H40)
	description = "Main battle tank. Heavy armor, heavy gun. Raises its arms to fire.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HEAVY_TRACKED",
	footprint = 2, -- size shows tech level (S-104)
	cost = { supply = 280, power = 2800, buildTime = 7000 },
	health = 3000, -- tier rebalance (S-157, the user): was 2500; faction pass (S-62)
	movement = { maxSpeed = 15, accel = 10, brake = 20, turnRate = 80 },
	sensors = { sight = 210 },
	weapons = { { def = "chs_juggernaut_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "armL", "armR", "muzzle" }, -- the arms raise to fire (guide 14.4, S-20)
	icon = "tank_heavy",
	model = "chs_juggernaut",
})

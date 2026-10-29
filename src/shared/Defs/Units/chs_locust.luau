--!strict
local Templates = require("../Templates")

-- Chaos faction-only unit (docs/design/factions.md section 4; S-75): a very
-- cheap, fast light tank with a short autocannon. Saturation and flanking;
-- dies to splash. Stats to balance.
return Templates.extend(Templates.TankT1, {
	id = "chs_locust",
	name = "Locust",
	description = "Swarm tank. A small fast tank with a short autocannon.",
	faction = "chaos",
	tier = 1,
	categories = { "GROUND", "ARMORED" },
	cost = { supply = 70, power = 800, buildTime = 2000 },
	health = 500, -- tier rebalance (S-157, the user): was 600
	movement = { maxSpeed = 27, accel = 20, brake = 34, turnRate = 140 },
	sensors = { sight = 170 },
	weapons = { { def = "chs_autocannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "chs_locust",
})

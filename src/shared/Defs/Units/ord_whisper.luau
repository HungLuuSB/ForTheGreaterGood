--!strict
-- Whisper: Order's cloaked T2 tank (S-228, the BAR roster program's batch 1;
-- BAR's armgremlin). A light gauss gun on a stealthy hull that cloaks while
-- it holds its fire: an ambusher and a deep scout. Switched on (it starts
-- on), it drains power and enemy sight can't see it; firing, or an enemy
-- within 60 studs, shows it. Stealthy: radar sees it only up close.
local Templates = require("../Templates")

return Templates.extend(Templates.TankT1, {
	id = "ord_whisper",
	name = "Whisper",
	description = "Cloaked tank. A light gauss gun; unseen while it holds its fire, at a power upkeep.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT", "STEALTH" },
	armorClass = "LIGHT",
	moveClass = "TRACKED",
	footprint = 2, -- (C's blockout, 8-stud hull)
	cost = { supply = 220, power = 2800, buildTime = 6500 },
	health = 1300,
	movement = { maxSpeed = 19, accel = 14, brake = 26, turnRate = 110 },
	sensors = { sight = 200 },
	cloak = { drain = 12, decloak = 60 },
	weapons = { { def = "ord_whisper_gauss", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "tank_light",
	model = "ord_whisper",
})

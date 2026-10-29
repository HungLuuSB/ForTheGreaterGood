--!strict
local Templates = require("../Templates")

-- Chaos faction-only unit (docs/design/factions.md section 4; S-64): a
-- super-heavy siege ram. Its gun does +50% to structures, and a demolition
-- charge (30 studs, one 3,000 blast every 20 s) breaks walls, turrets and
-- fortresses. Slow; weak to mobile units and air. Stats to balance.
return Templates.extend(Templates.TankT1, {
	id = "chs_minotaur",
	name = "Minotaur",
	description = "Siege ram. A gun that wrecks structures and a demolition charge that levels them up close.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	moveClass = "HEAVY_TRACKED",
	footprint = 2,
	cost = { supply = 340, power = 3400, buildTime = 8000 },
	health = 5000, -- tier rebalance (S-157, the user): was 4200
	movement = { maxSpeed = 12, accel = 7, brake = 16, turnRate = 60 },
	sensors = { sight = 200 },
	weapons = {
		{ def = "chs_ram_cannon", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
		{ def = "chs_demolition", turretPiece = "ram", muzzle = "ram" },
	},
	pieces = { "base", "ram", "turret", "barrel", "muzzle" },
	icon = "tank_heavy",
	model = "chs_minotaur",
})

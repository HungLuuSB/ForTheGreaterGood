--!strict
local Templates = require("../Templates")

-- Chaos faction-only unit (docs/design/factions.md section 4; S-75): a heavy
-- siege mortar that outranges static defenses but can only shell
-- structures (it can't track units). Useless against an army in the
-- field. Stats to balance.
return Templates.extend(Templates.TankT1, {
	id = "chs_cyclops",
	name = "Cyclops",
	description = "Siege mortar. Shells structures from beyond their reach; can't fire at units.",
	faction = "chaos",
	tier = 2,
	categories = { "GROUND", "ARMORED", "ARTILLERY" },
	moveClass = "HEAVY_TRACKED",
	footprint = 2,
	cost = { supply = 260, power = 2600, buildTime = 7000 },
	health = 1300, -- tier rebalance (S-157, the user): was 1100
	movement = { maxSpeed = 13.2, accel = 7, brake = 16, turnRate = 60 },
	sensors = { sight = 160 },
	weapons = { { def = "chs_siege_mortar", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "artillery",
	model = "chs_cyclops",
})

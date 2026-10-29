--!strict
-- Juggernaut: Chaos's T3 experimental assault bot (S-209, the user's
-- playtest 3 H40; BAR's corkorg; id chs_korgoth since the T2 tank
-- chs_juggernaut has the id, now named Goliath). The strongest Chaos land
-- unit: an immensely powerful single-target heat ray, two double-barrelled
-- shotgun cannons, long-range vertical-launch missiles. Short-ranged for its
-- size: focused long-range fire takes it down. Walks under water.
-- Self-destructed, it goes up almost like a nuke.
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_korgoth",
	name = "Juggernaut",
	description = "T3 experimental assault bot. A heat ray, two shotgun cannons and long-range missiles; walks under water. Self-destructed, nearly a nuke.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "AMPHIB_WALKER", -- walks on the seafloor (H40, S-210)
	footprint = 3,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 3600, power = 52000, buildTime = 120000 },
	health = 36000,
	movement = { maxSpeed = 7.2, accel = 5, brake = 12, turnRate = 100 },
	sensors = { sight = 240 },
	weapons = {
		{ def = "chs_korgoth_heatray", turretPiece = "torso", pitchPiece = "ray_arm", muzzle = "ray_muzzle" },
		{ def = "chs_korgoth_shotgun", turretPiece = "torso", pitchPiece = "gunL", muzzle = "gunL_muzzle1", muzzles = { "gunL_muzzle1", "gunL_muzzle2" } },
		{ def = "chs_korgoth_shotgun", turretPiece = "torso", pitchPiece = "gunR", muzzle = "gunR_muzzle1", muzzles = { "gunR_muzzle1", "gunR_muzzle2" } },
		{ def = "chs_korgoth_missiles", turretPiece = "torso", muzzle = "missile_pod" },
	},
	pieces = { "base", "thighL", "shinL", "footL", "thighR", "shinR", "footR", "torso", "ray_arm", "ray_muzzle", "gunL", "gunL_muzzle1", "gunL_muzzle2", "gunR", "gunR_muzzle1", "gunR_muzzle2", "missile_pod" },
	selfDestructBlast = { damage = 12000, aoe = 220, edge = 0.25 }, -- almost a nuke (H40)
	icon = "experimental",
	model = "chs_korgoth",
})

--!strict
-- Juggernaut: Chaos's T3 experimental assault bot (S-209, the user's
-- playtest 3 H40; BAR's corkorg). Its id was chs_korgoth until it took
-- chs_juggernaut from the T2 tank, now chs_goliath and retired (S-213). The strongest Chaos land
-- unit: an immensely powerful single-target heat ray, two double-barrelled
-- shotgun cannons, long-range vertical-launch missiles. Short-ranged for its
-- size: focused long-range fire takes it down. Walks under water.
-- Self-destructed or killed, it goes up in a
-- blast a third of a nuke's that can't kill a Commander (S-217, the user;
-- it was almost a nuke, 220 studs, H40). (S-225, the user) A big mech that
-- takes on two Titans: 1.5× the Titan's price, 1.8× its health, 2.2× its DPS.
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "chs_juggernaut",
	name = "Juggernaut",
	description = "Experimental assault bot. A heat ray, two shotgun cannons and missiles; walks under water.",
	faction = "chaos",
	tier = 3,
	domain = "ground",
	moveClass = "AMPHIB_WALKER", -- walks on the seafloor (H40, S-210)
	footprint = 3,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 5400, power = 78000, buildTime = 180000 }, -- (S-225) 1.5× the Titan, as in BAR: it takes on two Titans
	health = 54000,
	movement = { maxSpeed = 7.2, accel = 5, brake = 12, turnRate = 100 },
	sensors = { sight = 240 },
	weapons = {
		{ def = "chs_juggernaut_heatray", turretPiece = "torso", pitchPiece = "ray_arm", muzzle = "ray_muzzle" },
		{ def = "chs_juggernaut_shotgun", turretPiece = "torso", pitchPiece = "gunL", muzzle = "gunL_muzzle1", muzzles = { "gunL_muzzle1", "gunL_muzzle2" } },
		{ def = "chs_juggernaut_shotgun", turretPiece = "torso", pitchPiece = "gunR", muzzle = "gunR_muzzle1", muzzles = { "gunR_muzzle1", "gunR_muzzle2" } },
		{ def = "chs_juggernaut_missiles", turretPiece = "torso", muzzle = "missile_pod" },
	},
	pieces = { "base", "thighL", "shinL", "footL", "thighR", "shinR", "footR", "torso", "ray_arm", "ray_muzzle", "gunL", "gunL_muzzle1", "gunL_muzzle2", "gunR", "gunR_muzzle1", "gunR_muzzle2", "missile_pod" },
	selfDestructBlast = { damage = 480, aoe = 52, edge = 0.25 }, -- (S-217, the user) 35% of a nuke's 150 studs; about 15% of a Commander's health
	deathBlast = { damage = 480, aoe = 52, edge = 0.25 }, -- killed, the same: no larger than its self-destruct (S-217)
	icon = "experimental",
	model = "chs_juggernaut",
})

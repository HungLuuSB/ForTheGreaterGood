--!strict
-- Titan: Order's T3 assault mech (S-209, the user's playtest 3 H40; BAR's
-- armbanth). The heaviest Order unit that walks: Radiance's tachyon beam
-- against heavies, heat-seeking vertical-launch missiles, close-quarters
-- blasters with a wide blast, a huge health reserve. Walks under water. Its
-- reactor makes 250 power and stores 1,000.
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_titan",
	name = "Titan",
	description = "Experimental assault mech. A tachyon beam, heat-seeking missiles and close blasters; walks under water, and its reactor powers your base.",
	faction = "order",
	tier = 3,
	domain = "ground",
	moveClass = "AMPHIB_WALKER", -- walks on the seafloor (H40, S-210)
	footprint = 3,
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 3200, power = 48000, buildTime = 110000 },
	health = 30000,
	movement = { maxSpeed = 8.4, accel = 6, brake = 14, turnRate = 120 },
	sensors = { sight = 260 },
	production = { power = 250 },
	storage = { power = 1000 },
	weapons = {
		{ def = "ord_titan_beam", turretPiece = "torso", pitchPiece = "beam_arm", muzzle = "beam_muzzle" },
		{ def = "ord_titan_missiles", turretPiece = "torso", muzzle = "missile_pod" },
		{ def = "ord_titan_blaster", turretPiece = "torso", pitchPiece = "blaster_arm", muzzle = "blaster_muzzle1", muzzles = { "blaster_muzzle1", "blaster_muzzle2" } },
	},
	pieces = { "base", "thighL", "shinL", "footL", "thighR", "shinR", "footR", "torso", "beam_arm", "beam_muzzle", "missile_pod", "blaster_arm", "blaster_muzzle1", "blaster_muzzle2" },
	selfDestructBlast = { damage = 480, aoe = 52, edge = 0.25 }, -- (S-217, the user) 35% of a nuke's 150 studs; about 15% of a Commander's health
	deathBlast = { damage = 480, aoe = 52, edge = 0.25 }, -- killed, the same: no larger than its self-destruct (S-217)
	icon = "experimental",
	model = "ord_titan",
})

--!strict
-- Thunderer: Order's T3 lightning and EMP tank from the gantry (S-229, the
-- BAR roster program's batch 1; BAR's armthor). A huge tank with a heavy
-- lightning cannon and an EMP projector that stuns what it hits: it
-- freezes a line for the rest of the army. Compressed like the Titan
-- (S-209): about 1.5× its price.
local Templates = require("../Templates")

return Templates.extend(Templates.Unit, {
	id = "ord_thunderer",
	name = "Thunderer",
	description = "Experimental lightning tank. A heavy lightning cannon and an EMP projector that stuns what it hits.",
	faction = "order",
	tier = 3,
	domain = "ground",
	moveClass = "HEAVY_TRACKED",
	footprint = 3, -- (C's blockout, 14-stud hull)
	categories = { "GROUND", "ARMORED" },
	armorClass = "ARMORED",
	cost = { supply = 4800, power = 70000, buildTime = 160000 },
	health = 42000,
	movement = { maxSpeed = 7.5, accel = 5, brake = 12, turnRate = 60 },
	sensors = { sight = 260 },
	weapons = {
		{ def = "ord_thunderer_lightning", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
		{ def = "ord_thunderer_emp", turretPiece = "turret", muzzle = "emp" },
	},
	pieces = { "base", "turret", "barrel", "muzzle", "emp" },
	selfDestructBlast = { damage = 480, aoe = 52, edge = 0.25 }, -- as the Titan's (S-217)
	deathBlast = { damage = 480, aoe = 52, edge = 0.25 },
	icon = "experimental",
	model = "ord_thunderer",
})

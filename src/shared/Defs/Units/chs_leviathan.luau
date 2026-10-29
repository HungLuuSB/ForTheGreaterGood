--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.4 "Carrier", T2); stats to balance in M8.
return Templates.extend(Templates.Unit, {
	id = "chs_leviathan",
	name = "Leviathan",
	description = "Carrier. A mobile airfield with rearm pads, radar and point defence.",
	faction = "chaos",
	tier = 2,
	domain = "naval",
	categories = { "NAVAL", "RADAR_EMITTER" },
	armorClass = "SHIP",
	moveClass = "SHIP",
	footprint = 3,
	cost = { supply = 900, power = 10000, buildTime = 20000 },
	health = 6600,
	movement = { maxSpeed = 10.8, accel = 4, brake = 7, turnRate = 30 },
	sensors = { sight = 260, radar = 600, radarError = 45 },
	weapons = { { def = "chs_flak", turretPiece = "turret1", muzzle = "muzzle1" } },
	pieces = { "base", "turret1", "turret2", "muzzle1", "muzzle2" },
	icon = "carrier",
	rearmPads = 4,
	model = "chs_leviathan",
})

--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_sovereign",
	name = "Sovereign",
	description = "Command vehicle. Builds the first economy and factories; losing it loses the match.",
	faction = "order",
	tier = 0,
	categories = { "GROUND", "WORKER", "COMMANDER" },
	cost = { supply = 1000, power = 10000, buildTime = 30000 },
	health = 3000,
	movement = { maxSpeed = 14.4, accel = 10, brake = 20, turnRate = 90 },
	sensors = { sight = 140 },
	buildPower = 300,
	footprint = 2, -- a 10-stud walking mech (S-124, the user via models-C)
	moveClass = "AMPHIB_WALKER", -- climbs 40° slopes (S-159) and walks the seafloor, hidden from radar under water (S-210, the user's H18 / H19)
	buildRange = 60, -- 70% of 80 (client request 7, S-19), + 4 for the bigger body (S-124: the reach from its edge stays)
	buildOptions = { "ord_extractor", "ord_seaextractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_botlab", "ord_airfield", "ord_shipyard", "ord_sentry_tower", "ord_watchtower", "ord_nano" },
	-- a laser on the left arm and the D-Gun on the right (S-194, the user's G5); both turn with the torso
	pieces = { "base", "nano", "torso", "emitter", "muzzle" }, -- (S-194: the weapons turn with the torso)
	weapons = {
		{ def = "ord_sovereign_laser", turretPiece = "torso", muzzle = "emitter" },
		{ def = "ord_sovereign_dgun", turretPiece = "torso", muzzle = "muzzle" },
	},
	production = { supply = 1, power = 20 },
	deathBlast = { damage = 4000, aoe = 120, edge = 0.15 }, -- a Commander goes up in a huge blast, smaller than a nuke's 150 (S-178, F15)
	model = "ord_sovereign",
	icon = "commander",
})

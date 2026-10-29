--!strict
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_warlord",
	name = "Warlord",
	description = "Command Vehicle. Builds the first economy and factories. Losing it loses the match.",
	faction = "chaos",
	tier = 0,
	categories = { "GROUND", "WORKER", "COMMANDER" },
	cost = { supply = 1000, power = 10000, buildTime = 30000 },
	health = 3400,
	movement = { maxSpeed = 13.2, accel = 9, brake = 18, turnRate = 85 },
	sensors = { sight = 130 },
	buildPower = 300,
	footprint = 2, -- a 10-stud walking mech (S-124, the user via models-C)
	moveClass = "AMPHIB_WALKER", -- climbs 40° slopes (S-159) and walks the seafloor, hidden from radar under water (S-210, the user's H18 / H19)
	buildRange = 60, -- 70% of 80 (client request 7, S-19), + 4 for the bigger body (S-124: the reach from its edge stays)
	buildOptions = { "chs_extractor", "chs_seaextractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_botlab", "chs_airfield", "chs_shipyard", "chs_guard", "chs_eye", "chs_nano" },
	-- a laser on the left arm and the D-Gun on the right (S-194, the user's G5); both turn with the torso
	pieces = { "base", "nano", "torso", "emitter", "muzzle" }, -- (S-194: the weapons turn with the torso)
	weapons = {
		{ def = "chs_warlord_laser", turretPiece = "torso", muzzle = "emitter" },
		{ def = "chs_warlord_dgun", turretPiece = "torso", muzzle = "muzzle" },
	},
	production = { supply = 1, power = 20 },
	deathBlast = { damage = 4000, aoe = 120, edge = 0.15 }, -- a Commander goes up in a huge blast, smaller than a nuke's 150 (S-178, F15)
	model = "chs_warlord",
	icon = "commander",
})

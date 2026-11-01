--!strict
-- Taskmaster: Chaos's advanced construction bot (S-233, the BAR roster program's batch 2;
-- BAR's corack). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_taskmaster",
	name = "Taskmaster",
	description = "Advanced construction bot. Builds the T2 base, and climbs steep slopes.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	moveClass = "WALKER",
	footprint = 1, -- (C's blockout)
	categories = { "GROUND", "WORKER" },
	armorClass = "ARMORED",
	cost = { supply = 420, power = 5000, buildTime = 11000 },
	health = 890,
	movement = { maxSpeed = 14, accel = 20, brake = 25, turnRate = 400 },
	sensors = { sight = 170 },
	buildPower = 200,
	buildRange = 45,
	buildOptions = { "chs_extractor", "chs_solar", "chs_windmill", "chs_converter", "chs_depot", "chs_advextractor", "chs_fusion", "chs_advconverter", "chs_advdepot", "chs_advaccumulator", "chs_advfusion", "chs_advvehplant", "chs_advbotlab", "chs_gantry", "chs_maw", "chs_wyvern", "chs_cataclysm", "chs_allseer", "chs_blackout", "chs_seekerspire", "chs_ragnarok", "chs_augur", "chs_carapace", "chs_bulwark", "chs_hailstorm", "chs_scourge", "chs_cerberus", "chs_basilisk" },
	pieces = { "base", "torso", "nano", "nano1" },
	icon = "worker",
	model = "chs_taskmaster",
})

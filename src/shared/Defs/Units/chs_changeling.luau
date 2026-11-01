--!strict
-- Changeling: Chaos's decoy commander (S-233, the BAR roster program's batch 2;
-- BAR's cordecom). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "chs_changeling",
	name = "Changeling",
	description = "Decoy Commander. Enemies take it for the Warlord even up close; it builds and fights, with half the health.",
	faction = "chaos",
	tier = 2,
	categories = { "GROUND", "WORKER" },
	cost = { supply = 450, power = 5400, buildTime = 15000 },
	health = 1700, -- half the Commander's
	movement = { maxSpeed = 13.2, accel = 9, brake = 18, turnRate = 85 }, -- the Commander's, so its gait gives nothing away
	sensors = { sight = 140 },
	buildPower = 150,
	footprint = 2,
	moveClass = "AMPHIB_WALKER",
	buildRange = 60,
	buildOptions = { "chs_extractor", "chs_seaextractor", "chs_solar", "chs_advsolar", "chs_accumulator", "chs_windmill", "chs_converter", "chs_depot", "chs_vehplant", "chs_botlab", "chs_airfield", "chs_shipyard", "chs_guard", "chs_eye", "chs_nano", "chs_skimyard" },
	pieces = { "base", "nano", "torso", "emitter", "muzzle" }, -- the Commander's
	-- the Commander's laser in its first slot (no D-Gun), so an enemy's view of its aim fits the disguise
	weapons = { { def = "chs_warlord_laser", turretPiece = "torso", muzzle = "emitter" } },
	disguise = "chs_warlord", -- enemies take it for the Commander, even in sight; no wreck (S-233)
	deathBlast = { damage = 800, aoe = 40, edge = 0.3 }, -- far smaller than a Commander's
	model = "chs_warlord", -- the Commander's model (S-233)
	icon = "commander",
})

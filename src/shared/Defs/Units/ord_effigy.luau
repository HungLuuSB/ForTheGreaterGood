--!strict
-- Effigy: Order's decoy commander (S-233, the BAR roster program's batch 2;
-- BAR's armdecom). First-draft numbers from the README's suggested
-- conversion, scaled to our bots (docs/decisions/sim.md S-233).
local Templates = require("../Templates")

return Templates.extend(Templates.Builder, {
	id = "ord_effigy",
	name = "Effigy",
	description = "Decoy Commander. Enemies take it for the Sovereign even up close; it builds and fights, with half the health.",
	faction = "order",
	tier = 2,
	categories = { "GROUND", "WORKER" },
	cost = { supply = 450, power = 5400, buildTime = 15000 },
	health = 1500, -- half the Commander's
	movement = { maxSpeed = 14.4, accel = 10, brake = 20, turnRate = 90 }, -- the Commander's, so its gait gives nothing away
	sensors = { sight = 140 },
	buildPower = 150,
	footprint = 2,
	moveClass = "AMPHIB_WALKER",
	buildRange = 60,
	buildOptions = { "ord_extractor", "ord_seaextractor", "ord_solar", "ord_advsolar", "ord_capacitor", "ord_windmill", "ord_converter", "ord_depot", "ord_vehplant", "ord_botlab", "ord_airfield", "ord_shipyard", "ord_sentry_tower", "ord_watchtower", "ord_nano", "ord_hoverdock" },
	pieces = { "base", "nano", "torso", "emitter", "muzzle" }, -- the Commander's
	-- the Commander's laser in its first slot (no D-Gun), so an enemy's view of its aim fits the disguise
	weapons = { { def = "ord_sovereign_laser", turretPiece = "torso", muzzle = "emitter" } },
	disguise = "ord_sovereign", -- enemies take it for the Commander, even in sight; no wreck (S-233)
	deathBlast = { damage = 800, aoe = 40, edge = 0.3 }, -- far smaller than a Commander's
	model = "ord_sovereign", -- the Commander's model (S-233)
	icon = "commander",
})

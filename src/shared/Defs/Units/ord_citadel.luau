--!strict
local Templates = require("../Templates")

-- Order faction-only structure (docs/design/factions.md section 4; S-75): a
-- T3 fortress block with a long heavy gun, an IR SAM launcher and its own
-- radar. Anchors a front or a choke; siege units and nukes break it.
return Templates.extend(Templates.Structure, {
	id = "ord_citadel",
	name = "Stronghold", -- Citadel until S-225: BAR's Citadel is a different unit
	description = "Fortress. A long heavy gun, an IR SAM and a radar on an armored block.",
	faction = "order",
	tier = 3,
	categories = { "STRUCTURE", "RADAR_EMITTER" },
	cost = { supply = 1000, power = 10000, buildTime = 24000 },
	health = 9000,
	footprint = 7, -- size shows tech level (S-104)
	sensors = { sight = 300, airSight = 206, radar = 900, radarError = 16, radarDrain = 4 },
	weapons = {
		{ def = "ord_citadel_gun", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" },
		{ def = "ord_ir_sam", turretPiece = "launcher", muzzle = "muzzle2" },
	},
	pieces = { "base", "turret", "barrel", "muzzle", "launcher", "muzzle2", "radar" },
	icon = "fortress",
	model = "ord_citadel",
})

--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Gun turret", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "ord_bulwark",
	name = "Bulwark",
	description = "Gun turret. A light cannon emplacement.",
	faction = "order",
	retired = true, -- (S-157) Sentry (ord_sentry_tower) took its place as the T1 basic tower; kept for old replays and scenes
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 120, power = 900, buildTime = 2400 },
	-- S-179, the playtest's balance notes: health × 2
	health = 3600,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 230 },
	weapons = { { def = "ord_bulwark_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret",
	model = "ord_bulwark",
})

--!strict
local Templates = require("../Templates")

-- Placeholder (guide 13.5 "Gun turret", T1); stats to balance in M8.
return Templates.extend(Templates.Structure, {
	id = "chs_spike",
	name = "Spike",
	description = "Gun turret. A light cannon emplacement.",
	faction = "chaos",
	retired = true, -- (S-157) Guard (chs_guard) took its place as the T1 basic tower; kept for old replays and scenes
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 120, power = 900, buildTime = 2400 },
	-- S-179, the playtest's balance notes: health × 2
	health = 4000,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 210 },
	weapons = { { def = "chs_spike_cannon", turretPiece = "turret", muzzle = "muzzle" } },
	pieces = { "base", "turret", "muzzle" },
	icon = "turret",
	model = "chs_spike",
})

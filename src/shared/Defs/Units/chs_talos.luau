--!strict
local Templates = require("../Templates")

-- Chaos T1 lobbing gun (S-157, the user; Talos, the bronze giant who hurled
-- rocks): Gauntlet's counterpart with less range.
return Templates.extend(Templates.Structure, {
	id = "chs_talos",
	name = "Talos",
	description = "Lobbing gun. High-arc shells, shorter range than Gauntlet; slow to land.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 220, power = 1850, buildTime = 4800 },
	-- S-179, the playtest's balance notes: health × 2
	health = 2100,
	footprint = 2, -- size shows tech level (S-104)
	sensors = { sight = 220 },
	weapons = { { def = "chs_talos_shell", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "turret", "barrel", "muzzle" },
	icon = "artillery",
	model = "chs_talos",
})

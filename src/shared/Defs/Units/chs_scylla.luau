--!strict
local Templates = require("../Templates")

-- Naval SAM platform (guide 13.5, S-166): a floating radar SAM site, the
-- Corsair's naval SAM on its own radar; built on water by the Reaver. Can
-- be jammed; chaff decoys it.
return Templates.extend(Templates.Structure, {
	id = "chs_scylla",
	name = "Scylla",
	description = "Naval SAM platform. Radar-guided missiles against aircraft, on the water. Own radar; can be jammed.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 280, power = 3600, buildTime = 7500 },
	health = 2400,
	footprint = 3,
	sensors = { sight = 160, radar = 560, radarError = 22 },
	weapons = { { def = "chs_naval_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	placement = "water",
	model = "chs_scylla",
	icon = "sam_radar",
})

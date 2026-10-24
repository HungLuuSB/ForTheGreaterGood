--!strict
local Templates = require("../Templates")

-- Naval SAM platform (guide 13.5, S-166): a floating radar SAM site, the
-- Crusader's naval SAM on its own radar; built on water by the
-- Harbormaster. Can be jammed; chaff decoys it.
return Templates.extend(Templates.Structure, {
	id = "ord_pharos",
	name = "Pharos",
	description = "Naval SAM platform. Radar-guided missiles against aircraft, on the water. Own radar; can be jammed.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 300, power = 3800, buildTime = 8000 },
	health = 2200,
	footprint = 3,
	sensors = { sight = 160, radar = 600, radarError = 20 },
	weapons = { { def = "ord_naval_sam", turretPiece = "launcher", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" },
	placement = "water",
	model = "ord_pharos",
	icon = "sam_radar",
})

--!strict
local Templates = require("../Templates")

-- Order faction-only structure (docs/design/factions.md section 4; S-75):
-- a cheap wall segment. It blocks movement (structures take their cells out
-- of passability) and low direct fire (shots hit it, like any unit in their
-- path). Funnels attackers into kill zones; artillery and siege break it.
return Templates.extend(Templates.Structure, {
	id = "ord_barrier",
	name = "Barrier",
	description = "Wall segment. Blocks movement and low direct fire.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 20, power = 200, buildTime = 600 },
	health = 2500,
	footprint = 1,
	sensors = { sight = 40 },
	pieces = { "base" },
	icon = "wall",
	model = "ord_barrier",
})

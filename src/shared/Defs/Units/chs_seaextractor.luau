--!strict
local Templates = require("../Templates")

-- Submerged extractor (S-209, the user's playtest 3 H20; BAR's coruwmex): built
-- by an underwater builder on a deposit under the sea, and hidden under it:
-- only torpedoes can hit it (subs, some ships, torpedo bombers).
return Templates.extend(Templates.Structure, {
	id = "chs_seaextractor",
	name = "Sunken Excavator",
	description = "Offshore extractor. Mines a supply deposit under the sea; only torpedoes reach it.",
	faction = "chaos",
	tier = 1,
	categories = { "STRUCTURE", "SUB" },
	armorClass = "SUB",
	placement = "seafloor",
	cost = { supply = 60, power = 600, buildTime = 2000 },
	health = 500,
	footprint = 2, -- size shows tech level (S-104)
	extractor = { rate = 0.5, upkeep = 3 },
	icon = "extractor",
	model = "chs_seaextractor",
})

--!strict
local Templates = require("../Templates")

-- H30: the Advanced Fusion Reactor (S-209, the user's playtest 3; BAR's armafus / corafus).
return Templates.extend(Templates.Structure, {
	id = "ord_advfusion",
	name = "Advanced Fusion Reactor",
	description = "Advanced fusion reactor. Makes 3,000 power and stores 9,000; explodes like a small nuke.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 2600, power = 48000, buildTime = 90000 },
	health = 6000,
	footprint = 6, -- size shows tech level (S-104)
	production = { power = 3000 }, -- (H30)
	storage = { power = 9000 },
	deathBlast = { damage = 6000, aoe = 180, edge = 0.2 }, -- BAR's afus: a nuke-sized blast
	icon = "fusion",
	model = "ord_advfusion",
})

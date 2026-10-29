--!strict
local Templates = require("../Templates")

-- Construction Turret, the "nano" (S-209, the user's playtest 3 H31; BAR's
-- armnanotc): a T1 structure that builds nothing of its own but assists,
-- repairs and reclaims anything in reach, with more build power than any T1
-- unit but the Commander. Left alone it fights (FIGHT): repairs, assists and
-- reclaims what comes in range, enemy units too. Its death hurts only the
-- nanos around it (a pack chain-explodes); a self-destructed one hurts none.
return Templates.extend(Templates.Structure, {
	id = "ord_nano",
	name = "Construction Turret",
	description = "Construction turret. Assists, repairs and reclaims everything in its reach; never moves.",
	faction = "order",
	tier = 1,
	categories = { "STRUCTURE" },
	cost = { supply = 70, power = 1300, buildTime = 2600 },
	health = 420,
	footprint = 2, -- size shows tech level (S-104)
	assistOnly = true,
	buildPower = 200,
	buildRange = 150,
	deathBlast = { damage = 600, aoe = 40, edge = 0.4, onlyDefs = { "ord_nano", "chs_nano" }, notSelfDestruct = true },
	pieces = { "base", "turret", "nano" }, -- the nano emitter turns to its work
	icon = "nano",
	model = "ord_nano",
})

--!strict
local Templates = require("../Templates")

-- Chaos mobile anti-nuke (S-111, the user): a light T2 vehicle with
-- one interceptor (the structures hold three), about 60% of the
-- structure's coverage, slower to restock. It intercepts only while
-- stopped: the launcher has to raise. No other weapon. Placeholder numbers.
return Templates.extend(Templates.Unit, {
	id = "chs_chimera",
	name = "Chimera",
	description = "Mobile anti-nuke. One interceptor; shoots down enemy nukes near it while stopped. No other weapon.",
	faction = "chaos",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 360, power = 5200, buildTime = 8000 },
	health = 760,
	movement = { maxSpeed = 30, accel = 10, brake = 22, turnRate = 100 },
	sensors = { sight = 150 }, -- no radar needed: it spots strategic missiles anywhere (the user, S-111)
	weapons = { { def = "chs_mobile_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" }, -- (a turning "radar" is client-only)
	icon = "antinuke",
	model = "chs_chimera",
})

--!strict
local Templates = require("../Templates")

-- Order mobile anti-nuke (S-111, the user): a light T2 vehicle with
-- one interceptor (the structures hold three), about 60% of the
-- structure's coverage, slower to restock. It intercepts only while
-- stopped: the launcher has to raise. No other weapon. Placeholder numbers.
return Templates.extend(Templates.Unit, {
	id = "ord_custodian",
	name = "Custodian",
	description = "Mobile anti-nuke. Carries one interceptor and shoots down enemy nukes near it while stopped.",
	faction = "order",
	tier = 2,
	domain = "ground",
	categories = { "GROUND", "LIGHT" },
	armorClass = "LIGHT",
	moveClass = "WHEELED",
	footprint = 1,
	cost = { supply = 420, power = 6000, buildTime = 9000 },
	health = 900,
	movement = { maxSpeed = 18, accel = 10, brake = 22, turnRate = 100 },
	sensors = { sight = 150 }, -- no radar needed: it spots strategic missiles anywhere (the user, S-111)
	weapons = { { def = "ord_mobile_interceptor", muzzle = "muzzle" } },
	pieces = { "base", "launcher", "muzzle" }, -- (a turning "radar" is client-only)
	icon = "antinuke",
	model = "ord_custodian",
})

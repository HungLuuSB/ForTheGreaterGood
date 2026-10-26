--!strict
local Templates = require("../Templates")

-- Chaos decoy drone (S-109, next.md item 4; design S-75): cheap, unarmed,
-- built in groups. On radar it shows as a Behemoth strategic bomber
-- (`spoof`) until sight or a fire-control radar identifies it, so radar
-- SAMs and fighters spend missiles on it ahead of a real raid.
return Templates.extend(Templates.Unit, {
	id = "chs_wraith",
	name = "Wraith",
	description = "Decoy drone. Shows as a strategic bomber on enemy radar until seen or tracked; draws SAM fire.",
	faction = "chaos",
	tier = 2,
	domain = "air",
	categories = { "AIR", "JET" },
	armorClass = "AIR",
	moveClass = "JET",
	footprint = 1,
	cost = { supply = 40, power = 200, buildTime = 900 },
	health = 120,
	movement = { maxSpeed = 120, minSpeed = 72, accel = 90, brake = 70, turnRate = 90 },
	sensors = { sight = 120, radarSignature = 1 },
	spoof = "chs_behemoth",
	weapons = {},
	pieces = { "base" },
	icon = "bomber_heavy",
	model = "chs_wraith",
})

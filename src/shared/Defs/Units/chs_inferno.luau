--!strict
local Templates = require("../Templates")

-- Chaos T2 beam tower (S-96, client request 43): Radiance's counterpart,
-- shorter (560) and lighter (2,000 every 7 s, 500 power a shot), cheaper.
-- Switched off it retracts into its armored shell: no fire, a quarter of
-- the damage.
return Templates.extend(Templates.Structure, {
	id = "chs_inferno",
	name = "Inferno",
	description = "Beam tower. A precise, heavy shot for 500 power. Off: retracts into its armor.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 420, power = 5000, buildTime = 13000 },
	health = 2600,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 180 },
	retract = { armor = 4 },
	weapons = { { def = "chs_inferno_beam", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "shell", "turret", "barrel", "muzzle" },
	icon = "beam",
	model = "chs_inferno",
})

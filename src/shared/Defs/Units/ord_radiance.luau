--!strict
local Templates = require("../Templates")

-- Order T2 beam tower (S-96, client request 43; BAR's Pulsar): a precise
-- long beam, one very heavy hit every 9 s, 700 power a shot. Fires over
-- other defenses (beams are blocked by terrain only). Switched off it
-- retracts into its armored shell: no fire, a quarter of the damage.
return Templates.extend(Templates.Structure, {
	id = "ord_radiance",
	name = "Radiance",
	description = "Beam tower. A precise, very heavy shot at long range for 700 power. Off: retracts into its armor.",
	faction = "order",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 550, power = 6500, buildTime = 16000 },
	health = 3200,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 200 },
	retract = { armor = 4 },
	weapons = { { def = "ord_radiance_beam", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" } },
	pieces = { "base", "shell", "turret", "barrel", "muzzle" },
	icon = "beam",
	model = "ord_radiance",
})

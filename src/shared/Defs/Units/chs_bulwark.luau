--!strict
local Templates = require("../Templates")

-- Chaos T2 beam tower (S-157, the user): Radiance's counterpart in Inferno's
-- place. A Radiance-style beam with Inferno's numbers (chs_bulwark_beam), and
-- Geryon's green laser on its own turret for closer targets. Switched off it
-- retracts into its armored shell: no fire, a quarter of the damage.
return Templates.extend(Templates.Structure, {
	id = "chs_bulwark",
	name = "Bulwark",
	description = "Beam tower. A heavy beam for 500 power a shot and a green laser for close targets; retracts into its armor when off.",
	faction = "chaos",
	tier = 2,
	categories = { "STRUCTURE" },
	cost = { supply = 420, power = 5000, buildTime = 13000 },
	health = 2600,
	footprint = 3, -- size shows tech level (S-104)
	sensors = { sight = 200 },
	retract = { armor = 4 },
	weapons = { { def = "chs_bulwark_beam", turretPiece = "turret", pitchPiece = "barrel", muzzle = "muzzle" }, { def = "chs_bulwark_laser", turretPiece = "laser", pitchPiece = "laser_mount", muzzle = "laser_muzzle1", muzzles = { "laser_muzzle1", "laser_muzzle2", "laser_muzzle3" }, drumPiece = "laser_drum" } },
	pieces = { "base", "shell", "turret", "barrel", "muzzle", "laser", "laser_mount", "laser_drum", "laser_muzzle1", "laser_muzzle2", "laser_muzzle3" },
	icon = "beam",
	model = "chs_bulwark",
})

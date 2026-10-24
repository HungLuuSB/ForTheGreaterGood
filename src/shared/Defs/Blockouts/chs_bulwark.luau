--!strict
-- Bulwark (Chaos beam tower, T2, footprint 3; S-157, Inferno's replacement;
-- the user's reference 2026-10-24: a sturdy stacked multi-weapon tower with
-- guns at different heights). A heavy buttressed base with reactive blocks
-- and twin power drums at the back, an armored middle tier, and on top the
-- armored `shell` sleeve carrying the beam `turret`: a heavy head with a
-- single big "eye" lens and a long beam `barrel` (`muzzle` at its tip). On
-- the middle tier's front right corner a bastion carries the second turret,
-- `laser`: a Geryon-style rotary `laser_drum` of three green barrels
-- (`laser_muzzle1` the top one at rest; the client turns the drum 120 degrees
-- per shot). Switched off the head sinks into the sleeve and the barrel
-- folds down (pose `retracted`). Rugged and improvised (M-14). Model space,
-- forward = -Z.

local LX, LY, LZ = 5.6, 9.0, -5.6 -- the laser turret's pivot, on the bastion
local DY, DZ, R = LY + 1.5, LZ - 1.3, 0.7 -- its drum's axis and the barrels' distance from it

local function lat(k: number, z: number): { number }
	local a = math.rad(90 + (k - 1) * 120)
	return { LX + R * math.cos(a), DY + R * math.sin(a), z }
end

local parts = {
	{ name = "base", shape = "box", size = { 17, 4, 17 }, at = { 0, 2, 0 }, color = "dark" },
	{ name = "buttressFL", parent = "base", shape = "wedge", size = { 3, 4, 3 }, at = { -7.6, 2, -9.6 }, color = "hull" },
	{ name = "buttressFR", parent = "base", shape = "wedge", size = { 3, 4, 3 }, at = { 7.6, 2, -9.6 }, color = "hull" },
	{ name = "drumL", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 4.6, 3.4 }, at = { -5.4, 6.3, 7.2 }, color = "metal" },
	{ name = "drumR", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 4.6, 3.4 }, at = { -1.4, 6.3, 7.4 }, color = "metal" },
	{ name = "eraL", parent = "base", shape = "box", size = { 0.6, 2.4, 7 }, at = { -8.8, 2.6, -1 }, color = "metal" },
	{ name = "eraR", parent = "base", shape = "box", size = { 0.6, 2.4, 7 }, at = { 8.8, 2.6, -1 }, color = "metal" },
	{ name = "vent", parent = "base", shape = "box", size = { 4, 2.4, 0.2 }, at = { 0, 2.2, -8.6 }, color = "glass" },
	{ name = "team", parent = "base", shape = "box", size = { 4.6, 0.08, 2.4 }, at = { 4.6, 4.04, 5.4 }, color = "team" },
	{ name = "hazard", parent = "base", shape = "box", size = { 10, 0.06, 0.6 }, at = { 0, 4.03, -7.9 }, color = "hazard" },
	{ name = "tier", parent = "base", shape = "box", size = { 11, 4, 11 }, at = { 0, 6, 0 }, color = "hull" },
	{ name = "tierTeamL", parent = "base", shape = "box", size = { 0.08, 2.2, 4.0 }, at = { -5.54, 6.2, -1.0 }, color = "team" },
	{ name = "bastion", parent = "base", shape = "box", size = { 4.6, 1.2, 4.6 }, at = { LX, 8.4, LZ }, color = "hull" },
	{ name = "coil", parent = "base", shape = "cylinder", axis = "x", size = { 8, 0.9, 0.9 }, at = { -1.2, 7.4, -5.7 }, color = "glass" },

	-- the armored sleeve the beam head sits on (the def's `shell`; it doesn't move)
	{ name = "shell", parent = "base", shape = "box", size = { 7.6, 5, 7.6 }, at = { 0, 10.5, 0.4 }, pivot = { 0, 8, 0 }, color = "dark" },
	{ name = "shellPlateL", parent = "shell", shape = "box", size = { 0.5, 4.2, 6.4 }, at = { -4.0, 10.6, 0.4 }, color = "metal" },
	{ name = "shellPlateR", parent = "shell", shape = "box", size = { 0.5, 4.2, 6.4 }, at = { 4.0, 10.6, 0.4 }, color = "metal" },
	{ name = "shellTeam", parent = "shell", shape = "box", size = { 3.0, 1.4, 0.08 }, at = { 0, 11.2, -3.44 }, color = "team" },

	{ name = "turret", parent = "base", shape = "box", size = { 6.4, 3.4, 6.8 }, at = { 0, 14.7, 0.5 }, pivot = { 0, 13, 0 }, color = "hull" },
	{ name = "headTop", parent = "turret", shape = "wedge", size = { 6.4, 1.4, 2.4 }, at = { 0, 17.1, -1.6 }, color = "hull" },
	{ name = "eye", parent = "turret", shape = "ball", size = { 2.0, 2.0, 2.0 }, at = { 1.8, 15.6, -2.9 }, color = "glass" },
	{ name = "headTeam", parent = "turret", shape = "box", size = { 3.4, 0.08, 2.6 }, at = { 0, 16.44, 2.2 }, color = "team" },
	{ name = "heatsink", parent = "turret", shape = "box", size = { 5.4, 2.2, 0.6 }, at = { 0, 14.8, 4.2 }, color = "metal" },
	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 7.4 }, at = { -0.8, 14.6, -6.0 }, pivot = { -0.8, 14.6, -2.4 }, color = "metal" },
	{ name = "barrelRing", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 0.6 }, at = { -0.8, 14.6, -4.0 }, color = "dark" },
	{ name = "barrelTip", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 0.8 }, at = { -0.8, 14.6, -9.4 }, color = "dark" },

	{ name = "laser", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 1.6, 3.4 }, at = { LX, LY + 0.8, LZ + 0.4 }, pivot = { LX, LY, LZ }, color = "hull" },
	{ name = "laserSensor", parent = "laser", shape = "box", size = { 0.5, 0.4, 0.4 }, at = { LX + 1.3, LY + 1.4, LZ - 0.9 }, color = "glass" },
	{ name = "laser_drum", parent = "laser", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 1.0 }, at = { LX, DY, DZ }, pivot = { LX, DY, DZ }, color = "metal" },
}
for k = 1, 3 do
	table.insert(parts, { name = `laserBarrel{k}`, parent = "laser_drum", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 3.2 }, at = lat(k, DZ - 2.0), color = "metal" })
	table.insert(parts, { name = `laserLens{k}`, parent = "laser_drum", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.2 }, at = lat(k, DZ - 3.65), color = "glass" })
end

return {
	id = "chs_bulwark",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { -0.8, 14.6, -9.9 } },
		{ name = "laser_muzzle1", parent = "laser_drum", at = lat(1, DZ - 3.8) },
		{ name = "laser_muzzle2", parent = "laser_drum", at = lat(2, DZ - 3.8) },
		{ name = "laser_muzzle3", parent = "laser_drum", at = lat(3, DZ - 3.8) },
	},
}

--!strict
-- Bulwark (Chaos beam tower, T2, footprint 3; S-157, Inferno's replacement):
-- a big dark armored base with charge coils, a crude armored `shell` collar
-- round a central pit holding the beam `turret` (a column with a single big
-- "eye" lens head and a short emitter `barrel`, `muzzle` at its tip), and on
-- the front right corner a second turret, `laser`: a Geryon-style rotary
-- `laser_drum` of three green barrels (`laser_muzzle1` the top one at rest;
-- the client turns the drum 120 degrees per shot). Switched off it retracts
-- like the Inferno: the beam turret sinks, the emitter folds, and the crude
-- lids (client-only `shellL` / `shellR`, hinged on the collar) close over the
-- pit (pose `retracted`). Model space, forward = -Z.

local LX, LY, LZ = 6.0, 5.2, -5.0 -- the laser turret's pivot
local DY, DZ, R = LY + 1.6, LZ - 1.4, 0.7 -- its drum's axis and the barrels' distance from it

local function lat(k: number, z: number): { number }
	local a = math.rad(90 + (k - 1) * 120)
	return { LX + R * math.cos(a), DY + R * math.sin(a), z }
end

local parts = {
	{ name = "base", shape = "box", size = { 19, 4, 19 }, at = { 0, 2, 0 }, color = "dark" },
	{ name = "pit", parent = "base", shape = "box", size = { 8, 0.1, 8 }, at = { 0, 4.02, 0 }, color = "dark" },
	{ name = "team", parent = "base", shape = "box", size = { 5, 0.08, 1.8 }, at = { 0, 4.04, 7.8 }, color = "team" },
	{ name = "coilF", parent = "base", shape = "cylinder", axis = "x", size = { 10, 1.0, 1.0 }, at = { -2, 3.2, -9.0 }, color = "glass" },
	{ name = "coilB", parent = "base", shape = "cylinder", axis = "x", size = { 12, 1.0, 1.0 }, at = { 0, 3.2, 9.0 }, color = "glass" },
	{ name = "tankL", parent = "base", shape = "cylinder", axis = "y", size = { 2.8, 3.4, 2.8 }, at = { -7.4, 5.7, 6.6 }, color = "metal" },
	{ name = "eraL", parent = "base", shape = "box", size = { 0.6, 2.0, 6 }, at = { -9.6, 2.6, -2 }, color = "metal" },
	{ name = "hazard", parent = "base", shape = "box", size = { 8, 0.06, 0.6 }, at = { -3, 4.03, -8.2 }, color = "hazard" },
	{ name = "laserPad", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 1.2, 4.4 }, at = { LX, 4.6, LZ }, color = "hull" },

	-- the crude collar round the pit (the def's `shell`; it doesn't move)
	{ name = "shell", parent = "base", shape = "box", size = { 10.5, 0.8, 1.3 }, at = { 0, 4.4, -4.6 }, pivot = { 0, 4, 0 }, color = "metal" },
	{ name = "collarB", parent = "shell", shape = "box", size = { 10.5, 0.8, 1.3 }, at = { 0, 4.4, 4.6 }, color = "metal" },
	{ name = "collarL", parent = "shell", shape = "box", size = { 1.3, 0.8, 8 }, at = { -4.6, 4.4, 0 }, color = "metal" },
	{ name = "collarR", parent = "shell", shape = "box", size = { 1.3, 0.8, 8 }, at = { 4.6, 4.4, 0 }, color = "metal" },

	{ name = "turret", parent = "base", shape = "box", size = { 2.2, 8, 2.2 }, at = { 0, 8, 0 }, pivot = { 0, 4, 0 }, color = "hull" },
	{ name = "head", parent = "turret", shape = "box", size = { 4.0, 2.4, 3.4 }, at = { 0, 12.8, 0.3 }, color = "hull" },
	{ name = "eye", parent = "turret", shape = "ball", size = { 1.9, 1.9, 1.9 }, at = { 0, 12.8, -1.6 }, color = "glass" },
	{ name = "headTeam", parent = "turret", shape = "box", size = { 2.6, 0.08, 2.0 }, at = { 0, 14.04, 0.5 }, color = "team" },
	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 5.2 }, at = { 0, 12.8, -4.5 }, pivot = { 0, 12.8, -1.9 }, color = "metal" },

	{ name = "laser", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 1.6, 3.4 }, at = { LX, LY + 0.8, LZ + 0.4 }, pivot = { LX, LY, LZ }, color = "hull" },
	{ name = "laserSensor", parent = "laser", shape = "box", size = { 0.5, 0.4, 0.4 }, at = { LX + 1.3, LY + 1.4, LZ - 0.9 }, color = "glass" },
	{ name = "laser_drum", parent = "laser", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 1.0 }, at = { LX, DY, DZ }, pivot = { LX, DY, DZ }, color = "metal" },
}
for k = 1, 3 do
	table.insert(parts, { name = `laserBarrel{k}`, parent = "laser_drum", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 3.2 }, at = lat(k, DZ - 2.0), color = "metal" })
	table.insert(parts, { name = `laserLens{k}`, parent = "laser_drum", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.2 }, at = lat(k, DZ - 3.65), color = "glass" })
end
table.insert(parts, { name = "shellL", parent = "shell", shape = "box", size = { 0.6, 4.0, 8 }, at = { -4.2, 6.6, 0 }, pivot = { -4.2, 4.6, 0 }, color = "metal" })
table.insert(parts, { name = "shellR", parent = "shell", shape = "box", size = { 0.6, 4.0, 8 }, at = { 4.2, 6.6, 0 }, pivot = { 4.2, 4.6, 0 }, color = "metal" })

return {
	id = "chs_bulwark",
	visualPieces = { "shellL", "shellR" },
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 12.8, -7.2 } },
		{ name = "laser_muzzle1", parent = "laser_drum", at = lat(1, DZ - 3.8) },
		{ name = "laser_muzzle2", parent = "laser_drum", at = lat(2, DZ - 3.8) },
		{ name = "laser_muzzle3", parent = "laser_drum", at = lat(3, DZ - 3.8) },
	},
}

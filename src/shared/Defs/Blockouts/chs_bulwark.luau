--!strict
-- Bulwark (Chaos beam tower, T2, footprint 3; S-157, Inferno's replacement).
-- The user's reference (2026-10-24, BAR's Bulwark as the idea: weapons
-- stacked on top of each other, each turning on its own): a heavy buttressed
-- base with reactive blocks and twin power drums, then a vertical stack of
-- tiers. Lowest, the `laser` ring: a full-width rotating armored ring with a
-- Geryon-style rotary `laser_drum` of three green barrels on its front
-- (`laser_muzzle1` the top one at rest; the client turns the drum 120
-- degrees per shot). Above it the armored collar `shell` (static). On top the
-- beam `turret`: a heavy head with a single big "eye" lens and a long beam
-- `barrel` (`muzzle` at its tip). Switched off, the head sinks onto the
-- collar and the barrel folds down (pose `retracted`). Rugged and improvised
-- (M-14). Model space, forward = -Z.

local LY = 5.6 -- the laser ring's pivot height
local DY, DZ, R = LY + 1.5, -4.9, 0.7 -- its drum's axis and the barrels' distance from it

local function lat(k: number, z: number): { number }
	local a = math.rad(90 + (k - 1) * 120)
	return { R * math.cos(a), DY + R * math.sin(a), z }
end

local parts = {
	{ name = "base", shape = "box", size = { 16, 4, 16 }, at = { 0, 2, 0 }, color = "dark" },
	{ name = "buttressFL", parent = "base", shape = "wedge", size = { 3, 4, 3 }, at = { -6.4, 2, -9.0 }, color = "hull" },
	{ name = "buttressFR", parent = "base", shape = "wedge", size = { 3, 4, 3 }, at = { 6.4, 2, -9.0 }, color = "hull" },
	{ name = "drumL", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 4.0, 3.2 }, at = { -5.2, 6.0, 5.6 }, color = "metal" },
	{ name = "drumR", parent = "base", shape = "cylinder", axis = "y", size = { 3.2, 4.0, 3.2 }, at = { 5.2, 6.0, 5.6 }, color = "metal" },
	{ name = "eraL", parent = "base", shape = "box", size = { 0.6, 2.4, 7 }, at = { -8.3, 2.6, -1 }, color = "metal" },
	{ name = "eraR", parent = "base", shape = "box", size = { 0.6, 2.4, 7 }, at = { 8.3, 2.6, -1 }, color = "metal" },
	{ name = "vent", parent = "base", shape = "box", size = { 4, 2.4, 0.2 }, at = { 0, 2.2, -8.1 }, color = "glass" },
	{ name = "team", parent = "base", shape = "box", size = { 4.6, 0.08, 2.4 }, at = { 0, 4.04, 6.4 }, color = "team" },
	{ name = "hazard", parent = "base", shape = "box", size = { 10, 0.06, 0.6 }, at = { 0, 4.03, -7.4 }, color = "hazard" },
	{ name = "plinth", parent = "base", shape = "cylinder", axis = "y", size = { 9.6, 1.6, 9.6 }, at = { 0, 4.8, 0 }, color = "hull" },

	-- tier 1: the laser ring, turning on its own
	{ name = "laser", parent = "base", shape = "cylinder", axis = "y", size = { 8.8, 3.0, 8.8 }, at = { 0, LY + 1.5, 0 }, pivot = { 0, LY, 0 }, color = "hull" },
	{ name = "laserPlateL", parent = "laser", shape = "box", size = { 0.5, 2.4, 4.0 }, at = { -4.5, LY + 1.5, 0.6 }, color = "metal" },
	{ name = "laserPlateR", parent = "laser", shape = "box", size = { 0.5, 2.4, 4.0 }, at = { 4.5, LY + 1.5, 0.6 }, color = "metal" },
	{ name = "laserTeam", parent = "laser", shape = "box", size = { 2.8, 1.2, 0.08 }, at = { 0, LY + 1.5, 4.42 }, color = "team" },
	{ name = "laserMount", parent = "laser", shape = "box", size = { 2.6, 2.6, 1.4 }, at = { 0, DY, -4.2 }, color = "dark" },
	{ name = "laserSensor", parent = "laser", shape = "box", size = { 0.5, 0.4, 0.3 }, at = { 2.0, LY + 2.4, -4.3 }, color = "glass" },
	{ name = "laser_drum", parent = "laser", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 1.0 }, at = { 0, DY, DZ }, pivot = { 0, DY, DZ }, color = "metal" },

	-- tier 2: the armored collar (the def's `shell`; it doesn't move)
	{ name = "shell", parent = "base", shape = "box", size = { 7.2, 2.2, 7.2 }, at = { 0, LY + 4.1, 0.2 }, pivot = { 0, LY + 3.0, 0 }, color = "dark" },
	{ name = "collarRing", parent = "shell", shape = "cylinder", axis = "y", size = { 8.0, 0.6, 8.0 }, at = { 0, LY + 3.3, 0 }, color = "metal" },

	-- tier 3: the beam head on top, turning on its own
	{ name = "turret", parent = "base", shape = "box", size = { 6.6, 3.6, 7.0 }, at = { 0, LY + 7.0, 0.5 }, pivot = { 0, LY + 5.2, 0 }, color = "hull" },
	{ name = "headTop", parent = "turret", shape = "wedge", size = { 6.6, 1.4, 2.4 }, at = { 0, LY + 9.5, -1.7 }, color = "hull" },
	{ name = "eye", parent = "turret", shape = "ball", size = { 2.0, 2.0, 2.0 }, at = { 1.9, LY + 7.8, -3.0 }, color = "glass" },
	{ name = "headTeam", parent = "turret", shape = "box", size = { 3.4, 0.08, 2.6 }, at = { 0, LY + 8.84, 2.3 }, color = "team" },
	{ name = "heatsink", parent = "turret", shape = "box", size = { 5.6, 2.2, 0.6 }, at = { 0, LY + 7.1, 4.3 }, color = "metal" },
	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 7.4 }, at = { -0.8, LY + 6.9, -6.1 }, pivot = { -0.8, LY + 6.9, -2.5 }, color = "metal" },
	{ name = "barrelRing", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.8, 1.8, 0.6 }, at = { -0.8, LY + 6.9, -4.1 }, color = "dark" },
	{ name = "barrelTip", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 0.8 }, at = { -0.8, LY + 6.9, -9.5 }, color = "dark" },
}
for k = 1, 3 do
	table.insert(parts, { name = `laserBarrel{k}`, parent = "laser_drum", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 3.2 }, at = lat(k, DZ - 2.0), color = "metal" })
	table.insert(parts, { name = `laserLens{k}`, parent = "laser_drum", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.2 }, at = lat(k, DZ - 3.65), color = "glass" })
end

return {
	id = "chs_bulwark",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { -0.8, LY + 6.9, -10.0 } },
		{ name = "laser_muzzle1", parent = "laser_drum", at = lat(1, DZ - 3.8) },
		{ name = "laser_muzzle2", parent = "laser_drum", at = lat(2, DZ - 3.8) },
		{ name = "laser_muzzle3", parent = "laser_drum", at = lat(3, DZ - 3.8) },
	},
}

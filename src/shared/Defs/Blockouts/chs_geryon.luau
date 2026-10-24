--!strict
-- Geryon (Chaos triple laser tower, T1, footprint 2; S-157; the user's
-- reference 2026-10-24: a tall column with a heavy head of three long
-- barrels): a square armored footing, a tall slab column with team panels
-- down its faces, and on top the `turret`, an angular head; in front of it
-- the `drum`, a rotary cluster of three long green laser barrels in a
-- triangle about the drum's forward axis. Only the top barrel fires; the
-- client turns the drum 120 degrees per shot (`muzzle1` the top one at
-- rest). Each barrel is a client piece (`barrel1..3`) for its own recoil.
-- The drum hangs from `mount`, which the def pitches -60..+60 degrees.
-- Model space, forward = -Z.

local CY, CZ, R = 12.6, -1.4, 0.9 -- the drum's axis (height, depth) and the barrels' distance from it

local function at(k: number, z: number): { number }
	local a = math.rad(90 + (k - 1) * 120) -- barrel1 on top, then round
	return { R * math.cos(a), CY + R * math.sin(a), z }
end

local parts = {
	{ name = "base", shape = "box", size = { 7.0, 1.2, 7.0 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "box", size = { 5.0, 2.0, 5.0 }, at = { 0, 2.2, 0 }, color = "metal" },
	{ name = "column", parent = "base", shape = "box", size = { 3.4, 7.6, 3.0 }, at = { 0, 7.0, 0.3 }, color = "hull" },
	{ name = "colTeamF", parent = "base", shape = "box", size = { 1.0, 6.4, 0.08 }, at = { -0.9, 7.0, -1.24 }, color = "team" },
	{ name = "colTeamF2", parent = "base", shape = "box", size = { 1.0, 6.4, 0.08 }, at = { 0.9, 7.0, -1.24 }, color = "team" },
	{ name = "colTeamL", parent = "base", shape = "box", size = { 0.08, 6.4, 1.6 }, at = { -1.74, 7.0, 0.3 }, color = "team" },
	{ name = "colTeamR", parent = "base", shape = "box", size = { 0.08, 6.4, 1.6 }, at = { 1.74, 7.0, 0.3 }, color = "team" },
	{ name = "hazard", parent = "base", shape = "box", size = { 5.0, 0.06, 0.5 }, at = { 0, 1.23, -3.0 }, color = "hazard" },

	{ name = "turret", parent = "base", shape = "box", size = { 3.4, 2.8, 3.6 }, at = { 0, 12.4, 0.8 }, pivot = { 0, 10.8, 0.3 }, color = "hull" },
	{ name = "headTop", parent = "turret", shape = "wedge", size = { 3.4, 1.0, 1.6 }, at = { 0, 14.3, -0.2 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.2, 0.08, 1.6 }, at = { 0, 13.84, 1.6 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.5, 0.4, 0.3 }, at = { 1.3, 13.4, -1.0 }, color = "glass" },

	{ name = "mount", parent = "turret", shape = "box", size = { 2.2, 2.2, 0.8 }, at = { 0, CY, CZ + 1.0 }, pivot = { 0, CY, CZ + 1.2 }, color = "dark" },
	{ name = "drum", parent = "mount", shape = "cylinder", axis = "z", size = { 2.8, 2.8, 1.2 }, at = { 0, CY, CZ }, pivot = { 0, CY, CZ }, color = "metal" },
	{ name = "drumRing", parent = "drum", shape = "cylinder", axis = "z", size = { 2.6, 2.6, 0.3 }, at = { 0, CY, CZ - 3.0 }, color = "dark" },
}
for k = 1, 3 do
	table.insert(parts, { name = `barrel{k}`, parent = "drum", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 5.0 }, at = at(k, CZ - 3.1), pivot = at(k, CZ - 0.6), color = "metal" })
	table.insert(parts, { name = `lens{k}`, parent = `barrel{k}`, shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.2 }, at = at(k, CZ - 5.65), color = "glass" })
end

return {
	id = "chs_geryon",
	visualPieces = { "barrel1", "barrel2", "barrel3" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = at(1, CZ - 5.8) },
		{ name = "muzzle2", parent = "barrel2", at = at(2, CZ - 5.8) },
		{ name = "muzzle3", parent = "barrel3", at = at(3, CZ - 5.8) },
	},
}

--!strict
-- Geryon (Chaos triple laser tower, T1, footprint 2; S-157; the user's
-- reference 2026-10-24: a tall column with a heavy head of three long
-- barrels; F18 2026-10-26: "turret should stand high, proud, tower above
-- others", so taller and heavier like its counterpart the Overwatch, top
-- ~20 studs): a square armored footing, a tall slab column with team panels
-- down its faces, and on top the `turret`, an angular head; in front of it
-- the `drum`, a rotary cluster of three long green laser barrels in a
-- triangle about the drum's forward axis. Only the top barrel fires; the
-- client turns the drum 120 degrees per shot (`muzzle1` the top one at
-- rest). Each barrel is a client piece (`barrel1..3`) for its own recoil.
-- The drum hangs from `mount`, which the def pitches -60..+60 degrees.
-- Model space, forward = -Z.

local RING = 14.8 -- top of the column, where the head turns
local CY, CZ, R = RING + 2.0, -1.8, 1.15 -- the drum's axis (height, depth) and the barrels' distance from it
local CH = RING - 3.8 -- column height

local function at(k: number, z: number): { number }
	local a = math.rad(90 + (k - 1) * 120) -- barrel1 on top, then round
	return { R * math.cos(a), CY + R * math.sin(a), z }
end

local parts = {
	{ name = "base", shape = "box", size = { 9.6, 1.2, 9.6 }, at = { 0, 0.6, 0 }, color = "dark" },
	{ name = "footing", parent = "base", shape = "box", size = { 6.6, 2.6, 6.6 }, at = { 0, 2.5, 0 }, color = "metal" },
	{ name = "column", parent = "base", shape = "box", size = { 4.2, CH, 3.8 }, at = { 0, 3.8 + CH / 2, 0.3 }, color = "hull" },
	{ name = "colTeamF", parent = "base", shape = "box", size = { 1.2, CH - 1.6, 0.08 }, at = { -1.1, 3.8 + CH / 2, -1.64 }, color = "team" },
	{ name = "colTeamF2", parent = "base", shape = "box", size = { 1.2, CH - 1.6, 0.08 }, at = { 1.1, 3.8 + CH / 2, -1.64 }, color = "team" },
	{ name = "colTeamL", parent = "base", shape = "box", size = { 0.08, CH - 1.6, 2.0 }, at = { -2.14, 3.8 + CH / 2, 0.3 }, color = "team" },
	{ name = "colTeamR", parent = "base", shape = "box", size = { 0.08, CH - 1.6, 2.0 }, at = { 2.14, 3.8 + CH / 2, 0.3 }, color = "team" },
	{ name = "collar", parent = "base", shape = "box", size = { 4.8, 0.6, 4.4 }, at = { 0, RING - 0.3, 0.3 }, color = "dark" },
	{ name = "hazard", parent = "base", shape = "box", size = { 6.6, 0.06, 0.6 }, at = { 0, 1.23, -4.2 }, color = "hazard" },

	{ name = "turret", parent = "base", shape = "box", size = { 4.4, 3.6, 4.6 }, at = { 0, RING + 1.8, 0.8 }, pivot = { 0, RING, 0.3 }, color = "hull" },
	{ name = "headTop", parent = "turret", shape = "wedge", size = { 4.4, 1.2, 2.0 }, at = { 0, RING + 4.2, -0.5 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.8, 0.08, 2.0 }, at = { 0, RING + 3.64, 2.0 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.7, 0.5, 0.3 }, at = { 1.7, RING + 2.9, -1.55 }, color = "glass" },

	{ name = "mount", parent = "turret", shape = "box", size = { 2.8, 2.8, 1.0 }, at = { 0, CY, CZ + 1.3 }, pivot = { 0, CY, CZ + 1.5 }, color = "dark" },
	{ name = "drum", parent = "mount", shape = "cylinder", axis = "z", size = { 3.6, 3.6, 1.5 }, at = { 0, CY, CZ }, pivot = { 0, CY, CZ }, color = "metal" },
	{ name = "drumRing", parent = "drum", shape = "cylinder", axis = "z", size = { 3.3, 3.3, 0.4 }, at = { 0, CY, CZ - 3.8 }, color = "dark" },
}
for k = 1, 3 do
	table.insert(parts, { name = `barrel{k}`, parent = "drum", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 6.4 }, at = at(k, CZ - 3.9), pivot = at(k, CZ - 0.7), color = "metal" })
	table.insert(parts, { name = `lens{k}`, parent = `barrel{k}`, shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.25 }, at = at(k, CZ - 7.2), color = "glass" })
end

return {
	id = "chs_geryon",
	visualPieces = { "barrel1", "barrel2", "barrel3" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = at(1, CZ - 7.4) },
		{ name = "muzzle2", parent = "barrel2", at = at(2, CZ - 7.4) },
		{ name = "muzzle3", parent = "barrel3", at = at(3, CZ - 7.4) },
	},
}

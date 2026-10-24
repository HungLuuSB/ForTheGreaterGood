--!strict
-- Geryon (Chaos triple laser tower, T1, footprint 2; S-157): a round pad
-- with reactive blocks, a heavy post, a rounded `turret` and in front of it
-- the `drum`: a rotary cluster of three green laser barrels in a triangle
-- about the drum's forward axis. Only the top barrel fires; the client turns
-- the drum 120 degrees after each shot so the next comes up (`muzzle1` is the
-- top one at rest). Each barrel is a client piece (`barrel1..3`) for its own
-- recoil. Model space, forward = -Z.

local CY, CZ, R = 4.6, -1.8, 0.75 -- the drum's axis (height, depth) and the barrels' distance from it

local function at(k: number, z: number): { number }
	local a = math.rad(90 + (k - 1) * 120) -- barrel1 on top, then round
	return { R * math.cos(a), CY + R * math.sin(a), z }
end

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 11.6, 1.0, 11.6 }, at = { 0, 0.5, 0 }, color = "dark" },
	{ name = "teamA", parent = "base", shape = "box", size = { 2.8, 0.08, 2.0 }, at = { 0, 1.04, 3.8 }, color = "team" },
	{ name = "eraA", parent = "base", shape = "box", size = { 2.4, 1.0, 0.5 }, at = { -2.2, 1.4, -4.0 }, rot = { 0, 25, 0 }, color = "metal" },
	{ name = "eraB", parent = "base", shape = "box", size = { 2.4, 1.0, 0.5 }, at = { 2.2, 1.4, -4.0 }, rot = { 0, -25, 0 }, color = "metal" },
	{ name = "hazard", parent = "base", shape = "box", size = { 4.0, 0.06, 0.5 }, at = { 0, 1.03, -5.0 }, color = "hazard" },
	{ name = "post", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 2.6, 3.4 }, at = { 0, 2.3, 0.4 }, color = "hull" },

	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 2.0, 4.4 }, at = { 0, 4.6, 0.8 }, pivot = { 0, 3.6, 0.4 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.0 }, at = { 0, 5.64, 1.2 }, color = "team" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.6, 0.4, 0.4 }, at = { 1.6, 5.3, -1.0 }, color = "glass" },

	{ name = "drum", parent = "turret", shape = "cylinder", axis = "z", size = { 2.6, 2.6, 1.0 }, at = { 0, CY, CZ }, pivot = { 0, CY, CZ }, color = "metal" },
	{ name = "drumRing", parent = "drum", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 0.3 }, at = { 0, CY, CZ - 2.4 }, color = "dark" },
}
for k = 1, 3 do
	table.insert(parts, { name = `barrel{k}`, parent = "drum", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 3.6 }, at = at(k, CZ - 2.2), pivot = at(k, CZ - 0.5), color = "metal" })
	table.insert(parts, { name = `lens{k}`, parent = `barrel{k}`, shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.2 }, at = at(k, CZ - 4.05), color = "glass" })
end

return {
	id = "chs_geryon",
	visualPieces = { "barrel1", "barrel2", "barrel3" },
	parts = parts,
	attachments = {
		{ name = "muzzle1", parent = "barrel1", at = at(1, CZ - 4.2) },
		{ name = "muzzle2", parent = "barrel2", at = at(2, CZ - 4.2) },
		{ name = "muzzle3", parent = "barrel3", at = at(3, CZ - 4.2) },
	},
}

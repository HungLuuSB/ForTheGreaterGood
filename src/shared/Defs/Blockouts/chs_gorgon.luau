--!strict
-- Gorgon (Chaos mobile radar SAM, T2, footprint 1): a light 6 × 6 truck with
-- an open cab cage; at the back the `launcher`: open rails carrying two big
-- bare missiles raised 40°; behind the cab the `turret`: a lattice mast with
-- a flat radar panel (not turned by the weapon; the def turns `launcher`).
-- Chaos reads light (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.2, 0.9, 7.4 }, at = { 0, 1.75, 0.1 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 3.8, 1.1, 1.6 }, at = { 0, 2.75, -2.8 }, color = "hull" },
	{ name = "cabSlit", parent = "base", shape = "box", size = { 3.0, 0.2, 0.08 }, at = { 0, 2.95, -3.64 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 2.8, 0.08, 1.0 }, at = { 0, 3.34, -2.8 }, color = "team" },
	{ name = "cabCage", parent = "base", shape = "box", size = { 4.0, 0.12, 0.12 }, at = { 0, 3.5, -3.7 }, color = "dark" },

	{ name = "turret", parent = "base", shape = "box", size = { 0.3, 3.2, 0.3 }, at = { -1.4, 3.8, -1.2 }, color = "dark" },
	{ name = "mastBrace", parent = "turret", shape = "box", size = { 0.15, 2.8, 0.15 }, at = { -1.0, 3.6, -1.0 }, rot = { 0, 0, -12 }, color = "dark" },
	{ name = "panel", parent = "turret", shape = "box", size = { 2.2, 1.4, 0.2 }, at = { -1.4, 5.7, -1.2 }, rot = { -15, 0, 0 }, color = "dark" },
	{ name = "panelGlow", parent = "turret", shape = "box", size = { 1.8, 0.2, 0.06 }, at = { -1.4, 5.7, -1.33 }, rot = { -15, 0, 0 }, color = "glass" },

	{ name = "launcher", parent = "base", shape = "box", size = { 2.8, 0.3, 2.6 }, at = { 0.3, 2.35, 2.2 }, pivot = { 0.3, 2.2, 2.2 }, color = "dark" },
}
for i, x in { -0.5, 1.1 } do
	table.insert(parts, { name = `rail{i}`, parent = "launcher", shape = "box", size = { 0.2, 0.2, 4.4 }, at = { x, 3.6, 1.6 }, rot = { 40, 0, 0 }, color = "dark" })
	table.insert(parts, { name = `missile{i}`, parent = "launcher", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 4.2 }, at = { x, 3.95, 1.5 }, rot = { 40, 0, 0 }, color = "metal" })
	table.insert(parts, { name = `tip{i}`, parent = "launcher", shape = "ball", size = { 0.65, 0.65, 0.65 }, at = { x, 5.3, -0.1 }, color = "team" })
end
for i, z in { -2.6, 0.6, 2.6 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.6, 1.6 }, at = { -2.1, 0.8, z }, color = "track" })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.6, 1.6 }, at = { 2.1, 0.8, z }, color = "track" })
end

return {
	id = "chs_gorgon",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0.3, 5.4, -0.3 } },
	},
}

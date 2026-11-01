--!strict
-- Martyr (Order amphibious rolling bomb, T2): no legs; a ball shell
-- (`shell`, a client piece that rolls) with a team band, hazard stripes and
-- glowing seams over a small sealed chassis. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.2, 0.5, 1.2 }, at = { 0, 0.4, 0 }, color = "dark" },
}
local visual: { string } = {}
table.insert(visual, "shell")
for _, p in {
	{ name = "shell", parent = "base", shape = "ball", size = { 2.6, 2.6, 2.6 }, at = { 0, 1.35, 0 }, pivot = { 0, 1.35, 0 }, color = "hull", anim = { motion = "spin", axis = { 1, 0, 0 } } },
	{ name = "band", parent = "shell", shape = "cylinder", axis = "x", size = { 0.5, 2.72, 2.72 }, at = { 0, 1.35, 0 }, color = "team" },
	{ name = "hazardL", parent = "shell", shape = "cylinder", axis = "x", size = { 0.15, 2.2, 2.2 }, at = { -0.85, 1.35, 0 }, color = "hazard" },
	{ name = "capL", parent = "shell", shape = "cylinder", axis = "x", size = { 0.12, 0.8, 0.8 }, at = { -1.3, 1.35, 0 }, color = "glass" },
	{ name = "hazardR", parent = "shell", shape = "cylinder", axis = "x", size = { 0.15, 2.2, 2.2 }, at = { 0.85, 1.35, 0 }, color = "hazard" },
	{ name = "capR", parent = "shell", shape = "cylinder", axis = "x", size = { 0.12, 0.8, 0.8 }, at = { 1.3, 1.35, 0 }, color = "glass" },
	{ name = "torso", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 0, 1.35, 0 }, pivot = { 0, 1.35, 0 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_martyr",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 1.35, -1.4 } },
	},
}

--!strict
-- Marshal (Order skirmisher bot, gauss guns, T2): tall and lean, both forearms
-- long gauss rails with glowing coils (`muzzle`, `muzzle2`). Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.7, 0.8, 1.4 }, at = { 0, 3.2, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 3, hipX = 0.7, thick = 0.55, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2, 1.6, 1.6 }, at = { 0, 4.4, 0 }, pivot = { 0, 3.6, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.5, 0.8 }, at = { 0, 5.45, -0.2 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.6, 0.14, 0.08 }, at = { 0, 5.475, -0.63 }, color = "glass" },
	{ name = "chest", parent = "torso", shape = "wedge", size = { 1.6, 0.9, 0.5 }, at = { 0, 4.6, -1 }, color = "team" },
	{ name = "armR", parent = "torso", shape = "box", size = { 0.55, 1.1, 0.6 }, at = { 1.35, 4.35, 0 }, color = "metal" },
	{ name = "railR", parent = "torso", shape = "box", size = { 0.5, 0.45, 3 }, at = { 1.35, 3.8, -1.2 }, color = "hull" },
	{ name = "coilR1", parent = "torso", shape = "box", size = { 0.62, 0.57, 0.15 }, at = { 1.35, 3.8, -0.6 }, color = "glass" },
	{ name = "coilR2", parent = "torso", shape = "box", size = { 0.62, 0.57, 0.15 }, at = { 1.35, 3.8, -1.5 }, color = "glass" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.55, 1.1, 0.6 }, at = { -1.35, 4.35, 0 }, color = "metal" },
	{ name = "railL", parent = "torso", shape = "box", size = { 0.5, 0.45, 3 }, at = { -1.35, 3.8, -1.2 }, color = "hull" },
	{ name = "coilL1", parent = "torso", shape = "box", size = { 0.62, 0.57, 0.15 }, at = { -1.35, 3.8, -0.6 }, color = "glass" },
	{ name = "coilL2", parent = "torso", shape = "box", size = { 0.62, 0.57, 0.15 }, at = { -1.35, 3.8, -1.5 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_marshal",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.35, 3.8, -2.85 } },
		{ name = "muzzle2", parent = "torso", at = { -1.35, 3.8, -2.85 } },
	},
}

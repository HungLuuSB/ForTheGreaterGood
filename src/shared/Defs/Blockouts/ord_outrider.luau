--!strict
-- Outrider (Order fast raider bot, T2): long legs and a small body leaning
-- forward, a fin on its back and a gun under each side. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.2, 0.8, 1.1 }, at = { 0, 3.1, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.9, hipX = 0.55, thick = 0.45, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.4, 1, 1.9 }, at = { 0, 4, -0.2 }, rot = { -8, 0, 0 }, pivot = { 0, 3.5, 0 }, color = "hull" },
	{ name = "nose", parent = "torso", shape = "wedge", size = { 1.3, 0.8, 0.8 }, at = { 0, 4, -1.5 }, color = "team" },
	{ name = "eye", parent = "torso", shape = "box", size = { 0.8, 0.12, 0.06 }, at = { 0, 4.25, -1.1 }, color = "glass" },
	{ name = "fin", parent = "torso", shape = "wedge", size = { 0.12, 0.8, 1.2 }, at = { 0, 4.9, 0.4 }, color = "team" },
	{ name = "gunR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.2 }, at = { 0.85, 3.75, -1.2 }, color = "metal" },
	{ name = "gunRTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.312, 0.312, 0.2 }, at = { 0.85, 3.75, -1.85 }, color = "glass" },
	{ name = "gunL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 1.2 }, at = { -0.85, 3.75, -1.2 }, color = "metal" },
	{ name = "gunLTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.312, 0.312, 0.2 }, at = { -0.85, 3.75, -1.85 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_outrider",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0.85, 3.75, -1.95 } },
		{ name = "muzzle2", parent = "torso", at = { -0.85, 3.75, -1.95 } },
	},
}

--!strict
-- Steward (Order fast assist and repair bot, T2): light and long-legged, a
-- small body with a crane arm (`nano`) arching from its back over the head. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.3, 0.8, 1.1 }, at = { 0, 2.9, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.7, hipX = 0.55, thick = 0.42, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.5, 1.2, 1.3 }, at = { 0, 3.9, 0 }, pivot = { 0, 3.3, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.7, 0.45, 0.7 }, at = { 0, 4.725, -0.2 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.525, 0.126, 0.08 }, at = { 0, 4.747, -0.58 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.8, 0.4, 0.08 }, at = { 0, 3.95, -0.68 }, color = "team" },
	{ name = "mast", parent = "torso", shape = "box", size = { 0.35, 1.6, 0.35 }, at = { 0.35, 5, 0.6 }, color = "metal" },
	{ name = "nano", parent = "torso", shape = "box", size = { 0.45, 0.45, 2.4 }, at = { 0.35, 5.5, -0.6 }, rot = { 14.325, 0, 0 }, pivot = { 0.35, 5.8, 0.6 }, color = "metal" },
	{ name = "nanoHead", parent = "nano", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.45 }, at = { 0.35, 5.2, -1.8 }, color = "team" },
	{ name = "nanoGlow", parent = "nano", shape = "ball", size = { 0.4, 0.4, 0.4 }, at = { 0.35, 5.2, -2.1 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_steward",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0.35, 5.2, -2.3 } },
	},
}

--!strict
-- Draftsman (Order advanced constructor bot, T2): a heavier worker than the
-- Artisan, a broad body with a team backpack and a long jointed construction arm
-- (`nano`) over the right shoulder, a short tool arm on the left. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2, 0.8, 1.6 }, at = { 0, 3, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.8, hipX = 0.85, thick = 0.65, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.5, 1.9, 2.1 }, at = { 0, 4.35, 0 }, pivot = { 0, 3.4, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 1, 0.6, 0.9 }, at = { 0, 5.6, -0.4 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.75, 0.168, 0.08 }, at = { 0, 5.63, -0.88 }, color = "glass" },
	{ name = "pack", parent = "torso", shape = "box", size = { 2, 1.6, 0.9 }, at = { 0, 4.4, 1.45 }, color = "team" },
	{ name = "packGlow", parent = "torso", shape = "box", size = { 1.4, 0.15, 0.06 }, at = { 0, 5, 1.92 }, color = "glass" },
	{ name = "mount", parent = "torso", shape = "cylinder", axis = "y", size = { 0.9, 0.5, 0.9 }, at = { 1.3, 5.55, 0.2 }, color = "metal" },
	{ name = "nano", parent = "torso", shape = "box", size = { 0.45, 0.45, 3.2 }, at = { 1.3, 6.1, -1.4 }, rot = { -10.744, 0, 0 }, pivot = { 1.3, 5.8, 0.2 }, color = "metal" },
	{ name = "nanoHead", parent = "nano", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.45 }, at = { 1.3, 6.4, -3 }, color = "team" },
	{ name = "nanoGlow", parent = "nano", shape = "ball", size = { 0.4, 0.4, 0.4 }, at = { 1.3, 6.4, -3.3 }, color = "glass" },
	{ name = "tool", parent = "torso", shape = "box", size = { 0.5, 1.2, 0.5 }, at = { -1.5, 4, -0.3 }, color = "metal" },
	{ name = "toolTip", parent = "torso", shape = "box", size = { 0.6, 0.3, 0.7 }, at = { -1.5, 3.35, -0.6 }, color = "hazard" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_draftsman",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "nano1", parent = "nano", at = { 1.3, 6.4, -3.5 } },
	},
}

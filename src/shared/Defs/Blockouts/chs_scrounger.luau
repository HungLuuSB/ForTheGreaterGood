--!strict
-- Scrounger (Chaos combat engineer bot, T2): wiry and quick, a scrap hopper on
-- its back, a claw arm (`nano`) on the right and a short gun on the left. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 2.6, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.4, hipX = 0.6, thick = 0.5, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.7, 1.3, 1.5 }, at = { 0, 3.65, 0 }, pivot = { 0, 3, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.75, 0.45, 0.7 }, at = { -0.2, 4.52, -0.4 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.55, 0.1, 0.06 }, at = { -0.2, 4.57, -0.77 }, color = "glass" },
	{ name = "hopper", parent = "torso", shape = "wedge", size = { 1.6, 1, 1 }, at = { 0, 4.5, 0.75 }, rot = { 0, 180, 0 }, color = "metal" },
	{ name = "scrap", parent = "torso", shape = "box", size = { 1.2, 0.3, 0.6 }, at = { 0, 4.85, 0.85 }, rot = { 0, 15, 8 }, color = "dark" },
	{ name = "nano", parent = "torso", shape = "box", size = { 0.45, 0.45, 1.6 }, at = { 1.05, 3.6, -0.9 }, pivot = { 1.05, 3.6, -0.1 }, color = "metal" },
	{ name = "nanoClawL", parent = "nano", shape = "wedge", size = { 0.15, 0.5, 0.6 }, at = { 0.85, 3.6, -1.9 }, color = "dark" },
	{ name = "nanoClawR", parent = "nano", shape = "wedge", size = { 0.15, 0.5, 0.6 }, at = { 1.25, 3.6, -1.9 }, color = "dark" },
	{ name = "nanoGlow", parent = "nano", shape = "ball", size = { 0.32, 0.32, 0.32 }, at = { 1.05, 3.6, -1.95 }, color = "glass" },
	{ name = "gun", parent = "torso", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 1 }, at = { -1.05, 3.5, -0.9 }, color = "metal" },
	{ name = "gunTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.35, 0.35, 0.2 }, at = { -1.05, 3.5, -1.45 }, color = "dark" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.6, 0.35, 0.06 }, at = { 0.2, 3.6, -0.78 }, color = "team" },
	{ name = "nano1", parent = "nano", shape = "ball", size = { 0.3, 0.3, 0.3 }, at = { 1.05, 3.6, -2.2 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_scrounger",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { -1.05, 3.5, -1.55 } },
	},
}

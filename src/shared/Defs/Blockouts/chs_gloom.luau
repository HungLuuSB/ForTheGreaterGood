--!strict
-- Gloom (Chaos jammer bot, T2): a hunched little bot bristling with four
-- spiked antenna spines on its back, amber tips, over a jammer dish. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.5, 0.8, 1.2 }, at = { 0, 2.2, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2, hipX = 0.65, thick = 0.55, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.8, 1.2, 1.6 }, at = { 0, 3.2, 0.1 }, pivot = { 0, 2.6, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.45, 0.7 }, at = { 0, 3.5, -0.95 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.6, 0.1, 0.06 }, at = { 0, 3.55, -1.32 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.9, 0.35, 0.08 }, at = { 0, 2.95, -0.73 }, color = "team" },
	{ name = "dish", parent = "torso", shape = "cylinder", axis = "y", size = { 1.4, 0.2, 1.4 }, at = { 0, 3.95, 0.3 }, color = "metal" },
	{ name = "spine1", parent = "torso", shape = "box", size = { 0.15, 2.2, 0.15 }, at = { -0.5, 5.15, 0 }, rot = { 0, 0, -15 }, color = "dark" },
	{ name = "spineTip1", parent = "torso", shape = "ball", size = { 0.25, 0.25, 0.25 }, at = { -0.203, 6.25, 0 }, color = "glass" },
	{ name = "spine2", parent = "torso", shape = "box", size = { 0.15, 2, 0.15 }, at = { 0.5, 5.05, 0 }, rot = { 0, 0, 15 }, color = "dark" },
	{ name = "spineTip2", parent = "torso", shape = "ball", size = { 0.25, 0.25, 0.25 }, at = { 0.23, 6.05, 0 }, color = "glass" },
	{ name = "spine3", parent = "torso", shape = "box", size = { 0.15, 1.6, 0.15 }, at = { -0.3, 4.85, 0.7 }, rot = { 0, 0, -10 }, color = "dark" },
	{ name = "spineTip3", parent = "torso", shape = "ball", size = { 0.25, 0.25, 0.25 }, at = { -0.156, 5.65, 0.7 }, color = "glass" },
	{ name = "spine4", parent = "torso", shape = "box", size = { 0.15, 1.8, 0.15 }, at = { 0.35, 4.95, 0.7 }, rot = { 0, 0, 10 }, color = "dark" },
	{ name = "spineTip4", parent = "torso", shape = "ball", size = { 0.25, 0.25, 0.25 }, at = { 0.188, 5.85, 0.7 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_gloom",
	parts = parts,
	visualPieces = visual,
}

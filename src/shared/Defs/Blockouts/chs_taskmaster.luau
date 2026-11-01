--!strict
-- Taskmaster (Chaos advanced constructor bot, T2): a bulky worker with exhaust
-- stacks, hazard-striped plates and a long crane arm (`nano`) ending in a claw. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.1, 0.8, 1.6 }, at = { 0, 2.8, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.6, hipX = 0.9, thick = 0.75, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 1.8, 2.2 }, at = { 0, 4.1, 0 }, pivot = { 0, 3.2, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.9, 0.55, 0.8 }, at = { -0.6, 5.27, -0.5 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.7, 0.12, 0.08 }, at = { -0.6, 5.32, -0.93 }, color = "glass" },
	{ name = "hazard", parent = "torso", shape = "box", size = { 2.2, 0.3, 0.08 }, at = { 0, 3.6, -1.13 }, color = "hazard" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1, 0.5, 0.08 }, at = { 0.4, 4.3, -1.13 }, color = "team" },
	{ name = "stack1", parent = "torso", shape = "cylinder", axis = "y", size = { 0.35, 1.2, 0.35 }, at = { -0.7, 5.5, 0.9 }, color = "dark" },
	{ name = "stack2", parent = "torso", shape = "cylinder", axis = "y", size = { 0.35, 1.2, 0.35 }, at = { -0.2, 5.5, 0.9 }, color = "dark" },
	{ name = "boom", parent = "torso", shape = "box", size = { 0.7, 0.7, 0.9 }, at = { 1.3, 5.3, 0.4 }, color = "metal" },
	{ name = "nano", parent = "torso", shape = "box", size = { 0.45, 0.45, 3.4 }, at = { 1.3, 5.9, -1.5 }, rot = { -13.482, 0, 0 }, pivot = { 1.3, 5.5, 0.2 }, color = "metal" },
	{ name = "nanoClawL", parent = "nano", shape = "wedge", size = { 0.15, 0.5, 0.6 }, at = { 1.1, 6.3, -3.4 }, color = "dark" },
	{ name = "nanoClawR", parent = "nano", shape = "wedge", size = { 0.15, 0.5, 0.6 }, at = { 1.5, 6.3, -3.4 }, color = "dark" },
	{ name = "nanoGlow", parent = "nano", shape = "ball", size = { 0.32, 0.32, 0.32 }, at = { 1.3, 6.3, -3.45 }, color = "glass" },
	{ name = "nano1", parent = "nano", shape = "ball", size = { 0.3, 0.3, 0.3 }, at = { 1.3, 6.3, -3.7 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_taskmaster",
	parts = parts,
	visualPieces = visual,
}

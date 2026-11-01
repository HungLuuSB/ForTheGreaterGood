--!strict
-- Firebrand (Chaos rocket bot, T1): a hunched bot with an open rail rack over
-- its right shoulder, rockets tipped amber, spikes on the left pad. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2, 0.8, 1.5 }, at = { 0, 2.5, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.3, hipX = 0.8, thick = 0.65, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.2, 1.5, 1.8 }, at = { 0, 3.65, 0.1 }, pivot = { 0, 2.9, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.9, 0.5, 0.08 }, at = { -0.3, 3.6, -0.83 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.5, 0.8 }, at = { -0.35, 4.5, -0.5 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.6, 0.12, 0.08 }, at = { -0.35, 4.55, -0.93 }, color = "glass" },
	{ name = "rack", parent = "torso", shape = "box", size = { 1.3, 0.25, 2.2 }, at = { 1.4, 4.75, 0.1 }, rot = { -12, 0, 0 }, color = "metal" },
	{ name = "rocket1", parent = "torso", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 1.8 }, at = { 1, 5, 0 }, rot = { -12, 0, 0 }, color = "dark" },
	{ name = "rocketTip1", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.15 }, at = { 1, 5.19, -0.9 }, rot = { -12, 0, 0 }, color = "glass" },
	{ name = "rocket2", parent = "torso", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 1.8 }, at = { 1.4, 5, 0 }, rot = { -12, 0, 0 }, color = "dark" },
	{ name = "rocketTip2", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.15 }, at = { 1.4, 5.19, -0.9 }, rot = { -12, 0, 0 }, color = "glass" },
	{ name = "rocket3", parent = "torso", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 1.8 }, at = { 1.8, 5, 0 }, rot = { -12, 0, 0 }, color = "dark" },
	{ name = "rocketTip3", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.15 }, at = { 1.8, 5.19, -0.9 }, rot = { -12, 0, 0 }, color = "glass" },
	{ name = "padL", parent = "torso", shape = "wedge", size = { 1, 0.7, 1.8 }, at = { -1.45, 4.3, 0 }, rot = { 0, 90, 0 }, color = "metal" },
	{ name = "spike1", parent = "torso", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { -1.65, 5, 0.2 }, color = "metal" },
	{ name = "spike2", parent = "torso", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { -1.25, 5, 0.2 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_firebrand",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.4, 5.2, -1.05 } },
	},
}

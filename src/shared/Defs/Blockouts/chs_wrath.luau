--!strict
-- Wrath (Chaos heavy rocket artillery bot, T2): a squat bot hauling a big
-- launcher box on its back (`launcher`, pitches up) with nine amber tubes. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.1, 0.8, 1.6 }, at = { 0, 2.7, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.5, hipX = 0.9, thick = 0.75, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.4, 1.5, 2 }, at = { 0, 3.85, 0 }, pivot = { 0, 3.1, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.9, 0.5, 0.8 }, at = { 0, 4.1, -1.3 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.7, 0.12, 0.08 }, at = { 0, 4.15, -1.73 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.2, 0.4, 0.08 }, at = { 0, 3.5, -1.03 }, color = "team" },
	{ name = "launcher", parent = "torso", shape = "box", size = { 2.6, 1.6, 2.2 }, at = { 0, 5.5, 0.3 }, rot = { -20, 0, 0 }, pivot = { 0, 4.6, 0.8 }, color = "hull" },
	{ name = "frame", parent = "torso", shape = "box", size = { 2.8, 0.2, 2.4 }, at = { 0, 4.65, 0.4 }, color = "metal" },
	{ name = "tube11", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { -0.75, 5.3, -0.84 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube12", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { -0.75, 5.75, -0.68 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube13", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { -0.75, 6.2, -0.52 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube21", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { 0, 5.3, -0.84 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube22", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { 0, 5.75, -0.68 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube23", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { 0, 6.2, -0.52 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube31", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { 0.75, 5.3, -0.84 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube32", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { 0.75, 5.75, -0.68 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "tube33", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.12 }, at = { 0.75, 6.2, -0.52 }, rot = { -20, 0, 0 }, color = "glass" },
	{ name = "spike1", parent = "launcher", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { -1.15, 6.7, 0.6 }, color = "metal" },
	{ name = "spike2", parent = "launcher", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { 1.15, 6.7, 0.6 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_wrath",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 5.8, -0.95 } },
	},
}

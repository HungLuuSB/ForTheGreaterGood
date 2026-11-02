--!strict
-- Gargoyle (Chaos heavy amphibious anti-air bot, T2): big and hunched on thick
-- legs, two tall missile racks on the shoulders like folded wings (`launcher`,
-- pitches), horns, amber cells. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.3, 0.8, 1.8 }, at = { 0, 2.8, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.6, hipX = 1, thick = 0.8, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.8, 1.8, 2.4 }, at = { 0, 4.1, 0.1 }, pivot = { 0, 3.2, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 1, 0.6, 0.9 }, at = { 0, 4.5, -1.4 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.8, 0.12, 0.06 }, at = { 0, 4.55, -1.87 }, color = "glass" },
	{ name = "spike1", parent = "torso", shape = "wedge", size = { 0.2, 0.6, 0.5 }, at = { -0.45, 5.1, -1.3 }, color = "metal" },
	{ name = "spike2", parent = "torso", shape = "wedge", size = { 0.2, 0.6, 0.5 }, at = { 0.45, 5.1, -1.3 }, color = "metal" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.4, 0.5, 0.08 }, at = { 0, 3.7, -1.13 }, color = "team" },
	{ name = "launcher", parent = "torso", shape = "box", size = { 0.8, 0.4, 0.8 }, at = { 0, 5.2, 0.4 }, pivot = { 0, 5.2, 0.4 }, color = "metal" },
	{ name = "rackL", parent = "launcher", shape = "wedge", size = { 1.1, 2.4, 1.6 }, at = { -1.75, 6, 0.4 }, color = "hull" },
	{ name = "cellL11", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -1.96, 5.18, -0.45 }, color = "glass" },
	{ name = "cellL12", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -1.96, 5.6, -0.45 }, color = "glass" },
	{ name = "cellL13", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -1.96, 6.02, -0.45 }, color = "glass" },
	{ name = "cellL21", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -1.54, 5.18, -0.45 }, color = "glass" },
	{ name = "cellL22", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -1.54, 5.6, -0.45 }, color = "glass" },
	{ name = "cellL23", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -1.54, 6.02, -0.45 }, color = "glass" },
	{ name = "rackR", parent = "launcher", shape = "wedge", size = { 1.1, 2.4, 1.6 }, at = { 1.75, 6, 0.4 }, color = "hull" },
	{ name = "cellR11", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 1.54, 5.18, -0.45 }, color = "glass" },
	{ name = "cellR12", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 1.54, 5.6, -0.45 }, color = "glass" },
	{ name = "cellR13", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 1.54, 6.02, -0.45 }, color = "glass" },
	{ name = "cellR21", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 1.96, 5.18, -0.45 }, color = "glass" },
	{ name = "cellR22", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 1.96, 5.6, -0.45 }, color = "glass" },
	{ name = "cellR23", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 1.96, 6.02, -0.45 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_gargoyle",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 1.75, 6, -0.65 } },
	},
}

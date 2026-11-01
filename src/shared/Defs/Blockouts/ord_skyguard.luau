--!strict
-- Skyguard (Order amphibious anti-air bot, T2): a rounded, sealed body with float
-- collars at the hips and two missile pods on the shoulders that pitch up
-- together (`launcher`), cells glowing on their faces. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2, 0.8, 1.6 }, at = { 0, 2.8, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.6, hipX = 0.8, thick = 0.65, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.2, 1.7, 2 }, at = { 0, 4.05, 0 }, pivot = { 0, 3.2, 0 }, color = "hull" },
	{ name = "dome", parent = "torso", shape = "ball", size = { 2, 1.2, 1.8 }, at = { 0, 4.8, 0 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 1.2, 0.25, 0.08 }, at = { 0, 4.45, -1.03 }, color = "glass" },
	{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 1.8 }, at = { -1.45, 2.9, 0 }, color = "team" },
	{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 1.8 }, at = { 1.45, 2.9, 0 }, color = "team" },
	{ name = "launcher", parent = "torso", shape = "box", size = { 0.6, 0.4, 0.6 }, at = { 0, 5.1, 0.2 }, pivot = { 0, 5.1, 0.2 }, color = "metal" },
	{ name = "podL", parent = "launcher", shape = "box", size = { 0.9, 1, 1.6 }, at = { -1.6, 5.1, 0 }, color = "hull" },
	{ name = "podTeamL", parent = "launcher", shape = "box", size = { 0.06, 0.6, 1.2 }, at = { -2.07, 5.1, 0 }, color = "team" },
	{ name = "cellL11", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { -1.8, 4.9, -0.82 }, color = "glass" },
	{ name = "cellL12", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { -1.8, 5.3, -0.82 }, color = "glass" },
	{ name = "cellL21", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { -1.4, 4.9, -0.82 }, color = "glass" },
	{ name = "cellL22", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { -1.4, 5.3, -0.82 }, color = "glass" },
	{ name = "podR", parent = "launcher", shape = "box", size = { 0.9, 1, 1.6 }, at = { 1.6, 5.1, 0 }, color = "hull" },
	{ name = "podTeamR", parent = "launcher", shape = "box", size = { 0.06, 0.6, 1.2 }, at = { 2.07, 5.1, 0 }, color = "team" },
	{ name = "cellR11", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { 1.4, 4.9, -0.82 }, color = "glass" },
	{ name = "cellR12", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { 1.4, 5.3, -0.82 }, color = "glass" },
	{ name = "cellR21", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { 1.8, 4.9, -0.82 }, color = "glass" },
	{ name = "cellR22", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 0.12 }, at = { 1.8, 5.3, -0.82 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_skyguard",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 1.6, 5.1, -1 } },
	},
}

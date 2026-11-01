--!strict
-- Newt (Chaos amphibious bot, laser and torpedo, T2): squat and frog-wide on
-- short legs, float pods on its flanks, bulging amber eyes, a laser on top
-- (`muzzle`) and a torpedo tube under the chin (`muzzle2`). Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.2, 0.8, 1.6 }, at = { 0, 2, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 1.8, hipX = 1, thick = 0.7, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 1.2, 2.4 }, at = { 0, 3, 0 }, pivot = { 0, 2.4, 0 }, color = "hull" },
	{ name = "jaw", parent = "torso", shape = "wedge", size = { 2.4, 0.8, 0.8 }, at = { 0, 2.8, -1.55 }, color = "hull" },
	{ name = "podL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 2.2 }, at = { -1.6, 2.85, 0.1 }, color = "dark" },
	{ name = "eyeL", parent = "torso", shape = "ball", size = { 0.45, 0.45, 0.45 }, at = { -0.7, 3.7, -1 }, color = "glass" },
	{ name = "podR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 2.2 }, at = { 1.6, 2.85, 0.1 }, color = "dark" },
	{ name = "eyeR", parent = "torso", shape = "ball", size = { 0.45, 0.45, 0.45 }, at = { 0.7, 3.7, -1 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.2, 0.08, 0.8 }, at = { 0, 3.64, 0.4 }, color = "team" },
	{ name = "laserMount", parent = "torso", shape = "box", size = { 0.6, 0.4, 0.8 }, at = { 0, 3.8, -0.1 }, color = "metal" },
	{ name = "laser", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { 0, 3.85, -1.1 }, color = "metal" },
	{ name = "laserTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.375, 0.375, 0.2 }, at = { 0, 3.85, -1.75 }, color = "glass" },
	{ name = "torpedo", parent = "torso", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 1.4 }, at = { 0, 2.5, -1.4 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_newt",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 3.85, -1.85 } },
		{ name = "muzzle2", parent = "torso", at = { 0, 2.5, -2.15 } },
	},
}

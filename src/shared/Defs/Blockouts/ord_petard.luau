--!strict
-- Petard (Order rocket bot, T1): an upright bot carrying a square rocket pod on
-- its right shoulder, four tubes facing forward, a sensor head on the left. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.7, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.5, hipX = 0.7, thick = 0.55, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2, 1.6, 1.7 }, at = { 0, 3.9, 0 }, pivot = { 0, 3.1, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.9, 0.5, 0.08 }, at = { -0.3, 4, -0.88 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.55, 0.8 }, at = { 0, 4.975, -0.1 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.6, 0.154, 0.08 }, at = { 0, 5.003, -0.53 }, color = "glass" },
	{ name = "pod", parent = "torso", shape = "box", size = { 1.4, 1.3, 1.8 }, at = { 1.5, 4.9, 0.1 }, color = "team" },
	{ name = "podFace", parent = "torso", shape = "box", size = { 1.2, 1.1, 0.1 }, at = { 1.5, 4.9, -0.82 }, color = "dark" },
	{ name = "tube11", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.25, 4.65, -0.9 }, color = "glass" },
	{ name = "tube12", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.25, 5.15, -0.9 }, color = "glass" },
	{ name = "tube21", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.75, 4.65, -0.9 }, color = "glass" },
	{ name = "tube22", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.75, 5.15, -0.9 }, color = "glass" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.45, 1.1, 0.5 }, at = { -1.25, 3.8, 0 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_petard",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.5, 4.9, -1.05 } },
	},
}

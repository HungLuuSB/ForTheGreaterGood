--!strict
-- Mariner (Order amphibious bot, light laser, T2): a rounded hull-like body with
-- a raked bow, team float tanks on its flanks, a snorkel and a small laser on top. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.5 }, at = { 0, 2.5, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.3, hipX = 0.75, thick = 0.6, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2, 1.4, 2 }, at = { 0, 3.6, 0 }, pivot = { 0, 2.9, 0 }, color = "hull" },
	{ name = "bow", parent = "torso", shape = "wedge", size = { 2, 1.4, 0.8 }, at = { 0, 3.6, -1.4 }, color = "hull" },
	{ name = "tankL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2 }, at = { -1.3, 3.5, 0.1 }, color = "team" },
	{ name = "tankR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 2 }, at = { 1.3, 3.5, 0.1 }, color = "team" },
	{ name = "snorkel", parent = "torso", shape = "cylinder", axis = "y", size = { 0.25, 1.3, 0.25 }, at = { -0.6, 4.9, 0.7 }, color = "metal" },
	{ name = "laserMount", parent = "torso", shape = "box", size = { 0.6, 0.45, 0.7 }, at = { 0.3, 4.52, -0.2 }, color = "metal" },
	{ name = "laser", parent = "torso", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 1 }, at = { 0.3, 4.55, -1.05 }, color = "metal" },
	{ name = "laserTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.35, 0.35, 0.2 }, at = { 0.3, 4.55, -1.6 }, color = "glass" },
	{ name = "visor", parent = "torso", shape = "box", size = { 1.2, 0.2, 0.08 }, at = { 0, 3.9, -1.45 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_mariner",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0.3, 4.55, -1.7 } },
	},
}

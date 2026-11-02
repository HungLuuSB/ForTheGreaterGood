--!strict
-- Ravener (Chaos heavy all-terrain spider, heat ray, T2): a heavy armoured body
-- on four thick jointed legs with high knees and claws, a turret (`torso`) with
-- a heat-ray projector and an amber lens. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.2, 1, 2.8 }, at = { 0, 2.2, 0 }, color = "dark" },
}
local visual = Bots.spider(parts, { legs = 4, hipR = 1, hipY = 2.2, kneeR = 2.8, kneeY = 3.8, footR = 3.8, thick = 0.42, color = "hull" })
for _, p in {
	{ name = "plate", parent = "base", shape = "wedge", size = { 2, 0.7, 0.8 }, at = { 0, 2.2, -1.75 }, color = "hull" },
	{ name = "backSpike1", parent = "base", shape = "wedge", size = { 0.3, 0.6, 0.5 }, at = { -0.7, 3, 1.1 }, color = "metal" },
	{ name = "backSpike2", parent = "base", shape = "wedge", size = { 0.3, 0.6, 0.5 }, at = { 0, 3, 1.1 }, color = "metal" },
	{ name = "backSpike3", parent = "base", shape = "wedge", size = { 0.3, 0.6, 0.5 }, at = { 0.7, 3, 1.1 }, color = "metal" },
	{ name = "torso", parent = "base", shape = "box", size = { 1.7, 0.9, 1.8 }, at = { 0, 3.15, -0.1 }, pivot = { 0, 2.7, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.1, 0.08, 0.8 }, at = { 0, 3.62, 0.2 }, color = "team" },
	{ name = "projector", parent = "torso", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 1.4 }, at = { 0, 3.15, -1.5 }, color = "metal" },
	{ name = "lens", parent = "torso", shape = "cylinder", axis = "z", size = { 0.95, 0.95, 0.15 }, at = { 0, 3.15, -2.25 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_ravener",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 3.15, -2.4 } },
	},
}

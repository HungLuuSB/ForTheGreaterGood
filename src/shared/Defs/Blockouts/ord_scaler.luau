--!strict
-- Scaler (Order all-terrain rocket spider, T2): a flat armoured body on six
-- long jointed legs with high knees and claw tips, a rocket box on its back
-- (`torso`) with six tubes. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.9, 2.6 }, at = { 0, 2.2, 0 }, color = "hull" },
}
local visual = Bots.spider(parts, { legs = 6, hipR = 0.9, hipY = 2.2, kneeR = 2.3, kneeY = 3.7, footR = 3.4, thick = 0.3, color = "hull", team = true })
for _, p in {
	{ name = "plate", parent = "base", shape = "wedge", size = { 1.8, 0.6, 0.8 }, at = { 0, 2.2, -1.65 }, color = "hull" },
	{ name = "torso", parent = "base", shape = "box", size = { 1.6, 0.9, 1.6 }, at = { 0, 3.15, 0.1 }, pivot = { 0, 2.7, 0.1 }, color = "team" },
	{ name = "rackFace", parent = "torso", shape = "box", size = { 1.4, 0.7, 0.1 }, at = { 0, 3.15, -0.75 }, color = "dark" },
	{ name = "tube11", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -0.42, 2.94, -0.82 }, color = "glass" },
	{ name = "tube12", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { -0.42, 3.36, -0.82 }, color = "glass" },
	{ name = "tube21", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 0, 2.94, -0.82 }, color = "glass" },
	{ name = "tube22", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 0, 3.36, -0.82 }, color = "glass" },
	{ name = "tube31", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 0.42, 2.94, -0.82 }, color = "glass" },
	{ name = "tube32", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.12 }, at = { 0.42, 3.36, -0.82 }, color = "glass" },
	{ name = "eye", parent = "base", shape = "box", size = { 0.8, 0.15, 0.08 }, at = { 0, 2.35, -2.05 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_scaler",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 3.15, -0.95 } },
	},
}

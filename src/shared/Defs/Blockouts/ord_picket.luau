--!strict
-- Picket (Order anti-swarm bot, T1): a stocky upright bot with a broad chest
-- plate and big shoulder pads; both forearms end in close-range laser
-- emitters (`muzzle`, `muzzle2`). Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2, 0.8, 1.5 }, at = { 0, 2.7, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.5, hipX = 0.85, thick = 0.65, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 1.8, 2 }, at = { 0, 4, 0 }, pivot = { 0, 3.1, 0 }, color = "hull" },
	{ name = "chest", parent = "torso", shape = "wedge", size = { 2.2, 1.1, 0.6 }, at = { 0, 4.1, -1.25 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 1, 0.6, 0.9 }, at = { 0, 5.2, -0.2 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.75, 0.168, 0.08 }, at = { 0, 5.23, -0.68 }, color = "glass" },
	{ name = "padL", parent = "torso", shape = "box", size = { 0.9, 0.6, 1.8 }, at = { -1.6, 4.8, 0 }, color = "team" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.7, 1.5, 0.8 }, at = { -1.65, 3.85, -0.2 }, color = "metal" },
	{ name = "laserL", parent = "torso", shape = "box", size = { 0.8, 0.7, 1.5 }, at = { -1.65, 3.3, -0.9 }, color = "hull" },
	{ name = "lensL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.12 }, at = { -1.65, 3.3, -1.72 }, color = "glass" },
	{ name = "padR", parent = "torso", shape = "box", size = { 0.9, 0.6, 1.8 }, at = { 1.6, 4.8, 0 }, color = "team" },
	{ name = "armR", parent = "torso", shape = "box", size = { 0.7, 1.5, 0.8 }, at = { 1.65, 3.85, -0.2 }, color = "metal" },
	{ name = "laserR", parent = "torso", shape = "box", size = { 0.8, 0.7, 1.5 }, at = { 1.65, 3.3, -0.9 }, color = "hull" },
	{ name = "lensR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.12 }, at = { 1.65, 3.3, -1.72 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_picket",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.65, 3.3, -1.85 } },
		{ name = "muzzle2", parent = "torso", at = { -1.65, 3.3, -1.85 } },
	},
}

--!strict
-- Snare (Order all-terrain spider with an EMP laser, T2): a light body on four
-- long legs with high knees and claw tips; an EMP emitter ring on its `torso`. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.5, 0.8, 2 }, at = { 0, 2, 0 }, color = "hull" },
}
local visual = Bots.spider(parts, { legs = 4, hipR = 0.8, hipY = 2, kneeR = 2.2, kneeY = 3.4, footR = 3.2, thick = 0.28, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.2, 0.7, 1.4 }, at = { 0, 2.75, -0.1 }, pivot = { 0, 2.4, 0 }, color = "hull" },
	{ name = "emitter", parent = "torso", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.8 }, at = { 0, 2.75, -1.1 }, color = "metal" },
	{ name = "ring", parent = "torso", shape = "cylinder", axis = "z", size = { 0.95, 0.95, 0.15 }, at = { 0, 2.75, -1.45 }, color = "glass" },
	{ name = "backTeam", parent = "torso", shape = "box", size = { 1, 0.08, 0.9 }, at = { 0, 3.12, 0.2 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_snare",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 2.75, -1.6 } },
	},
}

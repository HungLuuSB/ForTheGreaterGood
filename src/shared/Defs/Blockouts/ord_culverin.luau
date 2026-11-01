--!strict
-- Culverin (Order mortar bot, T2): a squat, wide bot with a short fat mortar
-- (`barrel`, pitches) on its back and a team shield plate on its chest. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2, 0.8, 1.6 }, at = { 0, 2.4, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.2, hipX = 0.9, thick = 0.7, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.4, 1.4, 2.2 }, at = { 0, 3.5, 0 }, pivot = { 0, 2.8, 0 }, color = "hull" },
	{ name = "shield", parent = "torso", shape = "wedge", size = { 2.2, 1.2, 0.6 }, at = { 0, 3.5, -1.4 }, color = "team" },
	{ name = "visor", parent = "torso", shape = "box", size = { 1, 0.2, 0.08 }, at = { 0, 3.95, -1.13 }, color = "glass" },
	{ name = "cradle", parent = "torso", shape = "box", size = { 1.2, 0.6, 1.2 }, at = { 0, 4.5, 0.5 }, color = "metal" },
	{ name = "barrel", parent = "torso", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 2 }, at = { 0, 5.2, -0.2 }, rot = { 45, 0, 0 }, pivot = { 0, 4.5, 0.5 }, color = "dark" },
	{ name = "mouthRing", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.95, 0.95, 0.2 }, at = { 0, 5.85, -0.85 }, rot = { 45, 0, 0 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_culverin",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 5.95, -0.95 } },
	},
}

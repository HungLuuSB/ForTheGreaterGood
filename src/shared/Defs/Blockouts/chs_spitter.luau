--!strict
-- Spitter (Chaos mortar bot, T2): squat and low on thick legs, a fat mortar
-- tube (`barrel`, pitches) on its back beside an ammo drum. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2, 0.8, 1.6 }, at = { 0, 2.2, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2, hipX = 0.9, thick = 0.75, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.3, 1.3, 2.1 }, at = { 0, 3.25, 0 }, pivot = { 0, 2.6, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.45, 0.7 }, at = { 0, 3.4, -1.3 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.6, 0.1, 0.06 }, at = { 0, 3.45, -1.67 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.2, 0.4, 0.08 }, at = { 0, 2.9, -1.08 }, color = "team" },
	{ name = "drum", parent = "torso", shape = "cylinder", axis = "x", size = { 1, 0.9, 1 }, at = { -0.75, 4.35, 0.5 }, color = "dark" },
	{ name = "cradle", parent = "torso", shape = "box", size = { 1, 0.6, 1 }, at = { 0.5, 4.2, 0.5 }, color = "metal" },
	{ name = "barrel", parent = "torso", shape = "cylinder", axis = "z", size = { 0.95, 0.95, 1.9 }, at = { 0.5, 4.9, -0.1 }, rot = { 50, 0, 0 }, pivot = { 0.5, 4.2, 0.5 }, color = "metal" },
	{ name = "mouthRing", parent = "barrel", shape = "cylinder", axis = "z", size = { 1.05, 1.05, 0.2 }, at = { 0.5, 5.55, -0.65 }, rot = { 50, 0, 0 }, color = "glass" },
	{ name = "spike1", parent = "torso", shape = "wedge", size = { 0.3, 0.5, 0.5 }, at = { -1, 4.05, -0.6 }, color = "metal" },
	{ name = "spike2", parent = "torso", shape = "wedge", size = { 0.3, 0.5, 0.5 }, at = { 1, 4.05, -0.6 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_spitter",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0.5, 5.65, -0.75 } },
	},
}

--!strict
-- Squire (Order fast infantry bot, T1): small and light on quick legs, a compact
-- body with a visor, a plasma gun on the right arm, an antenna. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.2, 0.8, 1 }, at = { 0, 2.1, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 1.9, hipX = 0.5, thick = 0.4, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.5, 1.2, 1.3 }, at = { 0, 3.1, 0 }, pivot = { 0, 2.5, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.9, 0.45, 0.08 }, at = { 0, 3.15, -0.68 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.5, 0.75 }, at = { 0, 3.95, -0.1 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.6, 0.14, 0.08 }, at = { 0, 3.975, -0.505 }, color = "glass" },
	{ name = "pack", parent = "torso", shape = "box", size = { 1.1, 0.9, 0.5 }, at = { 0, 3.15, 0.9 }, color = "dark" },
	{ name = "antenna", parent = "torso", shape = "cylinder", axis = "y", size = { 0.08, 1.4, 0.08 }, at = { -0.45, 4.4, 0.8 }, color = "dark" },
	{ name = "arm", parent = "torso", shape = "box", size = { 0.45, 0.45, 1.1 }, at = { 0.95, 3.05, -0.4 }, color = "metal" },
	{ name = "gun", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1 }, at = { 0.95, 3.05, -1.45 }, color = "metal" },
	{ name = "gunTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.375, 0.375, 0.2 }, at = { 0.95, 3.05, -2 }, color = "glass" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.4, 0.9, 0.45 }, at = { -0.95, 3.05, 0 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_squire",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0.95, 3.05, -2.1 } },
	},
}

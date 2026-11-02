--!strict
-- Informant (Order cloaked spy bot, T2): small and crouched, dark faceted plates,
-- one glowing eye and the EMP charge glowing in its back. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1, 0.8, 0.9 }, at = { 0, 1.7, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 1.5, hipX = 0.45, thick = 0.35, color = "dark" })
for _, p in {
	{ name = "torso", parent = "base", shape = "wedge", size = { 1.3, 0.9, 1.6 }, at = { 0, 2.55, -0.1 }, pivot = { 0, 2.1, 0 }, color = "dark" },
	{ name = "back", parent = "torso", shape = "box", size = { 1.3, 0.9, 0.5 }, at = { 0, 2.55, 0.9 }, color = "dark" },
	{ name = "core", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.12 }, at = { 0, 2.6, 1.18 }, color = "glass" },
	{ name = "eye", parent = "torso", shape = "ball", size = { 0.35, 0.35, 0.35 }, at = { 0, 2.45, -0.85 }, color = "glass" },
	{ name = "teamFin", parent = "torso", shape = "box", size = { 0.08, 0.3, 0.7 }, at = { 0, 3.15, 0.6 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_informant",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 2.45, -1.05 } },
	},
}

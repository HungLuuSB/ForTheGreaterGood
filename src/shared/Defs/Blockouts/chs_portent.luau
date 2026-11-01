--!strict
-- Portent (Chaos radar bot, T2): spindly, with a lattice mast from its back
-- carrying a spinning radar bar (`radar`) and an amber eye. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 2.5, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.3, hipX = 0.6, thick = 0.5, color = "hull", foot = "metal" })
table.insert(visual, "radar")
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.6, 1.2, 1.4 }, at = { 0, 3.5, 0 }, pivot = { 0, 2.9, 0 }, color = "hull" },
	{ name = "eye", parent = "torso", shape = "ball", size = { 0.45, 0.45, 0.45 }, at = { 0, 3.7, -0.72 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.8, 0.35, 0.08 }, at = { 0, 3.25, -0.73 }, color = "team" },
	{ name = "legL", parent = "torso", shape = "box", size = { 0.12, 2.6, 0.12 }, at = { -0.3, 5.3, 0.6 }, rot = { 0, 0, 6 }, color = "metal" },
	{ name = "legR", parent = "torso", shape = "box", size = { 0.12, 2.6, 0.12 }, at = { 0.3, 5.3, 0.6 }, rot = { 0, 0, -6 }, color = "metal" },
	{ name = "rung1", parent = "torso", shape = "box", size = { 0.7, 0.08, 0.08 }, at = { 0, 4.6, 0.6 }, color = "dark" },
	{ name = "rung2", parent = "torso", shape = "box", size = { 0.58, 0.08, 0.08 }, at = { 0, 5.35, 0.6 }, color = "dark" },
	{ name = "rung3", parent = "torso", shape = "box", size = { 0.46, 0.08, 0.08 }, at = { 0, 6.1, 0.6 }, color = "dark" },
	{ name = "radar", parent = "torso", shape = "box", size = { 3, 0.6, 0.3 }, at = { 0, 6.8, 0.6 }, pivot = { 0, 6.8, 0.6 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarFace", parent = "radar", shape = "box", size = { 2.55, 0.36, 0.08 }, at = { 0, 6.8, 0.42 }, color = "glass" },
	{ name = "spike1", parent = "torso", shape = "wedge", size = { 0.3, 0.5, 0.5 }, at = { -0.6, 4.35, 0.2 }, color = "metal" },
	{ name = "spike2", parent = "torso", shape = "wedge", size = { 0.3, 0.5, 0.5 }, at = { 0.6, 4.35, 0.2 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_portent",
	parts = parts,
	visualPieces = visual,
}

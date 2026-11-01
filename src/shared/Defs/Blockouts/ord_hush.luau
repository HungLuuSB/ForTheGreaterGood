--!strict
-- Hush (Order jammer bot, T2): a small bot carrying a tall jammer mast on its back,
-- three cross arms with glowing tips and an emitter dome. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 2.3, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.1, hipX = 0.6, thick = 0.5, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.6, 1.3, 1.4 }, at = { 0, 3.35, 0 }, pivot = { 0, 2.7, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.75, 0.45, 0.7 }, at = { 0, 4.225, -0.2 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.562, 0.126, 0.08 }, at = { 0, 4.247, -0.58 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.9, 0.45, 0.08 }, at = { 0, 3.4, -0.73 }, color = "team" },
	{ name = "mast", parent = "torso", shape = "box", size = { 0.25, 3, 0.25 }, at = { 0, 5.5, 0.55 }, color = "metal" },
	{ name = "bar1", parent = "torso", shape = "box", size = { 1.8, 0.12, 0.12 }, at = { 0, 5, 0.55 }, color = "dark" },
	{ name = "tip1L", parent = "torso", shape = "ball", size = { 0.22, 0.22, 0.22 }, at = { -0.9, 5, 0.55 }, color = "glass" },
	{ name = "tip1R", parent = "torso", shape = "ball", size = { 0.22, 0.22, 0.22 }, at = { 0.9, 5, 0.55 }, color = "glass" },
	{ name = "bar2", parent = "torso", shape = "box", size = { 1.4, 0.12, 0.12 }, at = { 0, 5.85, 0.55 }, color = "dark" },
	{ name = "tip2L", parent = "torso", shape = "ball", size = { 0.22, 0.22, 0.22 }, at = { -0.7, 5.85, 0.55 }, color = "glass" },
	{ name = "tip2R", parent = "torso", shape = "ball", size = { 0.22, 0.22, 0.22 }, at = { 0.7, 5.85, 0.55 }, color = "glass" },
	{ name = "bar3", parent = "torso", shape = "box", size = { 1, 0.12, 0.12 }, at = { 0, 6.7, 0.55 }, color = "dark" },
	{ name = "tip3L", parent = "torso", shape = "ball", size = { 0.22, 0.22, 0.22 }, at = { -0.5, 6.7, 0.55 }, color = "glass" },
	{ name = "tip3R", parent = "torso", shape = "ball", size = { 0.22, 0.22, 0.22 }, at = { 0.5, 6.7, 0.55 }, color = "glass" },
	{ name = "dome", parent = "torso", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 0, 7.1, 0.55 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_hush",
	parts = parts,
	visualPieces = visual,
}

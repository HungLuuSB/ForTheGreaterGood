--!strict
-- Sextant (Order radar bot, T2): a compact bot carrying a mast on its back with
-- a big tilted radar dish (`radar`, spins). Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 2.4, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.2, hipX = 0.6, thick = 0.5, color = "hull", team = true })
table.insert(visual, "radar")
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.6, 1.3, 1.4 }, at = { 0, 3.45, 0 }, pivot = { 0, 2.8, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.8, 0.45, 0.7 }, at = { 0, 4.325, -0.2 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.6, 0.126, 0.08 }, at = { 0, 4.348, -0.58 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.9, 0.45, 0.08 }, at = { 0, 3.5, -0.73 }, color = "team" },
	{ name = "mast", parent = "torso", shape = "cylinder", axis = "y", size = { 0.2, 2, 0.2 }, at = { 0, 5.1, 0.6 }, color = "metal" },
	{ name = "radar", parent = "torso", shape = "cylinder", axis = "y", size = { 2.6, 0.15, 2.6 }, at = { 0, 6.2, 0.6 }, rot = { 25, 0, 0 }, pivot = { 0, 6.1, 0.6 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "radarFace", parent = "radar", shape = "cylinder", axis = "y", size = { 2.3, 0.06, 2.3 }, at = { 0, 6.3, 0.55 }, rot = { 25, 0, 0 }, color = "team" },
	{ name = "feed", parent = "radar", shape = "ball", size = { 0.35, 0.35, 0.35 }, at = { 0, 6.7, 0.35 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_sextant",
	parts = parts,
	visualPieces = visual,
}

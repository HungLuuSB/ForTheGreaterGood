--!strict
-- Marksman (Order cloaked sniper bot, T2): slim and dark with a hooded sensor
-- head, holding a very long rifle with a scope at the shoulder. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 3.2, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 3, hipX = 0.6, thick = 0.45, color = "dark", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.6, 1.4, 1.4 }, at = { 0, 4.3, 0 }, pivot = { 0, 3.6, 0 }, color = "dark" },
	{ name = "hood", parent = "torso", shape = "wedge", size = { 0.9, 0.6, 1 }, at = { 0, 5.3, -0.1 }, color = "dark" },
	{ name = "eye", parent = "torso", shape = "box", size = { 0.6, 0.12, 0.06 }, at = { 0, 5.2, -0.62 }, color = "glass" },
	{ name = "arm", parent = "torso", shape = "box", size = { 0.45, 0.9, 0.5 }, at = { 0.95, 4.5, -0.2 }, color = "metal" },
	{ name = "stock", parent = "torso", shape = "box", size = { 0.4, 0.5, 1.4 }, at = { 0.75, 4.8, -0.2 }, color = "hull" },
	{ name = "rifle", parent = "torso", shape = "cylinder", axis = "z", size = { 0.22, 0.22, 4.6 }, at = { 0.75, 4.9, -3.2 }, color = "metal" },
	{ name = "rifleTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.275, 0.275, 0.2 }, at = { 0.75, 4.9, -5.55 }, color = "dark" },
	{ name = "scope", parent = "torso", shape = "cylinder", axis = "z", size = { 0.25, 0.25, 0.9 }, at = { 0.75, 5.22, -1.1 }, color = "metal" },
	{ name = "lens", parent = "torso", shape = "cylinder", axis = "z", size = { 0.22, 0.22, 0.06 }, at = { 0.75, 5.22, -1.58 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.6, 0.4, 0.06 }, at = { -0.3, 4.4, -0.73 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_marksman",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0.75, 4.9, -5.65 } },
	},
}

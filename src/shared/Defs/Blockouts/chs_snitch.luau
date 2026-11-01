--!strict
-- Snitch (Chaos cloaked spy bot, T2): tiny and crouched, dark plates, one amber
-- eye, a whip antenna and the EMP charge glowing in its back. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1, 0.8, 0.9 }, at = { 0, 1.7, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 1.5, hipX = 0.45, thick = 0.35, color = "dark", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.2, 0.9, 1.4 }, at = { 0, 2.55, 0 }, pivot = { 0, 2.1, 0 }, color = "dark" },
	{ name = "head", parent = "torso", shape = "wedge", size = { 0.8, 0.5, 0.8 }, at = { 0, 3.2, -0.4 }, color = "hull" },
	{ name = "eye", parent = "torso", shape = "ball", size = { 0.3, 0.3, 0.3 }, at = { 0, 3.1, -0.82 }, color = "glass" },
	{ name = "whip", parent = "torso", shape = "cylinder", axis = "y", size = { 0.06, 1.8, 0.06 }, at = { 0.3, 3.9, 0.5 }, color = "metal" },
	{ name = "core", parent = "torso", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.12 }, at = { 0, 2.55, 0.76 }, color = "glass" },
	{ name = "teamFin", parent = "torso", shape = "box", size = { 0.08, 0.3, 0.6 }, at = { -0.3, 3.15, 0.3 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_snitch",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 3.1, -0.95 } },
	},
}

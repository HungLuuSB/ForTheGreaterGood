--!strict
-- Stormcaller (Order heavy assault bot, lightning rifle, T2): broad and armoured,
-- big team shoulder pads, the lightning rifle as its right forearm with three
-- glowing coils, a capacitor pack on its back. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.2, 0.8, 1.7 }, at = { 0, 3.1, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.9, hipX = 0.9, thick = 0.75, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.7, 2, 2.2 }, at = { 0, 4.5, 0 }, pivot = { 0, 3.5, 0 }, color = "hull" },
	{ name = "chest", parent = "torso", shape = "wedge", size = { 2.3, 1.2, 0.6 }, at = { 0, 4.6, -1.35 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 1, 0.6, 0.9 }, at = { 0, 5.8, -0.3 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.75, 0.168, 0.08 }, at = { 0, 5.83, -0.78 }, color = "glass" },
	{ name = "padL", parent = "torso", shape = "box", size = { 1.1, 0.7, 2 }, at = { -1.75, 5.4, 0 }, color = "team" },
	{ name = "padR", parent = "torso", shape = "box", size = { 1.1, 0.7, 2 }, at = { 1.75, 5.4, 0 }, color = "team" },
	{ name = "rifle", parent = "torso", shape = "box", size = { 0.8, 0.8, 3 }, at = { 1.75, 3.9, -1 }, color = "hull" },
	{ name = "coil1", parent = "torso", shape = "cylinder", axis = "z", size = { 1, 1, 0.18 }, at = { 1.75, 3.9, -0.6 }, color = "glass" },
	{ name = "coil2", parent = "torso", shape = "cylinder", axis = "z", size = { 1, 1, 0.18 }, at = { 1.75, 3.9, -1.3 }, color = "glass" },
	{ name = "coil3", parent = "torso", shape = "cylinder", axis = "z", size = { 1, 1, 0.18 }, at = { 1.75, 3.9, -2 }, color = "glass" },
	{ name = "prong", parent = "torso", shape = "box", size = { 0.3, 0.3, 0.8 }, at = { 1.75, 3.9, -2.85 }, color = "metal" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.7, 1.4, 0.8 }, at = { -1.75, 4, -0.1 }, color = "metal" },
	{ name = "pack", parent = "torso", shape = "box", size = { 1.8, 1.4, 0.8 }, at = { 0, 4.6, 1.45 }, color = "dark" },
	{ name = "packGlow", parent = "torso", shape = "box", size = { 1.2, 0.15, 0.06 }, at = { 0, 5, 1.88 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_stormcaller",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.75, 3.9, -3.35 } },
	},
}

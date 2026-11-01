--!strict
-- Paragon (Order amphibious assault mech, twin gauss cannons, T3): a sealed
-- armoured body with float collars, a sensor head, and a long gauss cannon on
-- each shoulder (`muzzle`, `muzzle2`). Laid out at bot size and scaled x1.7. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.2, 0.8, 1.7 }, at = { 0, 3.1, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 2.9, hipX = 0.95, thick = 0.75, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 1.9, 2.3 }, at = { 0, 4.45, 0 }, pivot = { 0, 3.5, 0 }, color = "hull" },
	{ name = "bow", parent = "torso", shape = "wedge", size = { 2.4, 1.2, 0.7 }, at = { 0, 4.2, -1.45 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 1, 0.55, 0.9 }, at = { 0, 5.675, -0.3 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.75, 0.154, 0.08 }, at = { 0, 5.703, -0.78 }, color = "glass" },
	{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 2 }, at = { -1.5, 3.15, 0 }, color = "team" },
	{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 2 }, at = { 1.5, 3.15, 0 }, color = "team" },
	{ name = "mountR", parent = "torso", shape = "box", size = { 0.9, 0.9, 1.6 }, at = { 1.75, 5.3, 0.1 }, color = "team" },
	{ name = "cannonR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 2.8 }, at = { 1.75, 5.3, -2.1 }, color = "metal" },
	{ name = "cannonRTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.562, 0.562, 0.2 }, at = { 1.75, 5.3, -3.55 }, color = "dark" },
	{ name = "coilR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 0.18 }, at = { 1.75, 5.3, -1.3 }, color = "glass" },
	{ name = "mountL", parent = "torso", shape = "box", size = { 0.9, 0.9, 1.6 }, at = { -1.75, 5.3, 0.1 }, color = "team" },
	{ name = "cannonL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 2.8 }, at = { -1.75, 5.3, -2.1 }, color = "metal" },
	{ name = "cannonLTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.562, 0.562, 0.2 }, at = { -1.75, 5.3, -3.55 }, color = "dark" },
	{ name = "coilL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 0.18 }, at = { -1.75, 5.3, -1.3 }, color = "glass" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "ord_paragon",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.75, 5.3, -3.65 } },
		{ name = "muzzle2", parent = "torso", at = { -1.75, 5.3, -3.65 } },
	},
}, 1.7)

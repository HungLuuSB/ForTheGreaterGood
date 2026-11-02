--!strict
-- Infernal (Chaos flamethrower mech with anti-air shoulder rockets, T3): a horned
-- heavy mech, a flamer cannon as each forearm (`muzzle`, `muzzle2`), fuel tanks
-- on its back and a rocket pod on each shoulder raked skyward (`aa_muzzle`).
-- Laid out at bot size and scaled x2.2. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.4, 0.8, 1.8 }, at = { 0, 3.2, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 3, hipX = 1, thick = 0.9, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.8, 2.1, 2.3 }, at = { 0, 4.65, 0 }, pivot = { 0, 3.6, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 1, 0.65, 0.9 }, at = { 0, 6, -0.6 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.8, 0.12, 0.06 }, at = { 0, 6.08, -1.08 }, color = "glass" },
	{ name = "hornL", parent = "torso", shape = "wedge", size = { 0.25, 1, 0.7 }, at = { -0.55, 6.7, -0.5 }, rot = { 0, 0, 20 }, color = "metal" },
	{ name = "tankL", parent = "torso", shape = "cylinder", axis = "y", size = { 0.7, 1.6, 0.7 }, at = { -0.55, 4.7, 1.45 }, color = "hazard" },
	{ name = "hornR", parent = "torso", shape = "wedge", size = { 0.25, 1, 0.7 }, at = { 0.55, 6.7, -0.5 }, rot = { 0, 0, -20 }, color = "metal" },
	{ name = "tankR", parent = "torso", shape = "cylinder", axis = "y", size = { 0.7, 1.6, 0.7 }, at = { 0.55, 4.7, 1.45 }, color = "hazard" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.4, 0.5, 0.08 }, at = { 0, 4.4, -1.18 }, color = "team" },
	{ name = "armR", parent = "torso", shape = "box", size = { 0.9, 1.6, 1 }, at = { 1.95, 4.5, -0.1 }, color = "metal" },
	{ name = "flamerR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 1.8 }, at = { 1.95, 3.8, -1.5 }, color = "dark" },
	{ name = "flamerRTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.875, 0.875, 0.2 }, at = { 1.95, 3.8, -2.45 }, color = "glass" },
	{ name = "podR", parent = "torso", shape = "box", size = { 1, 0.9, 1.4 }, at = { 1.75, 6.05, 0.2 }, rot = { 25, 0, 0 }, color = "hull" },
	{ name = "podCellsR", parent = "torso", shape = "box", size = { 0.8, 0.08, 0.7 }, at = { 1.75, 6.42, -0.1 }, rot = { 25, 0, 0 }, color = "glass" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.9, 1.6, 1 }, at = { -1.95, 4.5, -0.1 }, color = "metal" },
	{ name = "flamerL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 1.8 }, at = { -1.95, 3.8, -1.5 }, color = "dark" },
	{ name = "flamerLTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.875, 0.875, 0.2 }, at = { -1.95, 3.8, -2.45 }, color = "glass" },
	{ name = "podL", parent = "torso", shape = "box", size = { 1, 0.9, 1.4 }, at = { -1.75, 6.05, 0.2 }, rot = { 25, 0, 0 }, color = "hull" },
	{ name = "podCellsL", parent = "torso", shape = "box", size = { 0.8, 0.08, 0.7 }, at = { -1.75, 6.42, -0.1 }, rot = { 25, 0, 0 }, color = "glass" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "chs_infernal",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.95, 3.8, -2.55 } },
		{ name = "muzzle2", parent = "torso", at = { -1.95, 3.8, -2.55 } },
		{ name = "aa_muzzle", parent = "torso", at = { 1.75, 6.6, -0.3 } },
	},
}, 2.2)

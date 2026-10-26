--!strict
-- Mace (Order skirmisher bot, T1, footprint 1; S-181; outranges T1 tanks
-- with slow plasma): an upright bot whose `torso` (turns) carries a long
-- plasma barrel over the right shoulder in a housing with glowing coils and
-- a plasma cell on the back, a sensor head on the left and a short left
-- arm; `muzzle` at the barrel's mouth. Legs are client pieces (Bots.luau).
-- Order reads clean (M-14). Model space, forward = -Z.

local Bots = require("../Bots")

local BX, BY = 1.15, 5.0 -- the barrel's axis

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.9, 0 }, color = "hull" },
}
local legs = Bots.legs(parts, { hipY = 2.7, hipX = 0.7, thick = 0.55, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.2, 1.8, 1.8 }, at = { 0, 4.2, 0 }, pivot = { 0, 3.3, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.8, 0.6, 0.08 }, at = { -0.4, 4.2, -0.94 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.9, 0.6, 0.9 }, at = { -0.55, 5.4, -0.2 }, color = "hull" },
	{ name = "headGlass", parent = "torso", shape = "box", size = { 0.7, 0.2, 0.1 }, at = { -0.55, 5.45, -0.68 }, color = "glass" },
	{ name = "cell", parent = "torso", shape = "box", size = { 1.2, 1.2, 0.6 }, at = { 0.3, 4.4, 1.2 }, color = "glass" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.5, 1.3, 0.5 }, at = { -1.4, 3.9, 0 }, color = "metal" },
	{ name = "housing", parent = "torso", shape = "box", size = { 0.9, 0.9, 1.8 }, at = { BX, BY, 0.2 }, color = "hull" },
	{ name = "barrel", parent = "torso", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 4.4 }, at = { BX, BY, -2.9 }, color = "metal" },
	{ name = "coil1", parent = "torso", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 0.2 }, at = { BX, BY, -1.6 }, color = "glass" },
	{ name = "coil2", parent = "torso", shape = "cylinder", axis = "z", size = { 0.65, 0.65, 0.2 }, at = { BX, BY, -2.6 }, color = "glass" },
	{ name = "mouth", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.4 }, at = { BX, BY, -5.0 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_mace",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { BX, BY, -5.3 } },
	},
}

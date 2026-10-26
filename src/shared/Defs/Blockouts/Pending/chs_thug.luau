--!strict
-- Thug (Chaos assault bot, T1, footprint 1; S-181; tough, short-ranged): a
-- stocky brawler on short thick legs. A wide `torso` (turns) with spiked
-- shoulder plates, a small head sunk between them with an amber slit, a fist
-- on the left and the plasma cannon as the right forearm, its mouth glowing;
-- `muzzle` there. Legs are client pieces (Bots.luau). Chaos reads crude and
-- brutal (M-14). Model space, forward = -Z.

local Bots = require("../Bots")

local CX, CY = 1.9, 3.6 -- the cannon's axis

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.2, 0.8, 1.6 }, at = { 0, 2.3, 0 }, color = "dark" },
}
local legs = Bots.legs(parts, { hipY = 2.2, hipX = 0.95, thick = 0.75, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 3.0, 2.0, 2.4 }, at = { 0, 3.8, 0 }, pivot = { 0, 2.8, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.4, 0.7, 0.08 }, at = { 0, 3.6, -1.24 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 1.0, 0.7, 1.0 }, at = { 0, 5.1, -0.3 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.7, 0.15, 0.1 }, at = { 0, 5.15, -0.82 }, color = "glass" },
	{ name = "padL", parent = "torso", shape = "wedge", size = { 1.2, 0.8, 2.4 }, at = { -1.6, 5.1, 0 }, rot = { 0, 90, 0 }, color = "metal" },
	{ name = "padR", parent = "torso", shape = "wedge", size = { 1.2, 0.8, 2.4 }, at = { 1.6, 5.1, 0 }, rot = { 0, -90, 0 }, color = "metal" },
	{ name = "spikeL", parent = "torso", shape = "wedge", size = { 0.3, 0.8, 0.5 }, at = { -1.9, 5.85, 0 }, color = "metal" },
	{ name = "spikeR", parent = "torso", shape = "wedge", size = { 0.3, 0.8, 0.5 }, at = { 1.9, 5.85, 0 }, color = "metal" },
	{ name = "fist", parent = "torso", shape = "box", size = { 0.9, 1.6, 0.9 }, at = { -1.9, 3.3, -0.4 }, color = "metal" },
	{ name = "cannonArm", parent = "torso", shape = "box", size = { 1.0, 1.0, 1.4 }, at = { CX, CY, -0.4 }, color = "metal" },
	{ name = "cannon", parent = "torso", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 1.6 }, at = { CX, CY, -1.9 }, color = "dark" },
	{ name = "glow", parent = "torso", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.1 }, at = { CX, CY, -2.72 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_thug",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { CX, CY, -2.85 } },
	},
}

--!strict
-- Centurion (Chaos heavy laser bot, T2, footprint 2; S-181; very tough, a
-- long red laser that cuts a line of light units): a tall armored knight on
-- long legs. A broad `torso` (turns) with spiked shoulder plates, a helmet
-- head with a red slit, a slab shield on the left arm and the laser lance as
-- the right forearm, its red lens at the tip; `muzzle` there. Legs are
-- client pieces (Bots.luau). Chaos reads crude and brutal (M-14). Model
-- space, forward = -Z.

local Bots = require("../Bots")

local LX, LY = 3.0, 7.2 -- the lance's axis

local parts: { any } = {
	{ name = "base", shape = "box", size = { 3.6, 1.4, 2.4 }, at = { 0, 5.9, 0 }, color = "dark" },
	{ name = "tasset", parent = "base", shape = "wedge", size = { 3.2, 1.6, 0.6 }, at = { 0, 5.0, -1.4 }, rot = { 0, 180, 0 }, color = "metal" },
}
local legs = Bots.legs(parts, { hipY = 5.6, hipX = 1.4, thick = 1.1, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 4.6, 3.6, 3.0 }, at = { 0, 8.6, 0 }, pivot = { 0, 6.6, 0 }, color = "hull" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 2.0, 1.2, 0.08 }, at = { 0, 8.8, -1.54 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 1.3, 1.4, 1.5 }, at = { 0, 11.1, -0.3 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.9, 0.2, 0.1 }, at = { 0, 11.2, -1.07 }, color = "glass" },
	{ name = "crest", parent = "torso", shape = "wedge", size = { 0.3, 1.0, 1.6 }, at = { 0, 12.3, -0.1 }, color = "metal" },
	{ name = "padL", parent = "torso", shape = "box", size = { 1.8, 1.4, 2.6 }, at = { -3.1, 10.1, 0 }, rot = { 0, 0, 12 }, color = "metal" },
	{ name = "padR", parent = "torso", shape = "box", size = { 1.8, 1.4, 2.6 }, at = { 3.1, 10.1, 0 }, rot = { 0, 0, -12 }, color = "metal" },
	{ name = "spikeL", parent = "torso", shape = "wedge", size = { 0.4, 1.4, 0.8 }, at = { -3.4, 11.4, 0 }, color = "metal" },
	{ name = "spikeR", parent = "torso", shape = "wedge", size = { 0.4, 1.4, 0.8 }, at = { 3.4, 11.4, 0 }, color = "metal" },
	{ name = "armL", parent = "torso", shape = "box", size = { 1.0, 3.0, 1.0 }, at = { -3.0, 8.2, -0.2 }, color = "hull" },
	{ name = "shield", parent = "torso", shape = "box", size = { 0.4, 4.4, 3.0 }, at = { -3.7, 7.6, -0.8 }, color = "metal" },
	{ name = "shieldTeam", parent = "torso", shape = "box", size = { 0.08, 1.6, 1.4 }, at = { -3.94, 7.8, -0.8 }, color = "team" },
	{ name = "armR", parent = "torso", shape = "box", size = { 1.0, 2.6, 1.0 }, at = { LX, 8.6, -0.2 }, color = "hull" },
	{ name = "lanceBody", parent = "torso", shape = "box", size = { 1.2, 1.2, 2.0 }, at = { LX, LY, -0.6 }, color = "dark" },
	{ name = "lance", parent = "torso", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 5.6 }, at = { LX, LY, -4.4 }, color = "metal" },
	{ name = "lanceRing", parent = "torso", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 0.3 }, at = { LX, LY, -3.0 }, color = "dark" },
	{ name = "lens", parent = "torso", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.1 }, at = { LX, LY, -7.25 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_centurion",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { LX, LY, -7.4 } },
	},
}

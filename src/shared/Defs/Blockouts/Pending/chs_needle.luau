--!strict
-- Needle (Chaos anti-air bot, T1, footprint 1; S-181): a hunched bot whose
-- `torso` (turns) carries on its back the `launcher` (pitches): a rack of
-- three bare missile tubes over the shoulders with amber tips; `muzzle` at
-- the tubes' mouths. An amber eye, a slab body. Legs are client pieces
-- (Bots.luau). Chaos reads crude (M-14). Model space, forward = -Z.

local Bots = require("../Bots")

local LY, LZ = 5.1, 0.4 -- the launcher's centre

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.4, 0 }, color = "dark" },
}
local legs = Bots.legs(parts, { hipY = 2.3, hipX = 0.75, thick = 0.6, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.2, 1.6, 1.8 }, at = { 0, 3.6, 0 }, pivot = { 0, 2.8, 0 }, color = "hull" },
	{ name = "eye", parent = "torso", shape = "box", size = { 0.9, 0.22, 0.1 }, at = { 0, 3.9, -0.92 }, color = "glass" },
	{ name = "sideTeam", parent = "torso", shape = "box", size = { 0.08, 0.8, 1.2 }, at = { 1.14, 3.6, 0 }, color = "team" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.5, 1.3, 0.5 }, at = { -1.4, 3.3, -0.1 }, color = "metal" },
	{ name = "armR", parent = "torso", shape = "box", size = { 0.5, 1.3, 0.5 }, at = { 1.4, 3.3, -0.1 }, color = "metal" },
	{ name = "launcher", parent = "torso", shape = "box", size = { 2.0, 0.5, 1.6 }, at = { 0, LY - 0.55, LZ + 0.3 }, pivot = { 0, LY - 0.5, LZ + 0.6 }, color = "dark" },
} do
	table.insert(parts, p)
end
for k, x in { -0.65, 0, 0.65 } do
	table.insert(parts, { name = `tube{k}`, parent = "launcher", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 2.0 }, at = { x, LY, LZ }, color = "metal" })
	table.insert(parts, { name = `tip{k}`, parent = "launcher", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.1 }, at = { x, LY, LZ - 1.02 }, color = "glass" })
end

return {
	id = "chs_needle",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, LY, LZ - 1.1 } },
	},
}

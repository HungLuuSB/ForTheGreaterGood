--!strict
-- Pyre (Chaos fast flamethrower bot, T2): lean and forward-leaning, two hazard
-- fuel tanks on its back, a flamer nozzle as the right arm with an amber pilot
-- light. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 2.8, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.6, hipX = 0.6, thick = 0.5, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.7, 1.3, 1.5 }, at = { 0, 3.85, -0.15 }, rot = { -10, 0, 0 }, pivot = { 0, 3.2, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.7, 0.45, 0.7 }, at = { -0.3, 4.65, -0.6 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.5, 0.1, 0.06 }, at = { -0.3, 4.7, -0.97 }, color = "glass" },
	{ name = "tankL", parent = "torso", shape = "cylinder", axis = "y", size = { 0.55, 1.4, 0.55 }, at = { -0.35, 4.1, 0.9 }, color = "hazard" },
	{ name = "tankR", parent = "torso", shape = "cylinder", axis = "y", size = { 0.55, 1.4, 0.55 }, at = { 0.35, 4.1, 0.9 }, color = "hazard" },
	{ name = "hose", parent = "torso", shape = "box", size = { 0.15, 0.15, 1.2 }, at = { 0.7, 3.7, 0.3 }, color = "dark" },
	{ name = "arm", parent = "torso", shape = "box", size = { 0.55, 0.55, 1.2 }, at = { 1.05, 3.7, -0.5 }, color = "metal" },
	{ name = "nozzle", parent = "torso", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 0.9 }, at = { 1.05, 3.7, -1.55 }, color = "dark" },
	{ name = "nozzleTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.2 }, at = { 1.05, 3.7, -2.05 }, color = "glass" },
	{ name = "spike1", parent = "torso", shape = "wedge", size = { 0.3, 0.5, 0.5 }, at = { -0.7, 4.65, 0 }, color = "metal" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.5, 0.35, 0.06 }, at = { -0.4, 3.8, -0.92 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_pyre",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.05, 3.7, -2.15 } },
	},
}

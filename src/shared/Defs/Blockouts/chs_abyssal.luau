--!strict
-- Abyssal (Chaos amphibious siege mech, heavy cannon, T3): a sealed, rounded hulk
-- with ballast tanks on its back and a single huge cannon on the right
-- shoulder. Laid out at bot size and scaled x1.8. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.3, 0.8, 1.8 }, at = { 0, 3, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.8, hipX = 1, thick = 0.85, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 2, 2.4 }, at = { 0, 4.4, 0 }, pivot = { 0, 3.4, 0 }, color = "hull" },
	{ name = "dome", parent = "torso", shape = "ball", size = { 2.4, 1.2, 2.2 }, at = { 0, 5.4, 0 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 1, 0.15, 0.06 }, at = { -0.3, 4.85, -1.23 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.2, 0.5, 0.08 }, at = { -0.3, 4.1, -1.23 }, color = "team" },
	{ name = "ballastL", parent = "torso", shape = "cylinder", axis = "y", size = { 0.8, 2, 0.8 }, at = { -0.6, 4.5, 1.5 }, color = "dark" },
	{ name = "ballastR", parent = "torso", shape = "cylinder", axis = "y", size = { 0.8, 2, 0.8 }, at = { 0.6, 4.5, 1.5 }, color = "dark" },
	{ name = "armL", parent = "torso", shape = "box", size = { 0.9, 1.5, 1 }, at = { -1.75, 4.1, -0.1 }, color = "metal" },
	{ name = "claw", parent = "torso", shape = "wedge", size = { 0.6, 0.7, 0.9 }, at = { -1.75, 3.2, -0.5 }, color = "dark" },
	{ name = "mount", parent = "torso", shape = "box", size = { 1.2, 1.2, 2 }, at = { 1.85, 5.2, 0.2 }, color = "hull" },
	{ name = "cannon", parent = "torso", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 3.6 }, at = { 1.85, 5.2, -2.6 }, color = "metal" },
	{ name = "cannonTip", parent = "torso", shape = "cylinder", axis = "z", size = { 1, 1, 0.2 }, at = { 1.85, 5.2, -4.45 }, color = "dark" },
	{ name = "sleeve", parent = "torso", shape = "cylinder", axis = "z", size = { 1.05, 1.05, 1 }, at = { 1.85, 5.2, -1.3 }, color = "dark" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "chs_abyssal",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.85, 5.2, -4.55 } },
	},
}, 1.8)

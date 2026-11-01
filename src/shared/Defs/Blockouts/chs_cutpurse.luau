--!strict
-- Cutpurse (Chaos stealthy jamming combat engineer, T2): lean and dark, a
-- hooded head with one amber eye, cloak plates over the shoulders, twin whip
-- antennas, a claw arm (`nano`) on the left and a short gun on the right. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.8, 1.2 }, at = { 0, 2.8, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.6, hipX = 0.6, thick = 0.5, color = "dark", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.7, 1.4, 1.4 }, at = { 0, 3.9, 0 }, pivot = { 0, 3.2, 0 }, color = "dark" },
	{ name = "hood", parent = "torso", shape = "wedge", size = { 1, 0.7, 1.1 }, at = { 0, 4.95, -0.1 }, color = "hull" },
	{ name = "eye", parent = "torso", shape = "ball", size = { 0.3, 0.3, 0.3 }, at = { 0, 4.85, -0.62 }, color = "glass" },
	{ name = "cloakL", parent = "torso", shape = "wedge", size = { 0.6, 1.2, 1.5 }, at = { -1, 4.2, 0.1 }, rot = { 0, 0, -15 }, color = "hull" },
	{ name = "whipL", parent = "torso", shape = "cylinder", axis = "y", size = { 0.06, 2.2, 0.06 }, at = { -0.5, 5.7, 0.6 }, color = "metal" },
	{ name = "cloakR", parent = "torso", shape = "wedge", size = { 0.6, 1.2, 1.5 }, at = { 1, 4.2, 0.1 }, rot = { 0, 0, 15 }, color = "hull" },
	{ name = "whipR", parent = "torso", shape = "cylinder", axis = "y", size = { 0.06, 2.2, 0.06 }, at = { 0.5, 5.7, 0.6 }, color = "metal" },
	{ name = "nano", parent = "torso", shape = "box", size = { 0.45, 0.45, 1.6 }, at = { -1.05, 3.7, -1 }, pivot = { -1.05, 3.7, -0.2 }, color = "metal" },
	{ name = "nanoClawL", parent = "nano", shape = "wedge", size = { 0.15, 0.5, 0.6 }, at = { -1.25, 3.7, -2 }, color = "dark" },
	{ name = "nanoClawR", parent = "nano", shape = "wedge", size = { 0.15, 0.5, 0.6 }, at = { -0.85, 3.7, -2 }, color = "dark" },
	{ name = "nanoGlow", parent = "nano", shape = "ball", size = { 0.32, 0.32, 0.32 }, at = { -1.05, 3.7, -2.05 }, color = "glass" },
	{ name = "gun", parent = "torso", shape = "cylinder", axis = "z", size = { 0.28, 0.28, 1 }, at = { 1.05, 3.7, -0.9 }, color = "metal" },
	{ name = "gunTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.35, 0.35, 0.2 }, at = { 1.05, 3.7, -1.45 }, color = "dark" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.5, 0.35, 0.06 }, at = { 0.3, 4.1, -0.73 }, color = "team" },
	{ name = "nano1", parent = "nano", shape = "ball", size = { 0.3, 0.3, 0.3 }, at = { -1.05, 3.7, -2.3 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_cutpurse",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.05, 3.7, -1.55 } },
	},
}

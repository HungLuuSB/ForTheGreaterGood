--!strict
-- Champion (Order battle mech, rapid laser, T3): a heavy upright mech, a big
-- chest with a team crest, a rotary laser cannon as the right arm and a tower
-- shield on the left. Laid out at bot size and scaled x2.1. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.4, 0.8, 1.8 }, at = { 0, 3.2, 0 }, color = "hull" },
}
local visual = Bots.legs(parts, { hipY = 3, hipX = 1, thick = 0.85, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 3, 2.2, 2.4 }, at = { 0, 4.7, 0 }, pivot = { 0, 3.6, 0 }, color = "hull" },
	{ name = "chest", parent = "torso", shape = "wedge", size = { 2.6, 1.4, 0.7 }, at = { 0, 4.8, -1.55 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 1.1, 0.65, 1 }, at = { 0, 6.125, -0.4 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 0.825, 0.182, 0.08 }, at = { 0, 6.158, -0.93 }, color = "glass" },
	{ name = "padR", parent = "torso", shape = "box", size = { 1.2, 0.8, 2.2 }, at = { 1.95, 5.7, 0 }, color = "team" },
	{ name = "armR", parent = "torso", shape = "box", size = { 0.9, 1.6, 1 }, at = { 2, 4.4, -0.2 }, color = "metal" },
	{ name = "laserBody", parent = "torso", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 2.2 }, at = { 2, 3.7, -1.2 }, color = "hull" },
	{ name = "barrel1", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.4 }, at = { 1.72, 3.98, -2.9 }, color = "metal" },
	{ name = "barrel2", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.4 }, at = { 2.28, 3.98, -2.9 }, color = "metal" },
	{ name = "barrel3", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.4 }, at = { 1.72, 3.42, -2.9 }, color = "metal" },
	{ name = "barrel4", parent = "torso", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.4 }, at = { 2.28, 3.42, -2.9 }, color = "metal" },
	{ name = "lens", parent = "torso", shape = "cylinder", axis = "z", size = { 1, 1, 0.1 }, at = { 2, 3.7, -2.35 }, color = "glass" },
	{ name = "padL", parent = "torso", shape = "box", size = { 1.2, 0.8, 2.2 }, at = { -1.95, 5.7, 0 }, color = "team" },
	{ name = "shield", parent = "torso", shape = "box", size = { 0.4, 2.6, 2 }, at = { -2.15, 4, -0.6 }, color = "hull" },
	{ name = "shieldTeam", parent = "torso", shape = "box", size = { 0.06, 1.6, 1.2 }, at = { -2.38, 4.1, -0.6 }, color = "team" },
	{ name = "pack", parent = "torso", shape = "box", size = { 2.2, 1.6, 0.9 }, at = { 0, 4.8, 1.6 }, color = "dark" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "ord_champion",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 2, 3.7, -3.7 } },
	},
}, 2.1)

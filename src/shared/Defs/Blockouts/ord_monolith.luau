--!strict
-- Monolith (Order all-terrain heavy plasma artillery, T3): a broad armoured
-- body on four massive jointed legs with high knees and claw feet, a long heavy
-- plasma cannon (`barrel`, pitches) on its turret (`torso`). Laid out at bot
-- size and scaled x2.0. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.6, 1.1, 3 }, at = { 0, 2.6, 0 }, color = "hull" },
}
local visual = Bots.spider(parts, { legs = 4, hipR = 1.2, hipY = 2.6, kneeR = 3, kneeY = 4, footR = 3.9, thick = 0.5, color = "hull", team = true })
for _, p in {
	{ name = "skirt", parent = "base", shape = "box", size = { 2.8, 0.4, 3.2 }, at = { 0, 2, 0 }, color = "dark" },
	{ name = "torso", parent = "base", shape = "box", size = { 2.2, 1, 2.4 }, at = { 0, 3.65, 0.3 }, pivot = { 0, 3.15, 0.3 }, color = "team" },
	{ name = "glacis", parent = "torso", shape = "wedge", size = { 2.2, 0.8, 0.7 }, at = { 0, 3.55, -1.25 }, color = "hull" },
	{ name = "barrel", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 4.2 }, at = { 0, 3.8, -2.4 }, pivot = { 0, 3.8, -0.3 }, color = "metal" },
	{ name = "sleeve", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.85, 0.85, 1.2 }, at = { 0, 3.8, -0.9 }, color = "hull" },
	{ name = "coil1", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.15 }, at = { 0, 3.8, -1.9 }, color = "glass" },
	{ name = "coil2", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.15 }, at = { 0, 3.8, -2.7 }, color = "glass" },
	{ name = "mouth", parent = "barrel", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.4 }, at = { 0, 3.8, -4.4 }, color = "dark" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "ord_monolith",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 3.8, -4.65 } },
	},
}, 2)

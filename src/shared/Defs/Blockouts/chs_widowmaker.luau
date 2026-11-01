--!strict
-- Widowmaker (Chaos all-terrain assault spider mech, missiles, T3): an armoured
-- body on six long jointed legs with high knees and claws, a raised cockpit
-- turret (`torso`) with an amber eye slit and a missile pod on each side.
-- Laid out at bot size and scaled x1.8. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.4, 1.1, 3.2 }, at = { 0, 2.4, 0 }, color = "dark" },
}
local visual = Bots.spider(parts, { legs = 6, hipR = 1.1, hipY = 2.4, kneeR = 2.9, kneeY = 4.1, footR = 4, thick = 0.4, color = "hull" })
for _, p in {
	{ name = "abdomen", parent = "base", shape = "box", size = { 2, 1.2, 1.6 }, at = { 0, 2.6, 2.1 }, color = "hull" },
	{ name = "abdomenGlow", parent = "base", shape = "box", size = { 1.4, 0.1, 1 }, at = { 0, 3.22, 2.1 }, color = "glass" },
	{ name = "backSpike1", parent = "base", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { -0.6, 3.55, 2.5 }, color = "metal" },
	{ name = "backSpike2", parent = "base", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { 0.6, 3.55, 2.5 }, color = "metal" },
	{ name = "torso", parent = "base", shape = "box", size = { 1.8, 1.1, 1.8 }, at = { 0, 3.5, -0.4 }, pivot = { 0, 2.95, -0.2 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 1.2, 0.15, 0.06 }, at = { 0, 3.7, -1.33 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1, 0.08, 0.8 }, at = { 0, 4.07, -0.2 }, color = "team" },
	{ name = "podR", parent = "torso", shape = "box", size = { 0.8, 0.8, 1.4 }, at = { 1.3, 3.5, -0.5 }, color = "metal" },
	{ name = "cellR11", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { 1.13, 3.33, -1.22 }, color = "glass" },
	{ name = "cellR12", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { 1.13, 3.67, -1.22 }, color = "glass" },
	{ name = "cellR21", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { 1.47, 3.33, -1.22 }, color = "glass" },
	{ name = "cellR22", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { 1.47, 3.67, -1.22 }, color = "glass" },
	{ name = "podL", parent = "torso", shape = "box", size = { 0.8, 0.8, 1.4 }, at = { -1.3, 3.5, -0.5 }, color = "metal" },
	{ name = "cellL11", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { -1.47, 3.33, -1.22 }, color = "glass" },
	{ name = "cellL12", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { -1.47, 3.67, -1.22 }, color = "glass" },
	{ name = "cellL21", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { -1.13, 3.33, -1.22 }, color = "glass" },
	{ name = "cellL22", parent = "torso", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.12 }, at = { -1.13, 3.67, -1.22 }, color = "glass" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "chs_widowmaker",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 1.3, 3.5, -1.35 } },
		{ name = "muzzle2", parent = "torso", at = { -1.3, 3.5, -1.35 } },
	},
}, 1.8)

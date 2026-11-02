--!strict
-- Colossus (Chaos barely mobile walking fortress, three lasers, T3): a massive
-- block of armour on four stubby trunk legs (client pieces `legFL` .. `legBR`,
-- swinging at the hip like the Mammoth's), crowned by three laser turrets: a big
-- one on the `torso` and one at each front corner (`muzzle` .. `muzzle3`). Laid out
-- half size and scaled x2. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 8, 4, 8 }, at = { 0, 5, 0 }, color = "hull" },
}
local visual: { string } = {}
table.insert(visual, "legFL")
table.insert(visual, "legFR")
table.insert(visual, "legBL")
table.insert(visual, "legBR")
for _, p in {
	{ name = "legFL", parent = "base", shape = "box", size = { 2.2, 3.4, 2.2 }, at = { -3.2, 1.7, -3 }, pivot = { -3.2, 3.2, -3 }, color = "dark", anim = { motion = "swing", axis = { 1, 0, 0 } } },
	{ name = "footFL", parent = "legFL", shape = "box", size = { 2.8, 0.6, 2.8 }, at = { -3.2, 0.3, -3 }, color = "metal" },
	{ name = "legFR", parent = "base", shape = "box", size = { 2.2, 3.4, 2.2 }, at = { 3.2, 1.7, -3 }, pivot = { 3.2, 3.2, -3 }, color = "dark", anim = { motion = "swing", axis = { 1, 0, 0 } } },
	{ name = "footFR", parent = "legFR", shape = "box", size = { 2.8, 0.6, 2.8 }, at = { 3.2, 0.3, -3 }, color = "metal" },
	{ name = "legBL", parent = "base", shape = "box", size = { 2.2, 3.4, 2.2 }, at = { -3.2, 1.7, 3 }, pivot = { -3.2, 3.2, 3 }, color = "dark", anim = { motion = "swing", axis = { 1, 0, 0 } } },
	{ name = "footBL", parent = "legBL", shape = "box", size = { 2.8, 0.6, 2.8 }, at = { -3.2, 0.3, 3 }, color = "metal" },
	{ name = "legBR", parent = "base", shape = "box", size = { 2.2, 3.4, 2.2 }, at = { 3.2, 1.7, 3 }, pivot = { 3.2, 3.2, 3 }, color = "dark", anim = { motion = "swing", axis = { 1, 0, 0 } } },
	{ name = "footBR", parent = "legBR", shape = "box", size = { 2.8, 0.6, 2.8 }, at = { 3.2, 0.3, 3 }, color = "metal" },
	{ name = "skirt", parent = "base", shape = "box", size = { 8.6, 0.8, 8.6 }, at = { 0, 3.2, 0 }, color = "dark" },
	{ name = "glacis", parent = "base", shape = "wedge", size = { 8, 2, 1.6 }, at = { 0, 4.2, -4.8 }, color = "hull" },
	{ name = "teamL", parent = "base", shape = "box", size = { 0.08, 1.4, 5 }, at = { -4.04, 5.2, 0.5 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 0.08, 1.4, 5 }, at = { 4.04, 5.2, 0.5 }, color = "team" },
	{ name = "spike1", parent = "base", shape = "wedge", size = { 0.6, 1.4, 0.9 }, at = { -3, 7.7, 2.8 }, color = "metal" },
	{ name = "spike2", parent = "base", shape = "wedge", size = { 0.6, 1.4, 0.9 }, at = { 3, 7.7, 2.8 }, color = "metal" },
	{ name = "spike3", parent = "base", shape = "wedge", size = { 0.6, 1.4, 0.9 }, at = { -3, 7.7, -0.5 }, color = "metal" },
	{ name = "spike4", parent = "base", shape = "wedge", size = { 0.6, 1.4, 0.9 }, at = { 3, 7.7, -0.5 }, color = "metal" },
	{ name = "torso", parent = "base", shape = "box", size = { 3.6, 1.8, 3.6 }, at = { 0, 7.9, 0.6 }, pivot = { 0, 7, 0.6 }, color = "hull" },
	{ name = "turretTeam", parent = "torso", shape = "box", size = { 2.4, 0.08, 1.6 }, at = { 0, 8.82, 1.2 }, color = "team" },
	{ name = "laser", parent = "torso", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 3.2 }, at = { 0, 8, -2.8 }, color = "dark" },
	{ name = "laserTip", parent = "torso", shape = "cylinder", axis = "z", size = { 1.125, 1.125, 0.2 }, at = { 0, 8, -4.45 }, color = "glass" },
	{ name = "podL", parent = "base", shape = "box", size = { 1.6, 1.2, 1.8 }, at = { -2.9, 7.6, -2.6 }, color = "dark" },
	{ name = "podLaserL", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 1.4 }, at = { -2.9, 7.6, -4.2 }, color = "metal" },
	{ name = "podLaserLTip", parent = "base", shape = "cylinder", axis = "z", size = { 0.688, 0.688, 0.2 }, at = { -2.9, 7.6, -4.95 }, color = "glass" },
	{ name = "podR", parent = "base", shape = "box", size = { 1.6, 1.2, 1.8 }, at = { 2.9, 7.6, -2.6 }, color = "dark" },
	{ name = "podLaserR", parent = "base", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 1.4 }, at = { 2.9, 7.6, -4.2 }, color = "metal" },
	{ name = "podLaserRTip", parent = "base", shape = "cylinder", axis = "z", size = { 0.688, 0.688, 0.2 }, at = { 2.9, 7.6, -4.95 }, color = "glass" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "chs_colossus",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 8, -4.55 } },
		{ name = "muzzle2", parent = "base", at = { -2.9, 7.6, -5.05 } },
		{ name = "muzzle3", parent = "base", at = { 2.9, 7.6, -5.05 } },
	},
}, 2)

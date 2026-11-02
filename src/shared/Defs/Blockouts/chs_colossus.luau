--!strict
-- Colossus (Chaos barely mobile heavy turret, T3, footprint 5): a low, wide
-- fortress hull on four short trunk legs (client pieces `legFL` .. `legBR`,
-- swinging at the hip like the Mammoth's), crowned by a massive `torso` turret
-- built round one heavy cannon (`muzzle`, the D-Gun bolt), two lower lasers in
-- sponsons under it (`muzzle2` on the left) and a top laser in a cupola
-- (`muzzle3`); every weapon turns with the torso. Laid out half size and scaled
-- x2.5. Batch 2 of the BAR roster (2026-11-01), remodelled for S-236 (the user:
-- "it must be bigger... And a remodel too"). Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 10, 4, 10 }, at = { 0, 5, 0 }, color = "hull" },
}
local visual: { string } = {}
for _, tag in { "FL", "FR", "BL", "BR" } do
	table.insert(visual, "leg" .. tag)
end
local LEGS = { FL = { -4, -3.4 }, FR = { 4, -3.4 }, BL = { -4, 3.6 }, BR = { 4, 3.6 } }
for _, tag in { "FL", "FR", "BL", "BR" } do
	local x, z = LEGS[tag][1], LEGS[tag][2]
	table.insert(parts, { name = "leg" .. tag, parent = "base", shape = "box", size = { 2.8, 3.4, 2.8 }, at = { x, 1.7, z }, pivot = { x, 3.2, z }, color = "dark", anim = { motion = "swing", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = "foot" .. tag, parent = "leg" .. tag, shape = "box", size = { 3.6, 0.6, 3.6 }, at = { x, 0.3, z }, color = "metal" })
end
for _, p in {
	{ name = "skirt", parent = "base", shape = "box", size = { 10.8, 0.8, 10.6 }, at = { 0, 3.2, 0 }, color = "dark" },
	{ name = "glacis", parent = "base", shape = "wedge", size = { 9.6, 2, 1.6 }, at = { 0, 4.2, -5.8 }, color = "hull" },
	{ name = "teamL", parent = "base", shape = "box", size = { 0.08, 1.6, 6.4 }, at = { -5.04, 5, 0.4 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 0.08, 1.6, 6.4 }, at = { 5.04, 5, 0.4 }, color = "team" },
	{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 2.6, 0.9 }, at = { -2.6, 7.5, 5 }, color = "dark" },
	{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 2.6, 0.9 }, at = { 2.6, 7.5, 5 }, color = "dark" },
	{ name = "spike1", parent = "base", shape = "wedge", size = { 0.8, 1.8, 1 }, at = { -4, 7.9, 4 }, color = "metal" },
	{ name = "spike2", parent = "base", shape = "wedge", size = { 0.8, 1.8, 1 }, at = { 4, 7.9, 4 }, color = "metal" },
	{ name = "spike3", parent = "base", shape = "wedge", size = { 0.8, 1.8, 1 }, at = { -4, 7.9, 0.6 }, color = "metal" },
	{ name = "spike4", parent = "base", shape = "wedge", size = { 0.8, 1.8, 1 }, at = { 4, 7.9, 0.6 }, color = "metal" },
	{ name = "torso", parent = "base", shape = "box", size = { 6.8, 3.2, 6.2 }, at = { 0, 8.6, 0.5 }, pivot = { 0, 7, 0.6 }, color = "hull" },
	{ name = "turretTeam", parent = "torso", shape = "box", size = { 2.6, 0.08, 1.6 }, at = { -1.4, 10.24, 2.4 }, color = "team" },
	{ name = "mantlet", parent = "torso", shape = "box", size = { 3, 2.2, 1 }, at = { 0, 8.7, -2.45 }, color = "dark" },
	{ name = "cannon", parent = "torso", shape = "cylinder", axis = "z", size = { 1.44, 1.44, 6.2 }, at = { 0, 8.7, -6 }, color = "dark" },
	{ name = "cannonCoils", parent = "torso", shape = "cylinder", axis = "z", size = { 1.9, 1.9, 3.6 }, at = { 0, 8.7, -5.7 }, color = "metal" },
	{ name = "brake", parent = "torso", shape = "box", size = { 2, 1.3, 1.1 }, at = { 0, 8.7, -9.45 }, color = "dark" },
	{ name = "cannonTip", parent = "torso", shape = "cylinder", axis = "z", size = { 1.24, 1.24, 0.1 }, at = { 0, 8.7, -10.05 }, color = "glass" },
	{ name = "sponsonL", parent = "torso", shape = "box", size = { 1.4, 1.1, 1.6 }, at = { -2.5, 7.75, -2.2 }, color = "dark" },
	{ name = "laserL", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 1.9 }, at = { -2.5, 7.75, -3.95 }, color = "metal" },
	{ name = "laserLTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.75, 0.75, 0.2 }, at = { -2.5, 7.75, -4.9 }, color = "glass" },
	{ name = "sponsonR", parent = "torso", shape = "box", size = { 1.4, 1.1, 1.6 }, at = { 2.5, 7.75, -2.2 }, color = "dark" },
	{ name = "laserR", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 1.9 }, at = { 2.5, 7.75, -3.95 }, color = "metal" },
	{ name = "laserRTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.75, 0.75, 0.2 }, at = { 2.5, 7.75, -4.9 }, color = "glass" },
	{ name = "cupola", parent = "torso", shape = "cylinder", axis = "y", size = { 1.6, 0.5, 1.6 }, at = { 1.5, 10.45, 0.9 }, color = "dark" },
	{ name = "topLaser", parent = "torso", shape = "cylinder", axis = "z", size = { 0.48, 0.48, 1.8 }, at = { 1.5, 10.35, -1 }, color = "metal" },
	{ name = "topLaserTip", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.2 }, at = { 1.5, 10.35, -1.8 }, color = "glass" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "chs_colossus",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 8.7, -10.15 } },
		{ name = "muzzle2", parent = "torso", at = { -2.5, 7.75, -5 } },
		{ name = "muzzle3", parent = "torso", at = { 1.5, 10.35, -1.8 } },
	},
}, 2.5)

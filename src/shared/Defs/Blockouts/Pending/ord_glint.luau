--!strict
-- Glint (Order scout bot, T1, footprint 1; S-181): a slim fast runner on
-- long legs, a compact `torso` (turns) with a wedge cockpit and a team
-- stripe, and an `arm_l` / `arm_r` either side, each ending in a laser tube
-- with a lens (they fire in turn; `arm_l_muzzle` / `arm_r_muzzle` at the
-- lenses). Legs are client pieces (Bots.luau). Order reads clean (M-14).
-- Model space, forward = -Z.

local Bots = require("../Bots")

local AY = 3.9 -- the arms' height

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.6, 1.0 }, at = { 0, 2.95, 0 }, color = "hull" },
}
local legs = Bots.legs(parts, { hipY = 2.8, hipX = 0.55, thick = 0.45, color = "hull" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.8, 1.3, 1.6 }, at = { 0, 3.95, 0.2 }, pivot = { 0, 3.3, 0 }, color = "hull" },
	{ name = "cockpit", parent = "torso", shape = "wedge", size = { 1.6, 0.9, 0.9 }, at = { 0, 4.15, -1.05 }, color = "glass" },
	{ name = "stripe", parent = "torso", shape = "box", size = { 0.4, 0.06, 1.4 }, at = { 0, 4.63, 0.3 }, color = "team" },
	{ name = "fin", parent = "torso", shape = "box", size = { 0.1, 0.6, 0.9 }, at = { 0, 4.9, 0.7 }, color = "dark" },
	{ name = "arm_l", parent = "torso", shape = "box", size = { 0.5, 0.5, 1.8 }, at = { -1.2, AY, -0.5 }, pivot = { -1.1, AY, 0.2 }, color = "metal" },
	{ name = "tube_l", parent = "arm_l", shape = "cylinder", axis = "z", size = { 0.32, 0.32, 0.8 }, at = { -1.2, AY, -1.8 }, color = "dark" },
	{ name = "lens_l", parent = "arm_l", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.1 }, at = { -1.2, AY, -2.25 }, color = "glass" },
	{ name = "arm_r", parent = "torso", shape = "box", size = { 0.5, 0.5, 1.8 }, at = { 1.2, AY, -0.5 }, pivot = { 1.1, AY, 0.2 }, color = "metal" },
	{ name = "tube_r", parent = "arm_r", shape = "cylinder", axis = "z", size = { 0.32, 0.32, 0.8 }, at = { 1.2, AY, -1.8 }, color = "dark" },
	{ name = "lens_r", parent = "arm_r", shape = "cylinder", axis = "z", size = { 0.26, 0.26, 0.1 }, at = { 1.2, AY, -2.25 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_glint",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "arm_l_muzzle", parent = "arm_l", at = { -1.2, AY, -2.35 } },
		{ name = "arm_r_muzzle", parent = "arm_r", at = { 1.2, AY, -2.35 } },
	},
}

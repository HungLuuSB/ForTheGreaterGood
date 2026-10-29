--!strict
-- Mammoth (Chaos T2 armored assault bot, footprint 2; S-209): an armored
-- war elephant, heavier than the Fatboy. A long domed gunmetal body with
-- team flank slabs, an armored head low in front with team ear plates,
-- steel tusks and a trunk, exhaust stacks on the rump, on four thick pillar
-- legs (`legFL` / `legFR` / `legBL` / `legBR`, each jointed at the hip and
-- swinging for the walk). On its back the `turret` (turns) carries the
-- `barrels` (pitch) with two long laser barrels; `muzzleL` / `muzzleR` sit
-- at their lenses (small parts here: the blockout rules make only
-- `muzzle<n>` names Attachments). Chaos reads heavy and brutal (M-14).
-- Model space, forward = -Z.

local SWING = { motion = "swing", axis = { 1, 0, 0 } }
local HIP_Y = 5.6
local GUN_Y, GUN_Z, BX, MZ = 10.15, -0.9, 1.0, -6.75

local parts: { any } = {
	{ name = "base", shape = "box", size = { 8.2, 4.4, 12.0 }, at = { 0, 6.9, -0.2 }, color = "hull" },
	{ name = "belly", parent = "base", shape = "box", size = { 6.6, 0.6, 10.8 }, at = { 0, 4.45, -0.2 }, color = "dark" },
	{ name = "flankL", parent = "base", shape = "box", size = { 0.4, 2.7, 10.4 }, at = { -4.25, 6.35, -0.2 }, color = "team" },
	{ name = "flankR", parent = "base", shape = "box", size = { 0.4, 2.7, 10.4 }, at = { 4.25, 6.35, -0.2 }, color = "team" },
	{ name = "head", parent = "base", shape = "box", size = { 4.4, 3.6, 2.6 }, at = { 0, 6.7, -6.9 }, color = "hull" },
	{ name = "crest", parent = "base", shape = "box", size = { 1.0, 0.5, 1.8 }, at = { 0, 8.6, -7.1 }, color = "team" },
	{ name = "earL", parent = "base", shape = "box", size = { 0.25, 3.0, 2.6 }, at = { -2.75, 7.0, -6.0 }, rot = { 0, -20, 0 }, color = "team" },
	{ name = "earR", parent = "base", shape = "box", size = { 0.25, 3.0, 2.6 }, at = { 2.75, 7.0, -6.0 }, rot = { 0, 20, 0 }, color = "team" },
	{ name = "eyeL", parent = "base", shape = "box", size = { 0.6, 0.18, 0.06 }, at = { -1.3, 7.3, -8.22 }, color = "glass" },
	{ name = "eyeR", parent = "base", shape = "box", size = { 0.6, 0.18, 0.06 }, at = { 1.3, 7.3, -8.22 }, color = "glass" },
	{ name = "tuskL", parent = "base", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 2.4 }, at = { -1.55, 4.8, -8.6 }, rot = { -20, 0, 0 }, color = "metal" },
	{ name = "tuskR", parent = "base", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 2.4 }, at = { 1.55, 4.8, -8.6 }, rot = { -20, 0, 0 }, color = "metal" },
	{ name = "trunk", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 3.6, 1.2 }, at = { 0, 4.0, -8.35 }, color = "dark" },
	{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 0.76, 2.2, 0.76 }, at = { -2.3, 9.9, 4.6 }, color = "dark" },
	{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 0.76, 2.2, 0.76 }, at = { 2.3, 9.9, 4.6 }, color = "dark" },
	{ name = "vent", parent = "base", shape = "box", size = { 3.2, 1.4, 0.1 }, at = { 0, 7.2, 6.0 }, color = "glass" },
	{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 5.8, 0.3, 5.8 }, at = { 0, 9.2, 0.6 }, color = "metal" },
}
for _, leg in { { "FL", -3.15, -3.6 }, { "FR", 3.15, -3.6 }, { "BL", -3.15, 3.5 }, { "BR", 3.15, 3.5 } } do
	local key, x, z = leg[1], leg[2], leg[3]
	local name = `leg{key}`
	table.insert(parts, { name = name, parent = "base", shape = "box", size = { 2.3, HIP_Y, 2.3 }, at = { x, HIP_Y / 2 + 0.3, z }, pivot = { x, HIP_Y, z }, color = "hull", anim = SWING })
	table.insert(parts, { name = `{name}Team`, parent = name, shape = "box", size = { 1.5, 2.2, 0.08 }, at = { x, 4.3, z - 1.2 }, color = "team" })
	table.insert(parts, { name = `{name}Foot`, parent = name, shape = "cylinder", axis = "y", size = { 3.2, 0.7, 3.2 }, at = { x, 0.35, z }, color = "dark" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 5.2, 1.8, 4.8 }, at = { 0, 10.2, 1.45 }, pivot = { 0, 9.1, 0.6 }, color = "hull" },
	{ name = "turretTeam", parent = "turret", shape = "box", size = { 3.0, 0.08, 2.4 }, at = { 0, 11.14, 1.4 }, color = "team" },
	{ name = "barrels", parent = "turret", shape = "box", size = { 3.8, 1.7, 2.2 }, at = { 0, GUN_Y, GUN_Z - 0.1 }, pivot = { 0, GUN_Y, GUN_Z }, color = "dark" },
	{ name = "barrelL", parent = "barrels", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 4.8 }, at = { -BX, GUN_Y, -4.1 }, color = "metal" },
	{ name = "barrelR", parent = "barrels", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 4.8 }, at = { BX, GUN_Y, -4.1 }, color = "metal" },
	{ name = "muzzleL", parent = "barrels", shape = "cylinder", axis = "z", size = { 0.92, 0.92, 0.5 }, at = { -BX, GUN_Y, MZ + 0.3 }, color = "glass" },
	{ name = "muzzleR", parent = "barrels", shape = "cylinder", axis = "z", size = { 0.92, 0.92, 0.5 }, at = { BX, GUN_Y, MZ + 0.3 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_mammoth",
	parts = parts,
}

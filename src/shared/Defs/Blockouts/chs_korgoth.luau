--!strict
-- Juggernaut (chs_korgoth, Chaos T3 assault mech, footprint 3; S-209,
-- BAR's corkorg): a huge boxy chest of team armor slabs on a gunmetal
-- frame, slab pauldrons, a reactor hump with exhaust stacks, the
-- vertical-launch `missile_pod` on the right shoulder, on thick slab legs
-- (the leg kit, Bots.luau: here the def's own pieces). The `torso` turns;
-- the helmet is the heat ray (`ray_arm` pitches, `ray_muzzle` at its
-- lens); each arm (`gunL`, `gunR`) pitches at the shoulder and ends in a
-- double-barrelled shotgun cannon (`gun{L,R}_muzzle1` / `2`). Laid out at
-- the Commander's size and scaled x2.15 like its mesh (about 23 studs
-- tall). Chaos reads heavy and brutal (M-14). Model space, forward = -Z.

local Bots = require("./Bots")

local S = 2.15
local ARM_Y, ARM_X, FORE_Y = 8.0, 3.55, 5.0

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.7, 1.35, 2.3 }, at = { 0, 4.5, 0 }, color = "dark" },
	{ name = "cod", parent = "base", shape = "wedge", size = { 2.0, 1.3, 0.55 }, at = { 0, 4.4, -1.35 }, color = "hull" },
}
Bots.legs(parts, { hipY = 4.5, hipX = 1.95, thick = 1.45, color = "hull", team = true })
local function gun(side: string, sx: number): { any }
	local x = sx * ARM_X
	local name = `gun{side}`
	return {
		{ name = name, parent = "torso", shape = "box", size = { 1.6, 1.6, 1.5 }, at = { x, 6.8, 0 }, pivot = { sx * 3.35, ARM_Y, 0 }, color = "dark" },
		{ name = `{name}Body`, parent = name, shape = "box", size = { 2.0, 1.6, 3.2 }, at = { x, FORE_Y, -0.2 }, color = "hull" },
		{ name = `{name}Team`, parent = name, shape = "box", size = { 0.06, 1.1, 2.2 }, at = { x + sx * 1.03, FORE_Y, -0.2 }, color = "team" },
		{ name = `{name}Barrel1`, parent = name, shape = "cylinder", axis = "z", size = { 0.6, 0.6, 2.4 }, at = { x - 0.36, FORE_Y, -2.9 }, color = "dark" },
		{ name = `{name}Barrel2`, parent = name, shape = "cylinder", axis = "z", size = { 0.6, 0.6, 2.4 }, at = { x + 0.36, FORE_Y, -2.9 }, color = "dark" },
		{ name = `{name}Sleeve1`, parent = name, shape = "cylinder", axis = "z", size = { 0.76, 0.76, 1.0 }, at = { x - 0.36, FORE_Y, -3.6 }, color = "metal" },
		{ name = `{name}Sleeve2`, parent = name, shape = "cylinder", axis = "z", size = { 0.76, 0.76, 1.0 }, at = { x + 0.36, FORE_Y, -3.6 }, color = "metal" },
	}
end
for _, list in {
	{
		{ name = "torso", parent = "base", shape = "box", size = { 4.5, 2.7, 2.6 }, at = { 0, 7.75, 0.1 }, pivot = { 0, 5.2, 0 }, color = "hull" },
		{ name = "waist", parent = "torso", shape = "cylinder", axis = "y", size = { 1.7, 1.2, 1.7 }, at = { 0, 5.9, 0 }, color = "metal" },
		{ name = "chest", parent = "torso", shape = "box", size = { 4.4, 2.0, 0.85 }, at = { 0, 8.25, -1.6 }, color = "team" },
		{ name = "belly", parent = "torso", shape = "box", size = { 3.4, 1.0, 0.75 }, at = { 0, 6.75, -1.55 }, color = "team" },
		{ name = "padL", parent = "torso", shape = "box", size = { 2.5, 2.1, 3.6 }, at = { -3.6, 8.7, 0 }, color = "hull" },
		{ name = "padR", parent = "torso", shape = "box", size = { 2.5, 2.1, 3.6 }, at = { 3.6, 8.7, 0 }, color = "hull" },
		{ name = "padTeamL", parent = "torso", shape = "box", size = { 2.0, 0.75, 0.1 }, at = { -3.6, 8.7, -1.85 }, color = "team" },
		{ name = "padTeamR", parent = "torso", shape = "box", size = { 2.0, 0.75, 0.1 }, at = { 3.6, 8.7, -1.85 }, color = "team" },
		{ name = "hump", parent = "torso", shape = "box", size = { 2.6, 2.6, 1.4 }, at = { -0.55, 7.8, 2.0 }, color = "dark" },
		{ name = "humpGlow", parent = "torso", shape = "box", size = { 2.0, 0.22, 0.06 }, at = { -0.55, 7.6, 2.72 }, color = "glass" },
		{ name = "stack", parent = "torso", shape = "cylinder", axis = "y", size = { 0.56, 1.8, 0.56 }, at = { -1.45, 9.7, 1.9 }, color = "dark" },
		{ name = "missile_pod", parent = "torso", shape = "box", size = { 1.8, 1.75, 1.8 }, at = { 1.75, 10.1, 1.35 }, pivot = { 1.75, 11.0, 1.35 }, color = "hull" },
		{ name = "podTeam", parent = "missile_pod", shape = "box", size = { 1.9, 0.4, 1.9 }, at = { 1.75, 10.45, 1.35 }, color = "team" },
		{ name = "podCells", parent = "missile_pod", shape = "box", size = { 1.2, 0.06, 1.2 }, at = { 1.75, 11.0, 1.35 }, color = "glass" },
		{ name = "ray_arm", parent = "torso", shape = "box", size = { 1.45, 1.05, 2.0 }, at = { 0, 9.45, -1.0 }, pivot = { 0, 9.25, -0.7 }, color = "hull" },
		{ name = "crest", parent = "ray_arm", shape = "box", size = { 0.44, 0.6, 1.4 }, at = { 0, 10.3, -0.9 }, color = "team" },
		{ name = "rayEmitter", parent = "ray_arm", shape = "cylinder", axis = "z", size = { 0.84, 0.84, 1.0 }, at = { 0, 9.35, -1.85 }, color = "metal" },
		{ name = "rayLens", parent = "ray_arm", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.08 }, at = { 0, 9.35, -2.12 }, color = "glass" },
	},
	gun("L", -1),
	gun("R", 1),
} do
	for _, p in list do
		table.insert(parts, p)
	end
end

return require("./Scale").scaled({
	id = "chs_korgoth",
	parts = parts,
	attachments = {
		{ name = "ray_muzzle", parent = "ray_arm", at = { 0, 9.35, -2.15 } },
		{ name = "gunL_muzzle1", parent = "gunL", at = { -ARM_X - 0.36, FORE_Y, -4.25 } },
		{ name = "gunL_muzzle2", parent = "gunL", at = { -ARM_X + 0.36, FORE_Y, -4.25 } },
		{ name = "gunR_muzzle1", parent = "gunR", at = { ARM_X - 0.36, FORE_Y, -4.25 } },
		{ name = "gunR_muzzle2", parent = "gunR", at = { ARM_X + 0.36, FORE_Y, -4.25 } },
	},
}, S)

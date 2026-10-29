--!strict
-- Titan (Order T3 assault mech, footprint 3; S-209, BAR's armbanth): a
-- broad armored chest with a jutting front block and a sensor head, huge
-- team shoulder pads, a backpack, the vertical-launch `missile_pod` on the
-- left shoulder, on thick legs (the leg kit, Bots.luau: here the def's own
-- pieces). The `torso` turns; the arms pitch at the shoulders: the right
-- `beam_arm` holds the tachyon cannon (`beam_muzzle`), the left
-- `blaster_arm` twin blasters (`blaster_muzzle1` / `2`). Laid out at the
-- Commander's size and scaled x2.1 like its mesh (about 22 studs tall).
-- Order reads clean and heavy (M-14). Model space, forward = -Z.

local Bots = require("./Bots")

local S = 2.1
local ARM_Y, FORE_Y = 7.8, 5.0

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.5, 1.3, 2.1 }, at = { 0, 4.65, 0 }, color = "dark" },
	{ name = "cod", parent = "base", shape = "wedge", size = { 1.8, 1.2, 0.5 }, at = { 0, 4.5, -1.25 }, color = "hull" },
}
Bots.legs(parts, { hipY = 4.6, hipX = 1.75, thick = 1.3, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 3.4, 2.0, 2.4 }, at = { 0, 7.5, 0 }, pivot = { 0, 5.3, 0 }, color = "hull" },
	{ name = "waist", parent = "torso", shape = "cylinder", axis = "y", size = { 1.5, 1.2, 1.5 }, at = { 0, 6.0, 0 }, color = "metal" },
	{ name = "front", parent = "torso", shape = "box", size = { 2.3, 2.3, 1.2 }, at = { 0, 7.15, -1.75 }, color = "dark" },
	{ name = "slitL", parent = "torso", shape = "box", size = { 0.22, 1.15, 0.06 }, at = { -0.32, 7.3, -2.38 }, color = "glass" },
	{ name = "slitR", parent = "torso", shape = "box", size = { 0.22, 1.15, 0.06 }, at = { 0.32, 7.3, -2.38 }, color = "glass" },
	{ name = "frontTeam", parent = "torso", shape = "box", size = { 1.9, 0.38, 0.06 }, at = { 0, 6.3, -2.38 }, color = "team" },
	{ name = "head", parent = "torso", shape = "box", size = { 1.5, 0.85, 1.4 }, at = { 0, 8.85, -0.45 }, color = "hull" },
	{ name = "lens", parent = "torso", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.1 }, at = { 0, 8.85, -1.2 }, color = "glass" },
	{ name = "padL", parent = "torso", shape = "box", size = { 2.65, 2.0, 3.7 }, at = { -3.7, 8.6, 0 }, color = "team" },
	{ name = "padR", parent = "torso", shape = "box", size = { 2.65, 2.0, 3.7 }, at = { 3.7, 8.6, 0 }, color = "team" },
	{ name = "pack", parent = "torso", shape = "box", size = { 3.0, 2.4, 1.6 }, at = { 0.5, 7.5, 2.0 }, color = "dark" },
	{ name = "packGlow", parent = "torso", shape = "box", size = { 2.2, 0.2, 0.06 }, at = { 0.5, 8.55, 2.82 }, color = "glass" },
	{ name = "antenna", parent = "torso", shape = "cylinder", axis = "y", size = { 0.14, 2.4, 0.14 }, at = { 1.45, 9.6, 2.2 }, color = "dark" },
	{ name = "missile_pod", parent = "torso", shape = "cylinder", axis = "y", size = { 1.65, 2.4, 1.65 }, at = { -1.55, 9.1, 1.45 }, pivot = { -1.55, 10.5, 1.45 }, color = "hull" },
	{ name = "podTeam", parent = "missile_pod", shape = "cylinder", axis = "y", size = { 1.76, 0.4, 1.76 }, at = { -1.55, 10.0, 1.45 }, color = "team" },
	{ name = "podCells", parent = "missile_pod", shape = "cylinder", axis = "y", size = { 1.3, 0.06, 1.3 }, at = { -1.55, 10.32, 1.45 }, color = "glass" },
	-- the right arm: the tachyon cannon
	{ name = "beam_arm", parent = "torso", shape = "box", size = { 1.5, 1.6, 1.3 }, at = { 3.5, 6.7, 0 }, pivot = { 3.3, ARM_Y, 0 }, color = "hull" },
	{ name = "beamBody", parent = "beam_arm", shape = "box", size = { 1.7, 1.5, 3.0 }, at = { 3.5, FORE_Y, -0.25 }, color = "hull" },
	{ name = "beamTeam", parent = "beam_arm", shape = "box", size = { 0.06, 1.0, 2.2 }, at = { 4.38, FORE_Y, -0.2 }, color = "team" },
	{ name = "beamBarrel", parent = "beam_arm", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 2.6 }, at = { 3.5, FORE_Y, -3.0 }, color = "metal" },
	{ name = "beamCoil", parent = "beam_arm", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 0.25 }, at = { 3.5, FORE_Y, -3.2 }, color = "glass" },
	{ name = "beamMouth", parent = "beam_arm", shape = "cylinder", axis = "z", size = { 1.5, 1.5, 0.55 }, at = { 3.5, FORE_Y, -4.85 }, color = "dark" },
	-- the left arm: twin plasma blasters
	{ name = "blaster_arm", parent = "torso", shape = "box", size = { 1.5, 1.6, 1.3 }, at = { -3.5, 6.7, 0 }, pivot = { -3.3, ARM_Y, 0 }, color = "hull" },
	{ name = "blastBody", parent = "blaster_arm", shape = "box", size = { 1.9, 1.5, 2.8 }, at = { -3.5, FORE_Y, -0.15 }, color = "hull" },
	{ name = "blastTeam", parent = "blaster_arm", shape = "box", size = { 0.06, 1.0, 2.1 }, at = { -4.48, FORE_Y, -0.2 }, color = "team" },
	{ name = "blastL", parent = "blaster_arm", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 2.4 }, at = { -3.86, FORE_Y, -2.8 }, color = "metal" },
	{ name = "blastR", parent = "blaster_arm", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 2.4 }, at = { -3.14, FORE_Y, -2.8 }, color = "metal" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "ord_titan",
	parts = parts,
	attachments = {
		{ name = "beam_muzzle", parent = "beam_arm", at = { 3.5, FORE_Y, -5.2 } },
		{ name = "blaster_muzzle1", parent = "blaster_arm", at = { -3.86, FORE_Y, -4.05 } },
		{ name = "blaster_muzzle2", parent = "blaster_arm", at = { -3.14, FORE_Y, -4.05 } },
	},
}, S)

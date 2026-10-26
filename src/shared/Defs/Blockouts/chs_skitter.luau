--!strict
-- Skitter (Chaos scout bot, T1, footprint 1; S-181; the fastest thing on
-- legs): a low four-legged crawler. A dark body pod with a glowing abdomen,
-- four splayed legs (client pieces `thighFL` / `thighFR` / `thighBL` /
-- `thighBR`, each with its `shin..` below the knee, swinging like the
-- walkers' legs, rig.md 10; knees high like a spider's), and on top the `torso` (turns): a small head
-- with an amber eye and a plasma snout; `muzzle` at its glowing mouth.
-- Chaos reads crude (M-14). Model space, forward = -Z.

local HIP_R, HIP_Y = 0.9, 2.1 -- hips: distance out from the body's axis, height
local KNEE_R, KNEE_Y = 2.2, 2.9
local FOOT_R, FOOT_Y = 2.7, 0.15

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.9, 2.4 }, at = { 0, 2.0, 0 }, color = "dark" },
	{ name = "abdomen", parent = "base", shape = "box", size = { 1.4, 1.0, 1.4 }, at = { 0, 2.25, 1.75 }, color = "hull" },
	{ name = "abdomenGlow", parent = "base", shape = "box", size = { 1.0, 0.1, 1.0 }, at = { 0, 2.8, 1.75 }, color = "glass" },
	{ name = "backTeam", parent = "base", shape = "box", size = { 1.2, 0.08, 1.0 }, at = { 0, 2.49, 0.4 }, color = "team" },
}
-- one leg segment from a to b (both on the leg's own vertical plane at
-- yaw `a`): a box whose Y axis runs a → b
local function segment(name: string, parent: string, yaw: number, r0: number, y0: number, r1: number, y1: number, size: number, color: string, pivot: { number }?)
	local u = { math.sin(math.rad(yaw)), math.cos(math.rad(yaw)) }
	local dr, dy = r1 - r0, y1 - y0
	local len = math.sqrt(dr * dr + dy * dy)
	local tilt = math.deg(math.atan2(dr, dy)) -- leans the box's Y axis outward
	local rm, ym = (r0 + r1) / 2, (y0 + y1) / 2
	table.insert(parts, { name = name, parent = parent, shape = "box", size = { size, len, size }, at = { u[1] * rm, ym, u[2] * rm }, rot = { tilt, yaw, 0 }, pivot = pivot, color = color, anim = if pivot then { motion = "swing", axis = { 1, 0, 0 } } else nil })
end
local legs = {}
for _, leg in { { "FL", 225 }, { "FR", 135 }, { "BL", 315 }, { "BR", 45 } } do
	local name, yaw = `thigh{leg[1]}`, leg[2]
	local u = { math.sin(math.rad(yaw)), math.cos(math.rad(yaw)) }
	segment(name, "base", yaw, HIP_R, HIP_Y, KNEE_R, KNEE_Y, 0.35, "hull", { u[1] * HIP_R, HIP_Y, u[2] * HIP_R })
	segment(`shin{leg[1]}`, name, yaw, KNEE_R, KNEE_Y, FOOT_R, FOOT_Y, 0.3, "metal", { u[1] * KNEE_R, KNEE_Y, u[2] * KNEE_R })
	table.insert(parts, { name = `knee{leg[1]}`, parent = `shin{leg[1]}`, shape = "ball", size = { 0.4, 0.4, 0.4 }, at = { u[1] * KNEE_R, KNEE_Y, u[2] * KNEE_R }, color = "metal" })
	table.insert(legs, name)
	table.insert(legs, `shin{leg[1]}`)
end
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 1.3, 0.9, 1.6 }, at = { 0, 2.85, -0.4 }, pivot = { 0, 2.45, 0 }, color = "hull" },
	{ name = "eye", parent = "torso", shape = "box", size = { 0.8, 0.18, 0.1 }, at = { 0, 3.05, -1.22 }, color = "glass" },
	{ name = "snout", parent = "torso", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 1.2 }, at = { 0, 2.7, -1.7 }, color = "metal" },
	{ name = "mouth", parent = "torso", shape = "cylinder", axis = "z", size = { 0.45, 0.45, 0.1 }, at = { 0, 2.7, -2.32 }, color = "glass" },
	{ name = "spineA", parent = "torso", shape = "wedge", size = { 0.2, 0.6, 0.6 }, at = { 0, 3.55, -0.2 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_skitter",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 2.7, -2.45 } },
	},
}

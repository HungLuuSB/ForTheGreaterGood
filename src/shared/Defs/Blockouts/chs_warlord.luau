--!strict
-- Warlord (Chaos Commander, M-32): a heroic walking battle mech, rugged and
-- aggressive (the review of v1: higher, bigger, not a box robot). About 2.6x
-- a Lancer's height to the shoulders' top (8.9 studs; stacks and banner to
-- 11), pauldrons spanning about 10.4 studs; footprint 2. Long, deeply bent
-- legs (a forward knee over a raked shin) with exposed pistons and splayed
-- clawed feet; a narrow pelvis under a broad hunched chest leaning forward
-- with reactive blocks; a heavy sensor head thrust forward and up out of the
-- chest with amber eye slits; big slab pauldrons past the body; a reactor
-- hump with twin exhaust stacks and a banner mast with the team banner; long
-- arms reaching below the waist: the crane-like claw arm with the build
-- emitter (`nano`) and a heavy gun (`forearmR`, `muzzle`). Original design.
-- Model space, forward = -Z. The v1 mech is kept in Review/.
--
-- Rig (rig.md 10, walkers): the same pieces as v1.

local SWING = { motion = "swing", axis = { 1, 0, 0 } }

local parts = {}
local function add(p)
	table.insert(parts, p)
end

local function limb(name: string, parent: string, a: { number }, b: { number }, w: number, d: number, color: string, extra: { [string]: any }?)
	local dy, dz = b[2] - a[2], b[3] - a[3]
	local p: { [string]: any } = {
		name = name, parent = parent, shape = "box",
		size = { w, math.sqrt(dy * dy + dz * dz), d },
		at = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 },
		rot = { math.deg(math.atan2(dz, dy)), 0, 0 },
		color = color,
	}
	for k, v in extra or {} do
		p[k] = v
	end
	add(p)
end

-- pelvis: a narrow armored slab
add({ name = "base", shape = "box", size = { 2.4, 1.0, 1.7 }, at = { 0, 4.45, 0.2 }, color = "dark" })
add({ name = "hipAxle", parent = "base", shape = "cylinder", axis = "x", size = { 3.6, 0.65, 0.65 }, at = { 0, 4.3, 0.25 }, color = "metal" })
add({ name = "groin", parent = "base", shape = "box", size = { 1.6, 0.8, 0.3 }, at = { 0, 4.2, -0.75 }, color = "hull" })

-- torso: leaning forward 18 degrees, broad hunched chest, reactive blocks, reactor hump
add({ name = "torso", parent = "base", shape = "cylinder", axis = "y", size = { 1.7, 0.7, 1.7 }, at = { 0, 5.2, 0.1 }, pivot = { 0, 5.0, 0.1 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } })
add({ name = "belly", parent = "torso", shape = "box", size = { 2.8, 1.0, 2.0 }, at = { 0, 5.9, -0.1 }, rot = { 18, 0, 0 }, color = "dark" })
add({ name = "chest", parent = "torso", shape = "box", size = { 4.6, 1.8, 2.8 }, at = { 0, 7.1, -0.4 }, rot = { 18, 0, 0 }, color = "hull" })
for i, x in { -1.3, 0, 1.3 } do
	add({ name = `era{i}`, parent = "torso", shape = "box", size = { 1.1, 0.7, 0.35 }, at = { x, 6.85, -1.95 }, rot = { 18, 0, 0 }, color = "dark" })
end
add({ name = "coreSlit", parent = "torso", shape = "box", size = { 2.0, 0.18, 0.1 }, at = { 0, 6.3, -1.75 }, rot = { 18, 0, 0 }, color = "glass" })
add({ name = "hump", parent = "torso", shape = "box", size = { 3.6, 1.8, 2.0 }, at = { 0, 7.9, 1.3 }, color = "dark" })
add({ name = "humpTeam", parent = "torso", shape = "box", size = { 2.0, 0.08, 1.2 }, at = { 0, 8.84, 1.2 }, color = "team" })
for i, x in { -1.0, 1.0 } do
	add({ name = `stack{i}`, parent = "torso", shape = "cylinder", axis = "y", size = { 0.6, 2.2, 0.6 }, at = { x, 9.6, 1.9 }, color = "metal" })
end
add({ name = "mast", parent = "torso", shape = "cylinder", axis = "y", size = { 0.16, 3.6, 0.16 }, at = { 1.9, 9.6, 2.0 }, color = "metal" })
add({ name = "banner", parent = "torso", shape = "box", size = { 0.06, 1.8, 1.3 }, at = { 1.9, 10.4, 2.7 }, color = "team" })
-- slab pauldrons past the body
for _, sx in { -1, 1 } do
	local n = if sx < 0 then "L" else "R"
	add({ name = `pauldron{n}`, parent = "torso", shape = "box", size = { 2.5, 1.6, 3.2 }, at = { sx * 3.95, 8.0, -0.2 }, rot = { 10, 0, sx * -8 }, color = "dark" })
	add({ name = `pauldronEra{n}`, parent = "torso", shape = "box", size = { 2.1, 0.7, 0.4 }, at = { sx * 3.95, 7.75, -1.85 }, rot = { 10, 0, 0 }, color = "hull" })
end
add({ name = "shoulderTeamR", parent = "torso", shape = "box", size = { 1.8, 0.08, 2.2 }, at = { 3.95, 8.85, -0.3 }, rot = { 10, 0, -8 }, color = "team" })

-- head: thrust forward and up out of the chest, amber eye slits
add({ name = "head", parent = "torso", shape = "box", size = { 1.4, 0.95, 1.4 }, at = { 0, 8.25, -1.85 }, pivot = { 0, 7.9, -1.3 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } })
add({ name = "jaw", parent = "head", shape = "box", size = { 1.1, 0.4, 0.5 }, at = { 0, 7.75, -2.35 }, color = "hull" })
add({ name = "eyeL", parent = "head", shape = "box", size = { 0.42, 0.1, 0.06 }, at = { -0.32, 8.35, -2.56 }, color = "glass" })
add({ name = "eyeR", parent = "head", shape = "box", size = { 0.42, 0.1, 0.06 }, at = { 0.32, 8.35, -2.56 }, color = "glass" })

-- left arm: the crane-like claw arm with the build emitter
add({ name = "armL", parent = "torso", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { -3.4, 7.2, -0.3 }, pivot = { -3.4, 7.2, -0.3 }, color = "metal", anim = SWING })
limb("upperArmL", "armL", { -3.5, 6.9, -0.3 }, { -3.5, 5.1, 0 }, 0.9, 1.0, "dark")
limb("nano", "armL", { -3.5, 5.0, 0 }, { -3.5, 3.4, -1.8 }, 0.7, 0.7, "dark", { pivot = { -3.5, 5.0, 0 } })
add({ name = "clawA", parent = "nano", shape = "box", size = { 0.2, 0.9, 0.7 }, at = { -3.78, 3.2, -2.1 }, rot = { 0, 0, 15 }, color = "metal" })
add({ name = "clawB", parent = "nano", shape = "box", size = { 0.2, 0.9, 0.7 }, at = { -3.22, 3.2, -2.1 }, rot = { 0, 0, -15 }, color = "metal" })
add({ name = "emitter", parent = "nano", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { -3.5, 3.25, -2.1 }, color = "glass" })

-- right arm: a heavy gun below the waist
add({ name = "armR", parent = "torso", shape = "ball", size = { 1.4, 1.4, 1.4 }, at = { 3.4, 7.2, -0.3 }, pivot = { 3.4, 7.2, -0.3 }, color = "metal", anim = SWING })
limb("upperArmR", "armR", { 3.5, 6.9, -0.3 }, { 3.5, 5.1, 0 }, 1.0, 1.1, "dark")
add({ name = "forearmR", parent = "armR", shape = "box", size = { 1.7, 1.6, 3.0 }, at = { 3.6, 4.45, -1.0 }, pivot = { 3.5, 5.1, 0 }, color = "dark", anim = SWING })
add({ name = "gun", parent = "forearmR", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 1.4 }, at = { 3.6, 4.35, -3.1 }, color = "metal" })

-- legs: a forward knee over a raked shin, exposed pistons, splayed clawed feet
for _, sx in { -1, 1 } do
	local n = if sx < 0 then "L" else "R"
	local x = sx * 1.7
	add({ name = `hip{n}`, parent = "base", shape = "box", size = { 0.9, 1.0, 1.2 }, at = { sx * 1.65, 4.3, 0.25 }, pivot = { sx * 1.5, 4.3, 0.25 }, color = "metal", anim = SWING })
	limb(`thigh{n}`, `hip{n}`, { x, 4.2, 0.3 }, { x, 2.5, -0.85 }, 1.3, 1.3, "dark", { pivot = { x, 4.2, 0.3 }, anim = SWING })
	add({ name = `thighPiston{n}`, parent = `thigh{n}`, shape = "cylinder", axis = "y", size = { 0.22, 1.8, 0.22 }, at = { x + sx * 0.75, 3.4, 0.0 }, color = "metal" })
	limb(`shin{n}`, `thigh{n}`, { x, 2.5, -0.85 }, { x, 0.75, 0.45 }, 1.2, 1.2, "hull", { pivot = { x, 2.5, -0.85 }, anim = SWING })
	add({ name = `kneePlate{n}`, parent = `shin{n}`, shape = "box", size = { 1.1, 0.8, 0.35 }, at = { x, 2.4, -1.45 }, rot = { 30, 0, 0 }, color = "dark" })
	add({ name = `calfPiston{n}`, parent = `shin{n}`, shape = "cylinder", axis = "y", size = { 0.2, 1.6, 0.2 }, at = { x, 1.6, 0.55 }, rot = { 37, 0, 0 }, color = "metal" })
	add({ name = `foot{n}`, parent = `shin{n}`, shape = "box", size = { 1.1, 0.5, 1.0 }, at = { x, 0.5, 0.45 }, pivot = { x, 0.7, 0.45 }, color = "dark", anim = SWING })
	add({ name = `toes{n}`, parent = `foot{n}`, shape = "box", size = { 1.5, 0.4, 1.4 }, at = { x, 0.2, -0.6 }, color = "metal" })
	add({ name = `spur{n}`, parent = `foot{n}`, shape = "box", size = { 0.6, 0.4, 0.9 }, at = { x, 0.2, 1.2 }, color = "metal" })
end

return {
	id = "chs_warlord",
	visualPieces = { "torso", "head", "armL", "armR", "forearmR", "hipL", "thighL", "shinL", "footL", "hipR", "thighR", "shinR", "footR" },
	parts = parts,
	attachments = {
		{ name = "nano1", parent = "nano", at = { -3.5, 3.25, -2.45 } }, -- nanoframe anchor (M-25)
		{ name = "muzzle", parent = "forearmR", at = { 3.6, 4.35, -4.72 } },
	},
}

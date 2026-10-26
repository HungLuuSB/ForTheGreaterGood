--!strict
-- Sovereign (Order Commander, M-32): a heroic walking battle mech, the hero
-- unit (the review of v1: higher, bigger, not a box robot). About 2.7x a
-- Lancer's height (9.6 studs to the top of the head), pauldrons spanning
-- about 9.9 studs; footprint 2. Long legs (45% of the height) with a real
-- knee bend and compact armored feet with toe and heel plates; a narrow
-- armored waist under a broad chest (V shape) with the cyan command core; a
-- sensor head standing up out of the torso; big pauldrons past the body with
-- the team plates; a reactor backpack; long arms reaching below the waist:
-- the build arm (`nano`, the emitter at the end) and a big weapon pod
-- (`forearmR`, `muzzle`). Upright, noble stance. Original design. Model
-- space, forward = -Z. The v1 mech is kept in Review/.
--
-- Rig (rig.md 10, walkers): the same pieces as v1; `torso` is a def piece
-- since S-194 (both weapons turn with it), `emitter` the laser's muzzle.

local SWING = { motion = "swing", axis = { 1, 0, 0 } }

local parts = {}
local function add(p)
	table.insert(parts, p)
end

-- a box from a to b (in a plane of constant x), w wide and d deep
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

-- pelvis: narrow and armored
add({ name = "base", shape = "box", size = { 2.2, 1.0, 1.6 }, at = { 0, 4.75, 0 }, color = "dark" })
add({ name = "codplate", parent = "base", shape = "wedge", size = { 1.5, 1.0, 0.5 }, at = { 0, 4.55, -1.0 }, color = "hull" })
add({ name = "hipAxle", parent = "base", shape = "cylinder", axis = "x", size = { 3.2, 0.6, 0.6 }, at = { 0, 4.6, 0 }, color = "metal" })

-- torso: waist, a chest widening up into a V, the core, collar, reactor
add({ name = "torso", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 0.7, 1.6 }, at = { 0, 5.55, 0 }, pivot = { 0, 5.3, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } })
add({ name = "abdomen", parent = "torso", shape = "box", size = { 2.6, 0.8, 1.8 }, at = { 0, 6.15, 0 }, color = "dark" })
add({ name = "chest", parent = "torso", shape = "box", size = { 4.2, 1.5, 2.4 }, at = { 0, 7.2, 0 }, color = "hull" })
add({ name = "chestPlate", parent = "torso", shape = "wedge", size = { 3.6, 1.1, 0.7 }, at = { 0, 6.9, -1.5 }, rot = { 0, 180, 180 }, color = "hull" })
add({ name = "core", parent = "torso", shape = "cylinder", axis = "z", size = { 1.0, 1.0, 0.25 }, at = { 0, 7.2, -1.3 }, color = "glass" })
add({ name = "chestTeamL", parent = "torso", shape = "box", size = { 0.7, 0.6, 0.08 }, at = { -1.3, 7.35, -1.24 }, color = "team" })
add({ name = "chestTeamR", parent = "torso", shape = "box", size = { 0.7, 0.6, 0.08 }, at = { 1.3, 7.35, -1.24 }, color = "team" })
add({ name = "collar", parent = "torso", shape = "box", size = { 4.8, 0.6, 2.2 }, at = { 0, 8.2, 0.1 }, color = "hull" })
add({ name = "reactor", parent = "torso", shape = "box", size = { 3.4, 2.2, 1.6 }, at = { 0, 7.4, 1.95 }, color = "dark" })
add({ name = "reactorVent", parent = "torso", shape = "box", size = { 2.4, 0.3, 0.1 }, at = { 0, 7.0, 2.78 }, color = "glass" })
add({ name = "mast", parent = "torso", shape = "cylinder", axis = "y", size = { 0.12, 1.6, 0.12 }, at = { 1.2, 9.2, 2.3 }, color = "metal" })
-- pauldrons out past the body, carrying the team plates
for _, sx in { -1, 1 } do
	local n = if sx < 0 then "L" else "R"
	add({ name = `pauldron{n}`, parent = "torso", shape = "box", size = { 2.3, 1.5, 3.0 }, at = { sx * 3.8, 8.25, 0 }, color = "hull" })
	add({ name = `pauldronEdge{n}`, parent = "torso", shape = "wedge", size = { 2.3, 0.8, 0.6 }, at = { sx * 3.8, 8.1, -1.75 }, rot = { 0, 180, 180 }, color = "hull" })
	add({ name = `shoulderTeam{n}`, parent = "torso", shape = "box", size = { 1.7, 0.08, 2.2 }, at = { sx * 3.8, 9.04, 0 }, color = "team" })
end

-- head: a sensor unit standing up on a neck, under an armored brow
add({ name = "head", parent = "torso", shape = "box", size = { 1.3, 1.0, 1.4 }, at = { 0, 9.05, -0.3 }, pivot = { 0, 8.5, -0.2 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } })
add({ name = "neck", parent = "head", shape = "cylinder", axis = "y", size = { 0.7, 0.6, 0.7 }, at = { 0, 8.5, -0.2 }, color = "metal" })
add({ name = "brow", parent = "head", shape = "wedge", size = { 1.5, 0.4, 0.6 }, at = { 0, 9.45, -1.0 }, color = "dark" })
add({ name = "visor", parent = "head", shape = "box", size = { 1.0, 0.16, 0.06 }, at = { 0, 9.1, -1.02 }, color = "glass" })
add({ name = "antenna", parent = "head", shape = "cylinder", axis = "y", size = { 0.08, 0.9, 0.08 }, at = { 0.45, 9.95, 0.1 }, color = "metal" })

-- left arm: shoulder, upper arm, the build forearm angled forward-down, the emitter at its end
add({ name = "armL", parent = "torso", shape = "ball", size = { 1.3, 1.3, 1.3 }, at = { -3.3, 7.6, 0 }, pivot = { -3.3, 7.6, 0 }, color = "metal", anim = SWING })
limb("upperArmL", "armL", { -3.35, 7.3, 0 }, { -3.35, 5.6, 0 }, 1.0, 1.1, "hull")
limb("nano", "armL", { -3.35, 5.5, 0 }, { -3.35, 3.7, -0.9 }, 1.1, 1.2, "hull", { pivot = { -3.35, 5.5, 0 } })
add({ name = "emitter", parent = "nano", shape = "cylinder", axis = "z", size = { 0.8, 0.8, 0.5 }, at = { -3.35, 3.55, -1.35 }, color = "glass" })

-- right arm: shoulder, upper arm, a big weapon pod held forward below the waist
add({ name = "armR", parent = "torso", shape = "ball", size = { 1.3, 1.3, 1.3 }, at = { 3.3, 7.6, 0 }, pivot = { 3.3, 7.6, 0 }, color = "metal", anim = SWING })
limb("upperArmR", "armR", { 3.35, 7.3, 0 }, { 3.35, 5.6, 0 }, 1.0, 1.1, "hull")
add({ name = "forearmR", parent = "armR", shape = "box", size = { 1.5, 1.5, 3.4 }, at = { 3.45, 4.75, -1.2 }, pivot = { 3.35, 5.5, 0 }, color = "hull", anim = SWING })
add({ name = "podTeam", parent = "forearmR", shape = "box", size = { 0.08, 0.7, 1.8 }, at = { 4.22, 4.9, -1.0 }, color = "team" })
add({ name = "gun", parent = "forearmR", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 1.3 }, at = { 3.45, 4.65, -3.5 }, color = "dark" })

-- legs: hip yoke, a thigh down and forward to the knee, a shin back down to
-- the ankle (a real knee bend), a compact foot with toe and heel plates
for _, sx in { -1, 1 } do
	local n = if sx < 0 then "L" else "R"
	local x = sx * 1.5
	add({ name = `hip{n}`, parent = "base", shape = "box", size = { 0.8, 0.9, 1.1 }, at = { sx * 1.45, 4.6, 0 }, pivot = { sx * 1.3, 4.6, 0 }, color = "metal", anim = SWING })
	limb(`thigh{n}`, `hip{n}`, { x, 4.5, 0 }, { x, 2.6, -0.55 }, 1.2, 1.3, "hull", { pivot = { x, 4.5, 0 }, anim = SWING })
	add({ name = `knee{n}`, parent = `thigh{n}`, shape = "wedge", size = { 1.1, 0.9, 0.5 }, at = { x, 2.65, -1.25 }, rot = { 0, 180, 180 }, color = "dark" })
	limb(`shin{n}`, `thigh{n}`, { x, 2.6, -0.55 }, { x, 0.8, 0.15 }, 1.1, 1.2, "hull", { pivot = { x, 2.6, -0.55 }, anim = SWING })
	add({ name = `shinTeam{n}`, parent = `shin{n}`, shape = "box", size = { 0.6, 0.8, 0.08 }, at = { x, 1.8, -0.8 }, rot = { -21, 0, 0 }, color = "team" })
	add({ name = `foot{n}`, parent = `shin{n}`, shape = "box", size = { 1.0, 0.5, 0.9 }, at = { x, 0.55, 0.15 }, pivot = { x, 0.75, 0.15 }, color = "dark", anim = SWING })
	add({ name = `toe{n}`, parent = `foot{n}`, shape = "box", size = { 1.3, 0.45, 1.4 }, at = { x, 0.23, -0.75 }, color = "hull" })
	add({ name = `heel{n}`, parent = `foot{n}`, shape = "box", size = { 1.0, 0.45, 0.8 }, at = { x, 0.23, 0.8 }, color = "hull" })
end

return {
	id = "ord_sovereign",
	visualPieces = { "head", "armL", "armR", "forearmR", "hipL", "thighL", "shinL", "footL", "hipR", "thighR", "shinR", "footR" },
	parts = parts,
	attachments = {
		{ name = "nano1", parent = "nano", at = { -3.35, 3.55, -1.62 } }, -- nanoframe anchor (M-25)
		{ name = "muzzle", parent = "forearmR", at = { 3.45, 4.65, -5.0 } },
	},
}

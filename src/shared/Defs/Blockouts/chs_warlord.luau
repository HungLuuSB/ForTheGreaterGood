--!strict
-- Warlord (Chaos Commander, M-31): a hunched, heavier walker, about 1.5x a
-- Lancer's height to the top of its shoulders and wider than the Sovereign,
-- with the head low and forward between them. Exposed pistons and
-- hydraulics on the legs, slab and reactive armor, amber eye slits, twin
-- exhaust stacks, and a banner mast with the team banner on its back. Left
-- arm: a crane-like claw arm with the build emitter (`nano`, the def's
-- piece); right arm: a heavy gun with `muzzle`. Chaos reads light and
-- improvised (M-14). Original design. Model space, forward = -Z.
--
-- Rig (rig.md 10, walkers): the same pieces as the Sovereign.

local SWING = { motion = "swing", axis = { 1, 0, 0 } }

local parts = {
	-- pelvis: a wide slab
	{ name = "base", shape = "box", size = { 2.6, 0.9, 1.6 }, at = { 0, 2.35, 0.1 }, color = "dark" },
	-- torso: hunched forward, slabs and reactive blocks
	{ name = "torso", parent = "base", shape = "box", size = { 3.0, 1.6, 2.1 }, at = { 0, 3.55, -0.15 }, rot = { 12, 0, 0 }, pivot = { 0, 2.8, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "chestSlab", parent = "torso", shape = "box", size = { 2.6, 1.1, 0.35 }, at = { 0, 3.45, -1.35 }, rot = { 18, 0, 0 }, color = "dark" },
	{ name = "eraL", parent = "torso", shape = "box", size = { 0.6, 0.5, 0.3 }, at = { -0.8, 3.75, -1.5 }, rot = { 18, 0, 0 }, color = "hull" },
	{ name = "eraR", parent = "torso", shape = "box", size = { 0.6, 0.5, 0.3 }, at = { 0.8, 3.75, -1.5 }, rot = { 18, 0, 0 }, color = "hull" },
	{ name = "coreSlit", parent = "torso", shape = "box", size = { 1.2, 0.15, 0.1 }, at = { 0, 3.15, -1.55 }, rot = { 18, 0, 0 }, color = "glass" },
	{ name = "hump", parent = "torso", shape = "box", size = { 2.4, 1.0, 1.4 }, at = { 0, 4.35, 0.45 }, color = "hull" },
	{ name = "humpTeam", parent = "torso", shape = "box", size = { 1.4, 0.08, 0.9 }, at = { 0, 4.88, 0.45 }, color = "team" },
	{ name = "stackL", parent = "torso", shape = "cylinder", axis = "y", size = { 0.45, 1.6, 0.45 }, at = { -0.75, 5.0, 1.15 }, color = "metal" },
	{ name = "stackR", parent = "torso", shape = "cylinder", axis = "y", size = { 0.45, 1.6, 0.45 }, at = { 0.75, 5.0, 1.15 }, color = "metal" },
	{ name = "mast", parent = "torso", shape = "cylinder", axis = "y", size = { 0.14, 3.0, 0.14 }, at = { 1.25, 5.6, 1.1 }, color = "metal" },
	{ name = "banner", parent = "torso", shape = "box", size = { 0.06, 1.4, 1.0 }, at = { 1.25, 6.35, 1.65 }, color = "team" },
	-- shoulders: heavy slabs
	{ name = "pauldronL", parent = "torso", shape = "box", size = { 1.3, 1.1, 1.9 }, at = { -2.15, 4.0, -0.1 }, color = "dark" },
	{ name = "pauldronR", parent = "torso", shape = "box", size = { 1.3, 1.1, 1.9 }, at = { 2.15, 4.0, -0.1 }, color = "dark" },
	{ name = "shoulderTeamR", parent = "torso", shape = "box", size = { 0.9, 0.08, 1.2 }, at = { 2.15, 4.58, -0.1 }, color = "team" },
	-- head: low and forward, amber eye slits
	{ name = "head", parent = "torso", shape = "box", size = { 1.0, 0.65, 0.9 }, at = { 0, 4.1, -1.45 }, pivot = { 0, 4.0, -1.0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "eyeL", parent = "head", shape = "box", size = { 0.3, 0.08, 0.06 }, at = { -0.22, 4.15, -1.93 }, color = "glass" },
	{ name = "eyeR", parent = "head", shape = "box", size = { 0.3, 0.08, 0.06 }, at = { 0.22, 4.15, -1.93 }, color = "glass" },
	-- left arm: the crane-like claw arm with the build emitter
	{ name = "armL", parent = "torso", shape = "box", size = { 0.7, 1.3, 0.8 }, at = { -2.25, 3.15, -0.2 }, pivot = { -2.2, 3.9, -0.1 }, color = "metal", anim = SWING },
	{ name = "nano", parent = "armL", shape = "box", size = { 0.5, 0.5, 2.4 }, at = { -2.25, 2.45, -1.0 }, pivot = { -2.25, 2.5, 0 }, color = "dark" },
	{ name = "boomPiston", parent = "nano", shape = "cylinder", axis = "z", size = { 0.22, 0.22, 1.6 }, at = { -2.25, 2.85, -0.7 }, color = "metal" },
	{ name = "clawA", parent = "nano", shape = "box", size = { 0.15, 0.7, 0.5 }, at = { -2.45, 2.4, -2.35 }, rot = { 0, 0, 15 }, color = "metal" },
	{ name = "clawB", parent = "nano", shape = "box", size = { 0.15, 0.7, 0.5 }, at = { -2.05, 2.4, -2.35 }, rot = { 0, 0, -15 }, color = "metal" },
	{ name = "emitter", parent = "nano", shape = "ball", size = { 0.45, 0.45, 0.45 }, at = { -2.25, 2.45, -2.3 }, color = "glass" },
	-- right arm: a short heavy gun
	{ name = "armR", parent = "torso", shape = "box", size = { 0.75, 1.2, 0.85 }, at = { 2.3, 3.2, -0.2 }, pivot = { 2.25, 3.9, -0.1 }, color = "metal", anim = SWING },
	{ name = "forearmR", parent = "armR", shape = "box", size = { 1.1, 1.0, 1.9 }, at = { 2.35, 2.45, -0.7 }, pivot = { 2.3, 2.7, -0.2 }, color = "dark", anim = SWING },
	{ name = "gun", parent = "forearmR", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.9 }, at = { 2.35, 2.4, -2.05 }, color = "metal" },
	{ name = "gunEye", parent = "forearmR", shape = "box", size = { 0.25, 0.08, 0.06 }, at = { 2.35, 2.95, -1.66 }, color = "glass" },
}

-- legs: wide stance, hip yokes, thighs with exposed pistons, heavy shins and
-- splayed feet; all swing about X
for _, s in { { "L", -1 }, { "R", 1 } } do
	local n, x = s[1], s[2]
	table.insert(parts, { name = `hip{n}`, parent = "base", shape = "box", size = { 0.8, 0.8, 1.0 }, at = { x * 1.55, 2.25, 0.1 }, pivot = { x * 1.4, 2.3, 0.1 }, color = "metal", anim = SWING })
	table.insert(parts, { name = `thigh{n}`, parent = `hip{n}`, shape = "box", size = { 0.8, 1.15, 0.9 }, at = { x * 1.6, 1.65, -0.15 }, rot = { -15, 0, 0 }, pivot = { x * 1.6, 2.15, 0.1 }, color = "dark", anim = SWING })
	table.insert(parts, { name = `piston{n}`, parent = `thigh{n}`, shape = "cylinder", axis = "y", size = { 0.18, 1.3, 0.18 }, at = { x * 2.05, 1.5, 0.15 }, color = "metal" })
	table.insert(parts, { name = `shin{n}`, parent = `thigh{n}`, shape = "box", size = { 0.95, 1.1, 1.1 }, at = { x * 1.6, 0.8, 0.0 }, pivot = { x * 1.6, 1.15, -0.35 }, color = "hull", anim = SWING })
	table.insert(parts, { name = `shinPiston{n}`, parent = `shin{n}`, shape = "cylinder", axis = "y", size = { 0.16, 0.9, 0.16 }, at = { x * 1.6, 0.85, 0.65 }, color = "metal" })
	table.insert(parts, { name = `foot{n}`, parent = `shin{n}`, shape = "box", size = { 1.3, 0.35, 1.9 }, at = { x * 1.65, 0.175, -0.25 }, pivot = { x * 1.6, 0.35, 0 }, color = "dark", anim = SWING })
end

return {
	id = "chs_warlord",
	visualPieces = { "torso", "head", "armL", "armR", "forearmR", "hipL", "thighL", "shinL", "footL", "hipR", "thighR", "shinR", "footR" },
	parts = parts,
	attachments = {
		{ name = "nano1", parent = "nano", at = { -2.25, 2.45, -2.6 } }, -- nanoframe anchor (M-25)
		{ name = "muzzle", parent = "forearmR", at = { 2.35, 2.4, -2.55 } },
	},
}

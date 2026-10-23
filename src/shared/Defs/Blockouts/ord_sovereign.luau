--!strict
-- Sovereign (Order Commander, M-31): a tall upright walking battle mech, the
-- most imposing ground unit (about 1.5x a Lancer's height: 5.6 studs to the
-- top of the head). Clean sloped plates, a broad chest and big shoulder
-- armor with team plates, a sensor head under an armored brow, a big cyan
-- command core in the chest. Left arm: the build emitter (`nano`, the def's
-- piece, the forearm); right arm: a weapon pod with `muzzle`. Order reads
-- heavy (M-14). Original design. Model space, forward = -Z.
--
-- Rig (rig.md 10, walkers): base = pelvis; torso (turns); head; armL / armR
-- (shoulders) with the forearms `nano` / `forearmR`; per leg hip, thigh,
-- shin, foot. The legs and arms swing (the client's walk cycle).

local SWING = { motion = "swing", axis = { 1, 0, 0 } }

local parts = {
	-- pelvis
	{ name = "base", shape = "box", size = { 2.2, 0.9, 1.5 }, at = { 0, 2.65, 0 }, color = "dark" },
	{ name = "codplate", parent = "base", shape = "wedge", size = { 1.4, 0.8, 0.5 }, at = { 0, 2.45, -0.95 }, color = "hull" },
	-- torso: a broad chest on a waist, turned by the client
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 1.7, 1.9 }, at = { 0, 3.95, 0.05 }, pivot = { 0, 3.1, 0 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "waist", parent = "torso", shape = "cylinder", axis = "y", size = { 1.3, 0.5, 1.3 }, at = { 0, 3.2, 0 }, color = "metal" },
	{ name = "chest", parent = "torso", shape = "box", size = { 2.4, 1.3, 0.4 }, at = { 0, 4.0, -1.15 }, color = "hull" },
	{ name = "collar", parent = "torso", shape = "wedge", size = { 2.6, 0.5, 0.6 }, at = { 0, 4.85, -0.95 }, color = "hull" },
	{ name = "core", parent = "torso", shape = "cylinder", axis = "z", size = { 0.85, 0.85, 0.2 }, at = { 0, 3.95, -1.42 }, color = "glass" },
	{ name = "coreRim", parent = "torso", shape = "cylinder", axis = "z", size = { 1.15, 1.15, 0.12 }, at = { 0, 3.95, -1.37 }, color = "dark" },
	{ name = "chestTeamL", parent = "torso", shape = "box", size = { 0.45, 0.5, 0.08 }, at = { -0.85, 4.25, -1.38 }, color = "team" },
	{ name = "chestTeamR", parent = "torso", shape = "box", size = { 0.45, 0.5, 0.08 }, at = { 0.85, 4.25, -1.38 }, color = "team" },
	{ name = "backpack", parent = "torso", shape = "box", size = { 2.0, 1.4, 0.8 }, at = { 0, 4.0, 1.3 }, color = "dark" },
	{ name = "vents", parent = "torso", shape = "box", size = { 1.4, 0.3, 0.1 }, at = { 0, 4.35, 1.72 }, color = "glass" },
	-- shoulder armor with team plates
	{ name = "pauldronL", parent = "torso", shape = "box", size = { 1.3, 1.0, 1.8 }, at = { -1.95, 4.45, 0 }, color = "hull" },
	{ name = "pauldronR", parent = "torso", shape = "box", size = { 1.3, 1.0, 1.8 }, at = { 1.95, 4.45, 0 }, color = "hull" },
	{ name = "shoulderTeamL", parent = "torso", shape = "box", size = { 0.95, 0.08, 1.3 }, at = { -1.95, 4.98, 0 }, color = "team" },
	{ name = "shoulderTeamR", parent = "torso", shape = "box", size = { 0.95, 0.08, 1.3 }, at = { 1.95, 4.98, 0 }, color = "team" },
	-- sensor head under an armored brow
	{ name = "head", parent = "torso", shape = "box", size = { 0.95, 0.7, 0.95 }, at = { 0, 5.15, -0.2 }, pivot = { 0, 4.8, -0.1 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "brow", parent = "head", shape = "wedge", size = { 1.15, 0.35, 0.45 }, at = { 0, 5.38, -0.62 }, color = "dark" },
	{ name = "visor", parent = "head", shape = "box", size = { 0.75, 0.14, 0.06 }, at = { 0, 5.12, -0.69 }, color = "glass" },
	{ name = "antenna", parent = "head", shape = "cylinder", axis = "y", size = { 0.08, 0.7, 0.08 }, at = { 0.35, 5.8, 0.1 }, color = "metal" },
	-- left arm: the build arm, the emitter at the end of the forearm (`nano`)
	{ name = "armL", parent = "torso", shape = "box", size = { 0.75, 1.2, 0.85 }, at = { -2.05, 3.65, 0 }, pivot = { -2.05, 4.3, 0 }, color = "dark", anim = SWING },
	{ name = "nano", parent = "armL", shape = "box", size = { 0.85, 0.85, 1.7 }, at = { -2.05, 2.85, -0.45 }, pivot = { -2.05, 3.1, 0 }, color = "hull" },
	{ name = "emitterRing", parent = "nano", shape = "cylinder", axis = "z", size = { 0.75, 0.75, 0.3 }, at = { -2.05, 2.85, -1.4 }, color = "metal" },
	{ name = "emitter", parent = "nano", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.12 }, at = { -2.05, 2.85, -1.58 }, color = "glass" },
	-- right arm: the weapon pod
	{ name = "armR", parent = "torso", shape = "box", size = { 0.75, 1.2, 0.85 }, at = { 2.05, 3.65, 0 }, pivot = { 2.05, 4.3, 0 }, color = "dark", anim = SWING },
	{ name = "forearmR", parent = "armR", shape = "box", size = { 1.0, 1.0, 2.0 }, at = { 2.1, 2.85, -0.55 }, pivot = { 2.05, 3.1, 0 }, color = "hull", anim = SWING },
	{ name = "podTeam", parent = "forearmR", shape = "box", size = { 0.08, 0.5, 1.2 }, at = { 2.62, 2.9, -0.5 }, color = "team" },
	{ name = "gun", parent = "forearmR", shape = "cylinder", axis = "z", size = { 0.42, 0.42, 0.8 }, at = { 2.1, 2.75, -1.9 }, color = "dark" },
}

-- legs: hip (a yoke on the pelvis), thigh, shin, foot; all swing about X
for _, s in { { "L", -1 }, { "R", 1 } } do
	local n, x = s[1], s[2]
	table.insert(parts, { name = `hip{n}`, parent = "base", shape = "box", size = { 0.7, 0.7, 1.0 }, at = { x * 1.3, 2.55, 0 }, pivot = { x * 1.2, 2.6, 0 }, color = "metal", anim = SWING })
	table.insert(parts, { name = `thigh{n}`, parent = `hip{n}`, shape = "box", size = { 0.85, 1.25, 1.05 }, at = { x * 1.3, 1.85, 0 }, pivot = { x * 1.3, 2.4, 0 }, color = "hull", anim = SWING })
	table.insert(parts, { name = `knee{n}`, parent = `thigh{n}`, shape = "wedge", size = { 0.8, 0.55, 0.45 }, at = { x * 1.3, 1.3, -0.6 }, color = "dark" })
	table.insert(parts, { name = `shin{n}`, parent = `thigh{n}`, shape = "box", size = { 0.8, 1.15, 0.95 }, at = { x * 1.3, 0.85, 0.05 }, pivot = { x * 1.3, 1.25, 0 }, color = "hull", anim = SWING })
	table.insert(parts, { name = `shinTeam{n}`, parent = `shin{n}`, shape = "box", size = { 0.45, 0.6, 0.06 }, at = { x * 1.3, 0.9, -0.45 }, color = "team" })
	table.insert(parts, { name = `foot{n}`, parent = `shin{n}`, shape = "box", size = { 1.05, 0.35, 1.8 }, at = { x * 1.3, 0.175, -0.2 }, pivot = { x * 1.3, 0.35, 0 }, color = "dark", anim = SWING })
end

return {
	id = "ord_sovereign",
	visualPieces = { "torso", "head", "armL", "armR", "forearmR", "hipL", "thighL", "shinL", "footL", "hipR", "thighR", "shinR", "footR" },
	parts = parts,
	attachments = {
		{ name = "nano1", parent = "nano", at = { -2.05, 2.85, -1.66 } }, -- nanoframe anchor (M-25)
		{ name = "muzzle", parent = "forearmR", at = { 2.1, 2.75, -2.32 } },
	},
}

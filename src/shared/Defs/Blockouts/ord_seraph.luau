--!strict
-- Seraph (Order mobile radar SAM, T2, footprint 1): an armored 8 × 8 truck
-- with a boxy cab; at the back the `launcher`, four sealed canisters raised
-- 35° on a turning cradle; ahead of it the `turret`: a flat radar array on a
-- short mast (not turned by the weapon; the def turns `launcher`, M-3).
-- Team plates on the cab roof and canister lids. Order reads heavy (M-14).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.8, 1.3, 7.6 }, at = { 0, 1.75, 0.1 }, color = "hull" },
	{ name = "skirtL", parent = "base", shape = "box", size = { 0.3, 0.8, 6.8 }, at = { -2.55, 1.25, 0.1 }, color = "hull" },
	{ name = "skirtR", parent = "base", shape = "box", size = { 0.3, 0.8, 6.8 }, at = { 2.55, 1.25, 0.1 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 4.6, 1.3, 1.8 }, at = { 0, 3.05, -2.8 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 3.8, 0.35, 0.08 }, at = { 0, 3.25, -3.74 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 3.4, 0.08, 1.2 }, at = { 0, 3.74, -2.8 }, color = "team" },

	{ name = "turret", parent = "base", shape = "box", size = { 0.5, 1.8, 0.5 }, at = { 0, 3.3, -0.8 }, color = "dark" },
	{ name = "array", parent = "turret", shape = "box", size = { 3.0, 1.8, 0.3 }, at = { 0, 4.8, -0.8 }, rot = { -15, 0, 0 }, color = "hull" },
	{ name = "arrayFace", parent = "turret", shape = "box", size = { 2.6, 1.4, 0.06 }, at = { 0, 4.8, -0.99 }, rot = { -15, 0, 0 }, color = "glass" },

	{ name = "launcher", parent = "base", shape = "box", size = { 3.4, 0.5, 3.0 }, at = { 0, 2.65, 2.3 }, pivot = { 0, 2.4, 2.3 }, color = "dark" },
}
for i, x in { -1.2, -0.4, 0.4, 1.2 } do
	table.insert(parts, { name = `can{i}`, parent = "launcher", shape = "box", size = { 0.7, 0.7, 3.6 }, at = { x, 3.85, 2.0 }, rot = { 35, 0, 0 }, color = "hull" })
	table.insert(parts, { name = `lid{i}`, parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { x, 5.0, 0.6 }, rot = { 35, 0, 0 }, color = "team" })
end
for i, z in { -2.9, -1.3, 1.3, 2.9 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { -2.2, 0.75, z }, color = "track" })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { 2.2, 0.75, z }, color = "track" })
end

return {
	id = "ord_seraph",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 5.2, 0.3 } },
	},
}

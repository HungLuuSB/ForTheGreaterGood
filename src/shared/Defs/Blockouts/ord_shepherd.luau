--!strict
-- Shepherd (Order mobile point defence, T2 ground, footprint 1, S-149): an
-- armored 6x6 about 1.3x a T1 truck with a sloped cab, skirts with team
-- strips, and a vertical-launch module on the back (`launcher`, static: a
-- 2 x 4 grid of cell hatches with ready lights, launching straight up), a
-- compact search radar on a short mast behind the cab (client-only `radar`,
-- turns). `muzzle` at the front left cell. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.8, 1.6, 10 }, at = { 0, 1.9, 0 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 4.6, 1.6, 2.6 }, at = { 0, 3.4, -3.6 }, color = "hull" },
	{ name = "glacis", parent = "base", shape = "wedge", size = { 4.8, 1.6, 1.2 }, at = { 0, 1.9, -5.6 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 3.8, 0.45, 0.1 }, at = { 0, 3.8, -4.92 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 3.2, 0.08, 1.6 }, at = { 0, 4.24, -3.6 }, color = "team" },
	{ name = "skirtL", parent = "base", shape = "box", size = { 0.2, 0.8, 8.8 }, at = { -2.5, 1.9, 0.3 }, color = "hull" },
	{ name = "skirtR", parent = "base", shape = "box", size = { 0.2, 0.8, 8.8 }, at = { 2.5, 1.9, 0.3 }, color = "hull" },
	{ name = "skirtTeamL", parent = "base", shape = "box", size = { 0.06, 0.3, 4 }, at = { -2.62, 1.9, 1.0 }, color = "team" },
	{ name = "skirtTeamR", parent = "base", shape = "box", size = { 0.06, 0.3, 4 }, at = { 2.62, 1.9, 1.0 }, color = "team" },
	-- the vertical-launch module
	{ name = "launcher", parent = "base", shape = "box", size = { 3.6, 1.6, 4.8 }, at = { 0, 3.5, 2.2 }, pivot = { 0, 2.7, 2.2 }, color = "hull" },
	{ name = "vlsTeam", parent = "launcher", shape = "box", size = { 3.0, 0.08, 0.8 }, at = { 0, 4.34, 4.3 }, color = "team" },
	{ name = "radarMast", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.2, 0.35 }, at = { -1.4, 4.8, -1.8 }, color = "metal" },
	{ name = "radar", parent = "base", shape = "box", size = { 1.6, 0.9, 0.2 }, at = { -1.4, 5.7, -1.8 }, rot = { 15, 0, 0 }, pivot = { -1.4, 5.4, -1.8 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
}
for i = 0, 3 do
	for j = 0, 1 do
		table.insert(parts, { name = `cell{i}{j}`, parent = "launcher", shape = "box", size = { 1.3, 0.1, 0.9 }, at = { -0.75 + j * 1.5, 4.32, 0.35 + i * 1.05 }, color = "metal" })
		table.insert(parts, { name = `ready{i}{j}`, parent = "launcher", shape = "box", size = { 0.5, 0.06, 0.15 }, at = { -0.75 + j * 1.5, 4.38, 0.0 + i * 1.05 }, color = "glass" })
	end
end
for i, z in { -3.4, 0.2, 3.6 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.6, 1.6 }, at = { -2.35, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.6, 1.6 }, at = { 2.35, 0.8, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return {
	id = "ord_shepherd",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -0.75, 4.5, 0.35 } },
	},
}

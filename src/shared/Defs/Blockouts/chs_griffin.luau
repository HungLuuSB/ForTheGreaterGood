--!strict
-- Griffin (Chaos mobile point defence, T2 ground, footprint 1, S-149): a
-- lighter 6x6 truck with an open-backed cab and a flatbed carrying an open
-- welded rack of twelve upright interceptor tubes (`launcher`, static: the
-- deep stock, launching straight up, amber ready mouths), a spare tube crate,
-- and a lattice radar mast (client-only `radar`, turns). `muzzle` at the
-- front left tube's mouth. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.2, 1.2, 9.8 }, at = { 0, 1.7, 0 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 3.8, 1.5, 2.2 }, at = { 0, 3.05, -3.7 }, color = "hull" },
	{ name = "cabSlit", parent = "base", shape = "box", size = { 3.0, 0.3, 0.1 }, at = { 0, 3.4, -4.82 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 2.8, 0.08, 1.4 }, at = { 0, 3.84, -3.7 }, color = "team" },
	{ name = "bedTeamL", parent = "base", shape = "box", size = { 0.8, 0.08, 3.6 }, at = { -1.6, 2.34, 1.4 }, color = "team" },
	{ name = "bedTeamR", parent = "base", shape = "box", size = { 0.8, 0.08, 3.6 }, at = { 1.6, 2.34, 1.4 }, color = "team" },
	{ name = "crate", parent = "base", shape = "box", size = { 1.0, 0.7, 1.6 }, at = { 1.5, 2.65, -1.6 }, color = "metal" },
	-- the rack of upright tubes
	{ name = "launcher", parent = "base", shape = "box", size = { 3.2, 0.4, 4.2 }, at = { 0, 2.5, 2.0 }, pivot = { 0, 2.3, 2.0 }, color = "dark" },
	{ name = "rackFrontPost", parent = "launcher", shape = "box", size = { 3.2, 2.4, 0.2 }, at = { 0, 3.7, -0.1 }, color = "metal" },
	{ name = "rackBackPost", parent = "launcher", shape = "box", size = { 3.2, 2.4, 0.2 }, at = { 0, 3.7, 4.1 }, color = "metal" },
	-- lattice radar mast behind the cab
	{ name = "mast", parent = "base", shape = "box", size = { 0.3, 3.2, 0.3 }, at = { -1.5, 3.9, -2.2 }, color = "dark" },
	{ name = "radar", parent = "base", shape = "box", size = { 1.6, 0.8, 0.2 }, at = { -1.5, 5.8, -2.2 }, pivot = { -1.5, 5.5, -2.2 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "beacon", parent = "base", shape = "box", size = { 0.35, 0.35, 0.35 }, at = { -1.5, 6.4, -2.2 }, color = "glass" },
}
for i = 0, 3 do
	for j = 0, 2 do
		local x, z = -1.0 + j * 1.0, 0.5 + i * 1.0
		table.insert(parts, { name = `tube{i}{j}`, parent = "launcher", shape = "cylinder", axis = "y", size = { 0.6, 2.2, 0.6 }, at = { x, 3.8, z }, color = "metal" })
		table.insert(parts, { name = `mouth{i}{j}`, parent = "launcher", shape = "cylinder", axis = "y", size = { 0.45, 0.06, 0.45 }, at = { x, 4.92, z }, color = "glass" })
	end
end
for i, z in { -3.4, 0.4, 3.6 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { -2.2, 0.75, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { 2.2, 0.75, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return {
	id = "chs_griffin",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -1.0, 5.0, 0.5 } },
	},
}

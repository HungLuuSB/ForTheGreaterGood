--!strict
-- Custodian (Order mobile anti-nuke, proposed: T2 ground, footprint 1, from
-- the advanced vehicle plant; the user's request 2026-10-23, sim to define):
-- an armored 8x8 carrier about 1.3x a T1 truck (size scale) with a sloped
-- cab, a single large interceptor canister lying on the back (`launcher`,
-- hinged at its rear end; pose `raised`: swung up to near vertical), a
-- readiness ring at the canister mouth (power / weapon glow on the mesh), and
-- a compact radar (client-only `radar`, turns) on the cab roof. `muzzle` at
-- the canister mouth. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 5.2, 1.6, 10.6 }, at = { 0, 1.9, 0 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 5.0, 1.8, 2.6 }, at = { 0, 3.5, -3.9 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 4.2, 0.5, 0.1 }, at = { 0, 3.9, -5.22 }, color = "glass" },
	{ name = "glacis", parent = "base", shape = "wedge", size = { 5.2, 1.6, 1.2 }, at = { 0, 1.9, -5.9 }, color = "hull" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 3.4, 0.08, 1.6 }, at = { 0, 4.44, -3.9 }, color = "team" },
	{ name = "cradleF", parent = "base", shape = "box", size = { 3.6, 1.0, 0.6 }, at = { 0, 3.2, -1.6 }, color = "dark" },
	{ name = "cradleB", parent = "base", shape = "box", size = { 3.6, 1.4, 0.8 }, at = { 0, 3.4, 4.5 }, color = "dark" },
	-- the canister: a big tube on the back, hinged at its rear end
	{ name = "launcher", parent = "base", shape = "cylinder", axis = "z", size = { 2.6, 2.6, 7.6 }, at = { 0, 4.1, 0.9 }, pivot = { 0, 4.1, 4.7 }, color = "hull" },
	{ name = "canTeam", parent = "launcher", shape = "box", size = { 1.2, 0.08, 4 }, at = { 0, 5.42, 1.2 }, color = "team" },
	{ name = "canRing", parent = "launcher", shape = "cylinder", axis = "z", size = { 2.7, 2.7, 0.3 }, at = { 0, 4.1, -2.4 }, color = "dark" },
	{ name = "ready", parent = "launcher", shape = "cylinder", axis = "z", size = { 2.0, 2.0, 0.1 }, at = { 0, 4.1, -2.9 }, color = "glass" },
	-- compact radar on the cab roof
	{ name = "radarMast", parent = "base", shape = "cylinder", axis = "y", size = { 0.4, 0.8, 0.4 }, at = { 1.6, 4.8, -3.4 }, color = "metal" },
	{ name = "radar", parent = "base", shape = "box", size = { 1.8, 1.1, 0.2 }, at = { 1.6, 5.6, -3.4 }, rot = { 15, 0, 0 }, pivot = { 1.6, 5.2, -3.4 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
}
for i, z in { -3.9, -1.6, 1.8, 4.1 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.7, 1.7 }, at = { -2.6, 0.85, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.8, 1.7, 1.7 }, at = { 2.6, 0.85, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return {
	id = "ord_custodian",
	visualPieces = { "radar" },
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 4.1, -3.0 } },
	},
}

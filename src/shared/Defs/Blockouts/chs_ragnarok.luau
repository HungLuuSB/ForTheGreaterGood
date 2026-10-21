--!strict
-- Ragnarok (Chaos nuclear silo, T3, footprint 3): a round silo tube on a pad,
-- ringed with reactive-armor blocks, a round hatch (hinged at its back edge),
-- an open launch gantry with a crane arm beside it and fuel tanks: lighter
-- and more exposed than Order's bunker (M-14). Model space, forward = -Z
-- (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 20, 0.8, 20 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "tube", parent = "base", shape = "cylinder", axis = "y", size = { 9, 2.2, 9 }, at = { 0, 1.9, 0 }, color = "hull" },
	{ name = "teamW", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { -6.2, 0.85, -4.5 }, color = "team" },
	{ name = "teamE", parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { 6.2, 0.85, -4.5 }, color = "team" },
	-- open gantry tower with a crane arm over the silo
	{ name = "legA", parent = "base", shape = "box", size = { 0.4, 7, 0.4 }, at = { 6.5, 4.3, -2 }, color = "dark" },
	{ name = "legB", parent = "base", shape = "box", size = { 0.4, 7, 0.4 }, at = { 6.5, 4.3, 2 }, color = "dark" },
	{ name = "legC", parent = "base", shape = "box", size = { 0.4, 7, 0.4 }, at = { 9, 4.3, -2 }, color = "dark" },
	{ name = "legD", parent = "base", shape = "box", size = { 0.4, 7, 0.4 }, at = { 9, 4.3, 2 }, color = "dark" },
	{ name = "beamA", parent = "base", shape = "box", size = { 2.9, 0.4, 0.4 }, at = { 7.75, 7.6, -2 }, color = "dark" },
	{ name = "beamB", parent = "base", shape = "box", size = { 2.9, 0.4, 0.4 }, at = { 7.75, 7.6, 2 }, color = "dark" },
	{ name = "beamC", parent = "base", shape = "box", size = { 2.9, 0.4, 0.4 }, at = { 7.75, 4.3, -2 }, color = "dark" },
	{ name = "beamD", parent = "base", shape = "box", size = { 2.9, 0.4, 0.4 }, at = { 7.75, 4.3, 2 }, color = "dark" },
	{ name = "arm", parent = "base", shape = "box", size = { 7, 0.5, 0.7 }, at = { 3.6, 8.0, 0 }, color = "metal" },
	{ name = "lightA", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 8.05, -2 }, color = "glass" },
	{ name = "lightB", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 9, 8.05, 2 }, color = "glass" },
	-- fuel tanks
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 3, 1.6 }, at = { -7, 2.3, 4 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 3, 1.6 }, at = { -7, 2.3, 6.2 }, color = "metal" },
}

-- reactive-armor blocks round the tube, gaps between them
for i = 0, 7 do
	local a = i * 45
	local r = math.rad(a)
	table.insert(parts, {
		name = `era{i}`,
		parent = "base",
		shape = "box",
		size = { 2.2, 1.3, 0.4 },
		at = { math.sin(r) * 4.7, 1.9, math.cos(r) * 4.7 },
		rot = { 0, a, 0 },
		color = "metal",
	})
end

-- hatch: swings up about its back edge
table.insert(parts, { name = "hatch", parent = "base", shape = "cylinder", axis = "y", size = { 7.6, 0.5, 7.6 }, at = { 0, 3.25, 0 }, pivot = { 0, 3.25, 3.8 }, color = "metal" })
table.insert(parts, { name = "hatchCross", parent = "hatch", shape = "box", size = { 4.4, 0.08, 1.1 }, at = { 0, 3.54, 0 }, color = "team" })

return {
	id = "chs_ragnarok",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "base", at = { 0, 3.0, 0 } },
	},
}

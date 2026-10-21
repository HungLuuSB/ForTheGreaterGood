--!strict
-- Wind Pylon (Chaos, T1, footprint 1): an open lattice tower of four legs
-- with cross braces, a small nacelle, a two-blade rotor (visual piece) and
-- an orange light. Model space, forward = -Z (docs/contracts/rig.md).

local parts = {
	{ name = "base", shape = "box", size = { 5, 0.5, 5 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "team", parent = "base", shape = "box", size = { 4, 0.08, 1.2 }, at = { 0, 0.54, -1.8 }, color = "team" },
	{ name = "braceA", parent = "base", shape = "box", size = { 2.6, 0.2, 0.2 }, at = { 0, 4, -1.1 }, color = "dark" },
	{ name = "braceB", parent = "base", shape = "box", size = { 2.6, 0.2, 0.2 }, at = { 0, 4, 1.1 }, color = "dark" },
	{ name = "braceC", parent = "base", shape = "box", size = { 2, 0.2, 0.2 }, at = { 0, 7.5, -0.7 }, color = "dark" },
	{ name = "braceD", parent = "base", shape = "box", size = { 2, 0.2, 0.2 }, at = { 0, 7.5, 0.7 }, color = "dark" },
	{ name = "nacelle", parent = "base", shape = "box", size = { 1.2, 1, 2.4 }, at = { 0, 10.4, 0.3 }, color = "hull" },
	{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { 0, 11.05, 1.1 }, color = "glass" },
	{ name = "rotor", parent = "base", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.6 }, at = { 0, 10.4, -1.2 }, color = "metal" },
	{ name = "bladeA", parent = "rotor", shape = "box", size = { 0.45, 9, 0.12 }, at = { 0, 10.4, -1.4 }, rot = { 0, 0, 20 }, color = "hull" },
}
for i, p in { { -1.4, -1.4 }, { 1.4, -1.4 }, { -1.4, 1.4 }, { 1.4, 1.4 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.25, 9.6, 0.25 }, at = { p[1] * 0.7, 5.3, p[2] * 0.7 }, rot = { p[2] > 0 and -5 or 5, 0, p[1] > 0 and 5 or -5 }, color = "dark" })
end

return { id = "chs_windmill", visualPieces = { "rotor" }, parts = parts }

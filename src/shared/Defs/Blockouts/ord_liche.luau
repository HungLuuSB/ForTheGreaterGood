--!strict
-- Liche (Order strategic bomber, T2, footprint 2; S-181; one devastating
-- bomb per sortie): a big swept flying wing. A wide flat centre body with a
-- glazed cockpit, long swept wings with team panels, four buried engines
-- with cyan exhausts, two canted tail fins. Under the centre the `bay`
-- (the client opens it): bomb-bay doors over one huge bomb; `muzzle` under
-- the bomb. Order reads clean and heavy (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 5, 1.6, 11 }, at = { 0, 1.2, 0.5 }, color = "hull" },
	{ name = "nose", parent = "base", shape = "wedge", size = { 5, 1.4, 3.2 }, at = { 0, 1.3, -6.6 }, color = "hull" },
	{ name = "cockpit", parent = "base", shape = "wedge", size = { 2.4, 0.7, 2.2 }, at = { 0, 2.3, -4.0 }, color = "glass" },
	{ name = "spine", parent = "base", shape = "box", size = { 2.4, 0.5, 6 }, at = { 0, 2.2, 1.5 }, color = "hull" },
	{ name = "spineTeam", parent = "base", shape = "box", size = { 1.6, 0.08, 4 }, at = { 0, 2.49, 1.5 }, color = "team" },
}
for _, sx in { -1, 1 } do
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `wing{tag}`, parent = "base", shape = "box", size = { 11, 0.6, 5 }, at = { sx * 6.8, 1.0, 2.6 }, rot = { 0, sx * -32, 0 }, color = "hull" })
	table.insert(parts, { name = `wingTeam{tag}`, parent = "base", shape = "box", size = { 4, 0.08, 2 }, at = { sx * 8.2, 1.33, 3.6 }, rot = { 0, sx * -32, 0 }, color = "team" })
	table.insert(parts, { name = `wingTip{tag}`, parent = "base", shape = "box", size = { 0.4, 0.8, 2.6 }, at = { sx * 11.4, 1.1, 5.6 }, rot = { 0, sx * -32, 0 }, color = "dark" })
	for k, x in { 3.4, 5.2 } do -- buried engines
		table.insert(parts, { name = `engine{tag}{k}`, parent = "base", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 4 }, at = { sx * x, 1.5, 3.6 + (k - 1) * 1.1 }, color = "dark" })
		table.insert(parts, { name = `exhaust{tag}{k}`, parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 0.1 }, at = { sx * x, 1.5, 5.65 + (k - 1) * 1.1 }, color = "glass" })
	end
	table.insert(parts, { name = `fin{tag}`, parent = "base", shape = "box", size = { 0.3, 2.4, 2.4 }, at = { sx * 1.8, 3.0, 5.0 }, rot = { 0, 0, sx * -25 }, color = "hull" })
end
for _, p in {
	{ name = "bay", parent = "base", shape = "box", size = { 2.8, 0.3, 4.6 }, at = { 0, 0.25, 0.6 }, pivot = { 0, 0.4, 0.6 }, color = "dark" },
	{ name = "bomb", parent = "bay", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 3.6 }, at = { 0, -0.5, 0.6 }, color = "metal" },
	{ name = "bombBand", parent = "bay", shape = "cylinder", axis = "z", size = { 1.5, 1.5, 0.3 }, at = { 0, -0.5, -0.4 }, color = "hazard" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_liche",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "bay", at = { 0, -1.3, 0.6 } },
	},
}

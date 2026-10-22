--!strict
-- Advanced Shipyard (Order, T2, footprint 5): armored piers round a wider
-- basin, a tall closed hall across the back, two gantry cranes with team
-- bands, cyan pier lights. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 38, 0.6, 8 }, at = { 0, 0.3, 15 }, color = "dark" },
	{ name = "pierL", parent = "base", shape = "box", size = { 5, 3, 33 }, at = { -16.5, 1.5, -1.5 }, color = "hull" },
	{ name = "pierR", parent = "base", shape = "box", size = { 5, 3, 33 }, at = { 16.5, 1.5, -1.5 }, color = "hull" },
	{ name = "pierTipL", parent = "base", shape = "wedge", size = { 5, 3, 3 }, at = { -16.5, 1.5, -19.5 }, color = "hull" },
	{ name = "pierTipR", parent = "base", shape = "wedge", size = { 5, 3, 3 }, at = { 16.5, 1.5, -19.5 }, color = "hull" },
	{ name = "hall", parent = "base", shape = "box", size = { 28, 10, 7 }, at = { 0, 5.6, 15 }, color = "hull" },
	{ name = "hallTeam", parent = "base", shape = "box", size = { 22, 0.12, 5 }, at = { 0, 10.66, 15 }, color = "team" },
	{ name = "door", parent = "base", shape = "box", size = { 20, 8, 0.3 }, at = { 0, 4.6, 11.4 }, color = "dark" },
	{ name = "lightL", parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { -16.5, 3.4, -17 }, color = "glass" },
	{ name = "lightR", parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { 16.5, 3.4, -17 }, color = "glass" },
	-- T2 signature (T1 vs T2 check, 2026-10-22): a covered building dock over
	-- the slip, walls on the piers and a ribbed roof
	{ name = "dockWallL", parent = "base", shape = "box", size = { 1.2, 9.4, 18 }, at = { -16.5, 7.7, 1 }, color = "hull" },
	{ name = "dockWallR", parent = "base", shape = "box", size = { 1.2, 9.4, 18 }, at = { 16.5, 7.7, 1 }, color = "hull" },
	{ name = "dockRoof", parent = "base", shape = "box", size = { 34.2, 1, 18 }, at = { 0, 12.9, 1 }, color = "hull" },
	{ name = "dockRoofTeam", parent = "base", shape = "box", size = { 24, 0.12, 8 }, at = { 0, 13.46, 1 }, color = "team" },
	{ name = "dockRibA", parent = "base", shape = "box", size = { 34.2, 0.5, 0.6 }, at = { 0, 13.65, -6.5 }, color = "dark" },
	{ name = "dockRibB", parent = "base", shape = "box", size = { 34.2, 0.5, 0.6 }, at = { 0, 13.65, 8.5 }, color = "dark" },
}
for i, z in { -15 } do
	table.insert(parts, { name = `craneLegL{i}`, parent = "base", shape = "box", size = { 1, 11, 1 }, at = { -16.5, 8.5, z }, color = "metal" })
	table.insert(parts, { name = `craneLegR{i}`, parent = "base", shape = "box", size = { 1, 11, 1 }, at = { 16.5, 8.5, z }, color = "metal" })
	table.insert(parts, { name = `craneBeam{i}`, parent = "base", shape = "box", size = { 34, 1.4, 1.6 }, at = { 0, 14.6, z }, color = "hull" })
	table.insert(parts, { name = `craneTeam{i}`, parent = "base", shape = "box", size = { 20, 0.1, 1.2 }, at = { 0, 15.35, z }, color = "team" })
end

-- footprint 5 -> 6 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_advshipyard",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0, 1 } },
		{ name = "nano1", parent = "base", at = { -8, 12.35, 1 } },
		{ name = "nano2", parent = "base", at = { 0, 12.35, 1 } },
		{ name = "nano3", parent = "base", at = { 8, 12.35, 1 } },
	},
}, 1.14)

--!strict
-- Skim Yard (Chaos hovercraft factory; stands on land or water): a deck on
-- pontoons, an open bay at the back, three cranes and a ramp, spiked corners. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "chs_skimyard",
	parts = {
		{ name = "base", shape = "box", size = { 22, 1, 22 }, at = { 0, 0.5, 0 }, color = "dark" },
		{ name = "pontoonL", parent = "base", shape = "box", size = { 2.2, 1.6, 22 }, at = { -9.9, 0.8, 0 }, color = "hull" },
		{ name = "pontoonR", parent = "base", shape = "box", size = { 2.2, 1.6, 22 }, at = { 9.9, 0.8, 0 }, color = "hull" },
		{ name = "ramp", parent = "base", shape = "wedge", size = { 11, 0.9, 3 }, at = { 0, 0.45, -12.5 }, color = "metal" },
		{ name = "bay", parent = "base", shape = "box", size = { 13.64, 6, 8.36 }, at = { 0, 4, 6.05 }, color = "hull" },
		{ name = "bayRoof", parent = "base", shape = "box", size = { 14.52, 0.5, 9.24 }, at = { 0, 7.2, 6.05 }, color = "dark" },
		{ name = "crane1", parent = "base", shape = "box", size = { 0.8, 6.4, 0.8 }, at = { -6.82, 4.2, -1.1 }, color = "metal" },
		{ name = "crane2", parent = "base", shape = "box", size = { 0.8, 6.4, 0.8 }, at = { 6.82, 4.2, -1.1 }, color = "metal" },
		{ name = "crane3", parent = "base", shape = "box", size = { 0.8, 7.6, 0.8 }, at = { 0, 4.8, 1.32 }, color = "metal" },
		{ name = "pad", parent = "base", shape = "box", size = { 10.56, 0.12, 10.56 }, at = { 0, 1.06, -2.2 }, color = "hazard" },
		{ name = "spikeL", parent = "base", shape = "wedge", size = { 0.6, 3, 1.2 }, at = { -10.45, 2.5, -9.9 }, color = "metal" },
		{ name = "spikeR", parent = "base", shape = "wedge", size = { 0.6, 3, 1.2 }, at = { 10.45, 2.5, -9.9 }, color = "metal" },
	},
	attachments = {
		{ name = "nano1", parent = "base", at = { -6.82, 7.6, -2.75 } },
		{ name = "nano2", parent = "base", at = { 6.82, 7.6, -2.75 } },
		{ name = "nano3", parent = "base", at = { 0, 8.8, 0.22 } },
		{ name = "buildpad", parent = "base", at = { 0, 1.1, -2.2 } },
	},
}

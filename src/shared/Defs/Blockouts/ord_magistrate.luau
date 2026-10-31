--!strict
-- Magistrate (Order combat engineer, T2): a heavier tracked hull with a dozer
-- blade, a constructor arm (`nano`) and a light gun turret behind it. Model space, forward = -Z (docs/contracts/rig.md). Batch 1 of the BAR roster (2026-10-31): drawn from the role ahead of the def.

return {
	id = "ord_magistrate",
	parts = {
		{ name = "base", shape = "box", size = { 3.56, 1.2, 8.4 }, at = { 0, 1.1, 0 }, color = "hull" },
		{ name = "glacis", parent = "base", shape = "wedge", size = { 3.56, 0.96, 1.512 }, at = { 0, 1.22, -4.956 }, color = "hull" },
		{ name = "trackL", parent = "base", shape = "box", size = { 1.12, 1.34, 8.736 }, at = { -2.24, 0.67, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtL", parent = "base", shape = "box", size = { 0.25, 0.84, 7.56 }, at = { -2.92, 1.16, 0 }, color = "hull" },
		{ name = "trackR", parent = "base", shape = "box", size = { 1.12, 1.34, 8.736 }, at = { 2.24, 0.67, 0 }, color = "track", anim = { motion = "scroll", axis = { 1, 0, 0 } } },
		{ name = "skirtR", parent = "base", shape = "box", size = { 0.25, 0.84, 7.56 }, at = { 2.92, 1.16, 0 }, color = "hull" },
		{ name = "blade", parent = "base", shape = "box", size = { 5.8, 1.2, 0.3 }, at = { 0, 1, -4.9 }, rot = { -15, 0, 0 }, color = "metal" },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.5, 1.4 }, at = { -1.2, 1.95, -0.8 }, color = "dark" },
		{ name = "boom", parent = "nano", shape = "box", size = { 0.5, 0.5, 3.4 }, at = { -1.2, 2.7, -2.5 }, rot = { -20, 0, 0 }, color = "team" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.7, 0.7, 0.7 }, at = { -1.2, 3.25, -4.2 }, color = "glass" },
		{ name = "turret", parent = "base", shape = "box", size = { 1.8, 0.7, 1.8 }, at = { 0, 2.05, 2 }, color = "hull" },
		{ name = "turretFront", parent = "turret", shape = "wedge", size = { 1.8, 0.7, 0.54 }, at = { 0, 2.05, 0.83 }, color = "hull" },
		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 0.24, 0.24, 2 }, at = { 0, 2.05, 0.1 }, pivot = { 0, 2.05, 1.1 }, color = "metal" },
	},
	attachments = {
		{ name = "nano1", parent = "nano", at = { -1.2, 3.25, -4.5 } },
		{ name = "muzzle", parent = "barrel", at = { 0, 2.05, -0.9 } },
	},
}

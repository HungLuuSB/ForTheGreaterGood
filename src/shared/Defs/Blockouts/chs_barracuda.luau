--!strict
-- Barracuda (Chaos corvette, T1, footprint 1): a low hull, a squat
-- bridge with a slit and a funnel, an open gun mount forward
-- (`turret1`), a small aft mount (`turret2`), a lattice mast.
-- Model space, forward = -Z.

return {
	id = "chs_barracuda",
	parts = {
		{ name = "base", shape = "box", size = { 3.2, 1.8, 9.2 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 3.2, 1.8, 2.024 }, at = { 0, 0.4, -5.612 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 3.3, 0.3, 9.2 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 2.24, 0.08, 0.736 }, at = { 0, 1.34, 3.312 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 1.92, 1.04, 1.76 }, at = { 0, 1.82, 0.6 }, color = "hull" },
		{ name = "bridgeSlit", parent = "base", shape = "box", size = { 1.44, 0.2, 0.08 }, at = { 0, 2.145, -0.32 }, color = "glass" },
		{ name = "funnel", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 1.6, 0.9 }, at = { 0.48, 2.94, 1.7 }, color = "metal" },
		{ name = "turret1", parent = "base", shape = "cylinder", axis = "y", size = { 1.4, 0.8, 1.4 }, at = { 0, 1.7, -2.6 }, pivot = { 0, 1.3, -2.6 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.92 }, at = { 0, 1.7, -4.36 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 0.6, 0.9 }, at = { 0, 1.6, 3.3 }, pivot = { 0, 1.3, 3.3 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.8 }, at = { 0, 1.6, 2.45 }, color = "metal" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.25, 1.8, 0.25 }, at = { 0, 3.2, 1.2 }, color = "dark" },
		{ name = "mastBrace", parent = "base", shape = "box", size = { 0.15, 1.44, 0.15 }, at = { 0.5, 3.02, 1.2 }, rot = { 0, 0, 8 }, color = "dark" },
		{ name = "mastPanel", parent = "base", shape = "box", size = { 1.4, 0.8, 0.15 }, at = { 0, 3.8, 1.2 }, color = "dark" },
		{ name = "mastLight", parent = "base", shape = "box", size = { 0.3, 0.3, 0.3 }, at = { 0, 4.4, 1.2 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 1.7, -5.42 } },
		{ name = "muzzle2", parent = "turret2", at = { 0, 1.6, 1.95 } },
	},
}

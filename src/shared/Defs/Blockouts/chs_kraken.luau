--!strict
-- Kraken (Chaos cruiser, T2, footprint 3): a low long hull, a triple open
-- gun mount forward (`turret1`), flak aft (`turret2`), a squat bridge with
-- funnel and lattice mast. Model space, forward = -Z.

return {
	id = "chs_kraken",
	parts = {
		{ name = "base", shape = "box", size = { 7.6, 2.6, 24.5 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 7.6, 2.6, 5.39 }, at = { 0, 0.8, -14.945 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 7.7, 0.3, 24.5 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 5.32, 0.08, 1.96 }, at = { 0, 2.14, 8.82 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 3.648, 2.08, 4.8 }, at = { 0, 3.14, 1.2 }, color = "hull" },
		{ name = "bridgeSlit", parent = "base", shape = "box", size = { 2.736, 0.2, 0.08 }, at = { 0, 3.79, -1.24 }, color = "glass" },
		{ name = "funnel", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 1.6, 0.9 }, at = { 0.912, 4.78, 4.2 }, color = "metal" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.25, 4, 0.25 }, at = { 0, 6.1, 2.4 }, color = "dark" },
		{ name = "mastBrace", parent = "base", shape = "box", size = { 0.15, 3.2, 0.15 }, at = { 0.5, 5.7, 2.4 }, rot = { 0, 0, 8 }, color = "dark" },
		{ name = "mastPanel", parent = "base", shape = "box", size = { 1.4, 0.8, 0.15 }, at = { 0, 7.8, 2.4 }, color = "dark" },
		{ name = "mastLight", parent = "base", shape = "box", size = { 0.3, 0.3, 0.3 }, at = { 0, 8.4, 2.4 }, color = "glass" },
		{ name = "turret1", parent = "base", shape = "cylinder", axis = "y", size = { 3, 1.4, 3 }, at = { 0, 2.8, -7 }, pivot = { 0, 2.1, -7 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 4.4 }, at = { -0.45, 2.8, -10.7 }, color = "metal" },
		{ name = "turret1Barrel1", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 4.4 }, at = { 0, 2.8, -10.7 }, color = "metal" },
		{ name = "turret1Barrel2", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 4.4 }, at = { 0.45, 2.8, -10.7 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 0.8, 1.6 }, at = { 0, 2.5, 7.6 }, pivot = { 0, 2.1, 7.6 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.6 }, at = { -0.225, 2.5, 6 }, color = "metal" },
		{ name = "turret2Barrel1", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.6 }, at = { 0.225, 2.5, 6 }, color = "metal" },
		{ name = "aftMount", parent = "base", shape = "box", size = { 2.4, 1.2, 2.6 }, at = { 0, 2.7, 4.6 }, color = "hull" },
		{ name = "aftBarrels", parent = "base", shape = "box", size = { 1, 0.4, 3 }, at = { 0, 2.9, 2.4 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 2.8, -13 } },
		{ name = "muzzle2", parent = "turret2", at = { 0, 2.5, 5.1 } },
	},
}

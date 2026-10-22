--!strict
-- Crusader (Order destroyer, T2, footprint 3): a faceted hull, a tall
-- block superstructure with a glass band and solid mast, a gun house
-- forward (`turret1`), an ASW torpedo mount (`turret2`), a VLS block
-- (`launcher`) with team cells. Model space, forward = -Z.

return {
	id = "ord_crusader",
	parts = {
		{ name = "base", shape = "box", size = { 8.6, 2.6, 24 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 8.6, 2.6, 5.28 }, at = { 0, 0.8, -14.64 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 8.7, 0.3, 24 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 4.3, 0.08, 2.88 }, at = { 0, 2.14, -7.2 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 5.16, 3.2, 6 }, at = { 0, 3.7, 1.2 }, color = "hull" },
		{ name = "bridgeGlass", parent = "base", shape = "box", size = { 4.128, 0.3, 0.08 }, at = { 0, 4.9, -1.84 }, color = "glass" },
		{ name = "bridgeTeam", parent = "base", shape = "box", size = { 3.612, 0.08, 3.6 }, at = { 0, 5.34, 1.2 }, color = "team" },
		{ name = "mast", parent = "base", shape = "box", size = { 1.2, 4, 1.2 }, at = { 0, 7.3, 2.4 }, color = "hull" },
		{ name = "mastArray", parent = "base", shape = "box", size = { 1.5, 1, 1.5 }, at = { 0, 8.5, 2.4 }, color = "dark" },
		{ name = "mastGlass", parent = "base", shape = "box", size = { 1.55, 0.25, 1.55 }, at = { 0, 8.5, 2.4 }, color = "glass" },
		{ name = "turret1", parent = "base", shape = "box", size = { 2.2, 1, 2.2 }, at = { 0, 2.6, -7 }, pivot = { 0, 2.1, -7 }, color = "hull" },
		{ name = "turret1Front", parent = "turret1", shape = "wedge", size = { 2.2, 1, 0.88 }, at = { 0, 2.6, -8.54 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 3 }, at = { 0, 2.6, -10.48 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "box", size = { 1.2, 0.6, 1.2 }, at = { 3.3, 2.4, 4.4 }, pivot = { 3.3, 2.1, 4.4 }, color = "hull" },
		{ name = "turret2Front", parent = "turret2", shape = "wedge", size = { 1.2, 0.6, 0.48 }, at = { 3.3, 2.4, 3.56 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1 }, at = { 3.075, 2.4, 2.82 }, color = "metal" },
		{ name = "turret2Barrel1", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1 }, at = { 3.525, 2.4, 2.82 }, color = "metal" },
		{ name = "launcher", parent = "base", shape = "box", size = { 2.6, 0.6, 2.4 }, at = { 0, 2.4, -3.6 }, pivot = { 0, 2.1, -3.6 }, color = "dark" },
		{ name = "cell00", parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { -0.8, 2.73, -4 }, color = "team" },
		{ name = "cell01", parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { -0.8, 2.73, -3.2 }, color = "metal" },
		{ name = "cell10", parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { 0, 2.73, -4 }, color = "metal" },
		{ name = "cell11", parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { 0, 2.73, -3.2 }, color = "team" },
		{ name = "cell20", parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { 0.8, 2.73, -4 }, color = "team" },
		{ name = "cell21", parent = "launcher", shape = "box", size = { 0.6, 0.06, 0.6 }, at = { 0.8, 2.73, -3.2 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 2.6, -12.08 } },
		{ name = "muzzle2", parent = "turret2", at = { 3.3, 2.4, 2.22 } },
		{ name = "muzzle3", parent = "launcher", at = { 0, 3.5, -3.6 } },
	},
}

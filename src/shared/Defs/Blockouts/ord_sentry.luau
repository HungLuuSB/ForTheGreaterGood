--!strict
-- Sentry (Order corvette, T1, footprint 1): a faceted hull, a tall boxy
-- bridge with a glass band and team roof, a gun house forward (`turret1`)
-- and a small aft mount (`turret2`), a solid mast.
-- Model space, forward = -Z.

return {
	id = "ord_sentry",
	parts = {
		{ name = "base", shape = "box", size = { 3.6, 1.8, 9 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 3.6, 1.8, 1.98 }, at = { 0, 0.4, -5.49 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 3.7, 0.3, 9 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 1.8, 0.08, 1.08 }, at = { 0, 1.34, -2.7 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 2.7, 1.6, 2.2 }, at = { 0, 2.1, 0.6 }, color = "hull" },
		{ name = "bridgeGlass", parent = "base", shape = "box", size = { 2.16, 0.3, 0.08 }, at = { 0, 2.5, -0.54 }, color = "glass" },
		{ name = "bridgeTeam", parent = "base", shape = "box", size = { 1.89, 0.08, 1.32 }, at = { 0, 2.94, 0.6 }, color = "team" },
		{ name = "turret1", parent = "base", shape = "box", size = { 1.4, 0.8, 1.6 }, at = { 0, 1.7, -2.6 }, pivot = { 0, 1.3, -2.6 }, color = "hull" },
		{ name = "turret1Front", parent = "turret1", shape = "wedge", size = { 1.4, 0.8, 0.64 }, at = { 0, 1.7, -3.72 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.92 }, at = { 0, 1.7, -5 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "box", size = { 0.9, 0.6, 0.9 }, at = { 0, 1.6, 3.3 }, pivot = { 0, 1.3, 3.3 }, color = "hull" },
		{ name = "turret2Front", parent = "turret2", shape = "wedge", size = { 0.9, 0.6, 0.36 }, at = { 0, 1.6, 2.67 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 0.8 }, at = { 0, 1.6, 2.09 }, color = "metal" },
		{ name = "mast", parent = "base", shape = "box", size = { 1.2, 1.8, 1.2 }, at = { 0, 3.8, 1.2 }, color = "hull" },
		{ name = "mastArray", parent = "base", shape = "box", size = { 1.5, 1, 1.5 }, at = { 0, 3.9, 1.2 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "mastGlass", parent = "base", shape = "box", size = { 1.55, 0.25, 1.55 }, at = { 0, 3.9, 1.2 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 1.7, -6.06 } },
		{ name = "muzzle2", parent = "turret2", at = { 0, 1.6, 1.59 } },
	},
}

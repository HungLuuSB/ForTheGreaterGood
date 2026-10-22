--!strict
-- Dominion (Order cruiser, T2, footprint 3): a big faceted hull, a triple
-- gun house forward (`turret1`), a flak mount aft (`turret2`), a second
-- triple mount aft (decoration), a tall block superstructure.
-- Model space, forward = -Z.

return {
	id = "ord_dominion",
	parts = {
		{ name = "base", shape = "box", size = { 8.6, 2.6, 24 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 8.6, 2.6, 5.28 }, at = { 0, 0.8, -14.64 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 8.7, 0.3, 24 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 4.3, 0.08, 2.88 }, at = { 0, 2.14, -7.2 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 5.16, 3.2, 6 }, at = { 0, 3.7, 1.2 }, color = "hull" },
		{ name = "bridgeGlass", parent = "base", shape = "box", size = { 4.128, 0.3, 0.08 }, at = { 0, 4.9, -1.84 }, color = "glass" },
		{ name = "bridgeTeam", parent = "base", shape = "box", size = { 3.612, 0.08, 3.6 }, at = { 0, 5.34, 1.2 }, color = "team" },
		{ name = "mast", parent = "base", shape = "box", size = { 1.2, 4, 1.2 }, at = { 0, 7.3, 2.4 }, color = "hull" },
		{ name = "mastArray", parent = "base", shape = "box", size = { 1.5, 1, 1.5 }, at = { 0, 8.5, 2.4 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "mastGlass", parent = "base", shape = "box", size = { 1.55, 0.25, 1.55 }, at = { 0, 8.5, 2.4 }, color = "glass" },
		{ name = "turret1", parent = "base", shape = "box", size = { 3, 1.4, 3 }, at = { 0, 2.8, -7 }, pivot = { 0, 2.1, -7 }, color = "hull" },
		{ name = "turret1Front", parent = "turret1", shape = "wedge", size = { 3, 1.4, 1.2 }, at = { 0, 2.8, -9.1 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 4.4 }, at = { -0.45, 2.8, -11.9 }, color = "metal" },
		{ name = "turret1Barrel1", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 4.4 }, at = { 0, 2.8, -11.9 }, color = "metal" },
		{ name = "turret1Barrel2", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 4.4 }, at = { 0.45, 2.8, -11.9 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "box", size = { 1.6, 0.8, 1.6 }, at = { 0, 2.5, 7.6 }, pivot = { 0, 2.1, 7.6 }, color = "hull" },
		{ name = "turret2Front", parent = "turret2", shape = "wedge", size = { 1.6, 0.8, 0.64 }, at = { 0, 2.5, 6.48 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.6 }, at = { -0.225, 2.5, 5.36 }, color = "metal" },
		{ name = "turret2Barrel1", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.6 }, at = { 0.225, 2.5, 5.36 }, color = "metal" },
		{ name = "aftMount", parent = "base", shape = "box", size = { 2.4, 1.2, 2.6 }, at = { 0, 2.7, 4.6 }, color = "hull" },
		{ name = "aftBarrels", parent = "base", shape = "box", size = { 1, 0.4, 3 }, at = { 0, 2.9, 2.4 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 2.8, -14.2 } },
		{ name = "muzzle2", parent = "turret2", at = { 0, 2.5, 4.46 } },
	},
}

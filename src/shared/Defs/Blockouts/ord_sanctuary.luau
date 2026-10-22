--!strict
-- Sanctuary (Order carrier, T2, footprint 3): a full flight deck with
-- team pads, a tall island to starboard with a glass band and solid
-- radar mast, flak mounts fore and aft (`turret1`, `turret2`).
-- Model space, forward = -Z.

return {
	id = "ord_sanctuary",
	parts = {
		{ name = "base", shape = "box", size = { 8.6, 2.6, 24 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 8.6, 2.6, 5.28 }, at = { 0, 0.8, -14.64 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 8.7, 0.3, 24 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 4.3, 0.08, 2.88 }, at = { 0, 2.14, -7.2 }, color = "team" },
		{ name = "flightDeck", parent = "base", shape = "box", size = { 11, 0.4, 25 }, at = { 0, 2.5, -0.4 }, color = "dark" },
		{ name = "deckLine", parent = "base", shape = "box", size = { 0.3, 0.06, 24 }, at = { 0, 2.73, -0.4 }, color = "hull" },
		{ name = "padTeamA", parent = "base", shape = "box", size = { 2.4, 0.06, 2.4 }, at = { -1.6, 2.73, -6 }, color = "team" },
		{ name = "padTeamB", parent = "base", shape = "box", size = { 2.4, 0.06, 2.4 }, at = { -1.6, 2.73, 4 }, color = "team" },
		{ name = "island", parent = "base", shape = "box", size = { 2, 4.4, 5 }, at = { 4.1, 4.9, 2 }, color = "hull" },
		{ name = "islandGlass", parent = "base", shape = "box", size = { 2.05, 0.4, 5.05 }, at = { 4.1, 6.3, 2 }, color = "glass" },
		{ name = "mast", parent = "base", shape = "box", size = { 1.2, 2, 1.2 }, at = { 4.1, 8.1, 2.6 }, color = "hull" },
		{ name = "mastArray", parent = "base", shape = "box", size = { 1.5, 1, 1.5 }, at = { 4.1, 8.3, 2.6 }, color = "dark" },
		{ name = "mastGlass", parent = "base", shape = "box", size = { 1.55, 0.25, 1.55 }, at = { 4.1, 8.3, 2.6 }, color = "glass" },
		{ name = "turret1", parent = "base", shape = "box", size = { 1.2, 0.7, 1.2 }, at = { -3.3, 3.05, -9.5 }, pivot = { -3.3, 2.7, -9.5 }, color = "hull" },
		{ name = "turret1Front", parent = "turret1", shape = "wedge", size = { 1.2, 0.7, 0.48 }, at = { -3.3, 3.05, -10.34 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { -3.525, 3.05, -11.18 }, color = "metal" },
		{ name = "turret1Barrel1", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { -3.075, 3.05, -11.18 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "box", size = { 1.2, 0.7, 1.2 }, at = { -3.3, 3.05, 9 }, pivot = { -3.3, 2.7, 9 }, color = "hull" },
		{ name = "turret2Front", parent = "turret2", shape = "wedge", size = { 1.2, 0.7, 0.48 }, at = { -3.3, 3.05, 8.16 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { -3.525, 3.05, 7.32 }, color = "metal" },
		{ name = "turret2Barrel1", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { -3.075, 3.05, 7.32 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { -3.3, 3.05, -11.88 } },
		{ name = "muzzle2", parent = "turret2", at = { -3.3, 3.05, 6.62 } },
	},
}

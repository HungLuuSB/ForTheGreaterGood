--!strict
-- Leviathan (Chaos carrier, T2, footprint 3): an offset flight deck with
-- team pads, a low island to port with a lattice radar mast, flak
-- mounts fore and aft (`turret1`, `turret2`). Model space, forward = -Z.

return {
	id = "chs_leviathan",
	parts = {
		{ name = "base", shape = "box", size = { 7.6, 2.6, 24.5 }, at = { 0, 0.8, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 7.6, 2.6, 5.39 }, at = { 0, 0.8, -14.945 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 7.7, 0.3, 24.5 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 5.32, 0.08, 1.96 }, at = { 0, 2.14, 8.82 }, color = "team" },
		{ name = "flightDeck", parent = "base", shape = "box", size = { 10, 0.4, 25.5 }, at = { 0.6, 2.5, -0.4 }, color = "dark" },
		{ name = "deckLine", parent = "base", shape = "box", size = { 0.3, 0.06, 24.5 }, at = { 0.6, 2.73, -0.4 }, color = "hull" },
		{ name = "padTeamA", parent = "base", shape = "box", size = { 2.4, 0.06, 2.4 }, at = { -1.6, 2.73, -6 }, color = "team" },
		{ name = "padTeamB", parent = "base", shape = "box", size = { 2.4, 0.06, 2.4 }, at = { -1.6, 2.73, 4 }, color = "team" },
		{ name = "island", parent = "base", shape = "box", size = { 1.8, 3.4, 4.2 }, at = { -3.4, 4.4, 3 }, color = "hull" },
		{ name = "islandSlit", parent = "base", shape = "box", size = { 1.84, 0.3, 4.24 }, at = { -3.4, 5.3, 3 }, color = "glass" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.25, 3.4, 0.25 }, at = { -3.4, 7.8, 3 }, color = "dark" },
		{ name = "mastBrace", parent = "base", shape = "box", size = { 0.15, 2.72, 0.15 }, at = { -2.9, 7.46, 3 }, rot = { 0, 0, 8 }, color = "dark" },
		{ name = "mastPanel", parent = "base", shape = "box", size = { 1.4, 0.8, 0.15 }, at = { -3.4, 9.2, 3 }, color = "dark" },
		{ name = "mastLight", parent = "base", shape = "box", size = { 0.3, 0.3, 0.3 }, at = { -3.4, 9.8, 3 }, color = "glass" },
		{ name = "turret1", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 0.7, 1.2 }, at = { 3.4, 3.05, -9.5 }, pivot = { 3.4, 2.7, -9.5 }, color = "hull" },
		{ name = "turret1Barrel0", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { 3.175, 3.05, -10.7 }, color = "metal" },
		{ name = "turret1Barrel1", parent = "turret1", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { 3.625, 3.05, -10.7 }, color = "metal" },
		{ name = "turret2", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 0.7, 1.2 }, at = { 3.4, 3.05, 9 }, pivot = { 3.4, 2.7, 9 }, color = "hull" },
		{ name = "turret2Barrel0", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { 3.175, 3.05, 7.8 }, color = "metal" },
		{ name = "turret2Barrel1", parent = "turret2", shape = "cylinder", axis = "z", size = { 0.3, 0.3, 1.2 }, at = { 3.625, 3.05, 7.8 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 3.4, 3.05, -11.4 } },
		{ name = "muzzle2", parent = "turret2", at = { 3.4, 3.05, 7.1 } },
	},
}

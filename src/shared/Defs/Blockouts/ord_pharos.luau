--!strict
-- Pharos (Order naval SAM platform, T2, footprint 3, floats; sim-A's request):
-- a round armored caisson riding at the waterline (y = 0) with a team deck
-- ring, fenders and deck lights; a tall lighthouse tower (team band, gallery,
-- a glowing lantern room) crowned by the `launcher` (yaws and pitches): a
-- sensor head between two armored canister pods with ready-lit caps.
-- `muzzle` at the left pod's caps. Model space, forward = -Z.

return {
	id = "ord_pharos",
	parts = {
		{ name = "base", shape = "cylinder", axis = "y", size = { 22, 2.4, 22 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "deckRing", parent = "base", shape = "cylinder", axis = "y", size = { 19, 0.12, 19 }, at = { 0, 1.66, 0 }, color = "team" },
		{ name = "deck", parent = "base", shape = "cylinder", axis = "y", size = { 17, 0.16, 17 }, at = { 0, 1.7, 0 }, color = "hull" },
		{ name = "skirt", parent = "base", shape = "cylinder", axis = "y", size = { 22.6, 0.5, 22.6 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "fenderN", parent = "base", shape = "box", size = { 4, 1, 0.8 }, at = { 0, 0.6, -11.2 }, color = "dark" },
		{ name = "fenderS", parent = "base", shape = "box", size = { 4, 1, 0.8 }, at = { 0, 0.6, 11.2 }, color = "dark" },
		{ name = "fenderE", parent = "base", shape = "box", size = { 0.8, 1, 4 }, at = { 11.2, 0.6, 0 }, color = "dark" },
		{ name = "fenderW", parent = "base", shape = "box", size = { 0.8, 1, 4 }, at = { -11.2, 0.6, 0 }, color = "dark" },
		{ name = "light0", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -6.4, 2.0, -6.4 }, color = "glass" },
		{ name = "light1", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 6.4, 2.0, -6.4 }, color = "glass" },
		{ name = "light2", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -6.4, 2.0, 6.4 }, color = "glass" },
		{ name = "light3", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { 6.4, 2.0, 6.4 }, color = "glass" },
		{ name = "hazardF", parent = "base", shape = "box", size = { 6, 0.06, 0.6 }, at = { 0, 1.8, -7.6 }, color = "hazard" },
		-- reload magazine: two hatches on the deck behind the tower
		{ name = "magazine", parent = "base", shape = "box", size = { 5, 1.2, 3 }, at = { 0, 2.3, 6 }, color = "hull" },
		{ name = "magazineTeam", parent = "base", shape = "box", size = { 3.6, 0.08, 1.8 }, at = { 0, 2.94, 6 }, color = "team" },
		-- the lighthouse
		{ name = "towerLow", parent = "base", shape = "cylinder", axis = "y", size = { 6.4, 8, 6.4 }, at = { 0, 5.7, 0 }, color = "hull" },
		{ name = "towerBand", parent = "base", shape = "cylinder", axis = "y", size = { 6.5, 1, 6.5 }, at = { 0, 8.2, 0 }, color = "team" },
		{ name = "towerHigh", parent = "base", shape = "cylinder", axis = "y", size = { 4.8, 6, 4.8 }, at = { 0, 12.7, 0 }, color = "hull" },
		{ name = "door", parent = "base", shape = "box", size = { 1.4, 2.4, 0.3 }, at = { 0, 2.9, -3.15 }, color = "dark" },
		{ name = "window0", parent = "base", shape = "box", size = { 0.5, 1, 0.2 }, at = { 0, 11.5, -2.42 }, color = "glass" },
		{ name = "window1", parent = "base", shape = "box", size = { 0.5, 1, 0.2 }, at = { 0, 13.5, 2.42 }, color = "glass" },
		{ name = "gallery", parent = "base", shape = "cylinder", axis = "y", size = { 7.4, 0.4, 7.4 }, at = { 0, 15.9, 0 }, color = "dark" },
		{ name = "rail", parent = "base", shape = "cylinder", axis = "y", size = { 7.2, 0.9, 7.2 }, at = { 0, 16.55, 0 }, color = "metal" },
		{ name = "lantern", parent = "base", shape = "cylinder", axis = "y", size = { 3.8, 2.2, 3.8 }, at = { 0, 17.2, 0 }, color = "glass" },
		{ name = "lanternRoof", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 0.5, 4.4 }, at = { 0, 18.55, 0 }, color = "dark" },
		-- the launcher: turntable, sensor head, two canister pods
		{ name = "launcher", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 0.6, 3.4 }, at = { 0, 19.1, 0 }, pivot = { 0, 19.8, 0 }, color = "hull" },
		{ name = "sensor", parent = "launcher", shape = "box", size = { 1.4, 1.4, 1.6 }, at = { 0, 20.1, -0.4 }, color = "hull" },
		{ name = "seeker", parent = "launcher", shape = "box", size = { 0.8, 0.6, 0.2 }, at = { 0, 20.2, -1.25 }, color = "glass" },
		{ name = "podL", parent = "launcher", shape = "box", size = { 1.8, 1.8, 4.4 }, at = { -1.8, 20.2, -0.3 }, color = "hull" },
		{ name = "podR", parent = "launcher", shape = "box", size = { 1.8, 1.8, 4.4 }, at = { 1.8, 20.2, -0.3 }, color = "hull" },
		{ name = "podTeamL", parent = "launcher", shape = "box", size = { 1.4, 0.08, 3.4 }, at = { -1.8, 21.14, -0.3 }, color = "team" },
		{ name = "podTeamR", parent = "launcher", shape = "box", size = { 1.4, 0.08, 3.4 }, at = { 1.8, 21.14, -0.3 }, color = "team" },
		{ name = "capsL", parent = "launcher", shape = "box", size = { 1.5, 1.5, 0.1 }, at = { -1.8, 20.2, -2.55 }, color = "glass" },
		{ name = "capsR", parent = "launcher", shape = "box", size = { 1.5, 1.5, 0.1 }, at = { 1.8, 20.2, -2.55 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -1.8, 20.2, -2.7 } },
	},
}

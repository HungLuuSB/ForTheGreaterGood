--!strict
-- Scylla (Chaos naval SAM platform, T2, footprint 3, floats; sim-A's request):
-- a monstrous ruin afloat. Two rusted drum floats under a tilted deck of
-- broken slabs, ruined columns (one toppled), team plates; a crooked
-- pedestal with spikes and an amber eye slit. The `launcher` (yaws and
-- pitches) is the beast: a slab skull with six missile tubes fanned out like
-- necks, each mouth ringed in amber. `muzzle` at the middle tube's mouth.
-- Model space, forward = -Z.

return {
	id = "chs_scylla",
	parts = {
		{ name = "base", shape = "box", size = { 18, 0.9, 16 }, at = { 0, 1.5, 0 }, rot = { 0, 0, 2 }, color = "hull" },
		{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 5, 5, 21 }, at = { -7, -0.2, 0 }, color = "dark" },
		{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 4.6, 4.6, 19 }, at = { 7.2, -0.3, 0.6 }, color = "dark" },
		{ name = "strapL", parent = "base", shape = "box", size = { 5.4, 0.5, 0.6 }, at = { -7, 0.6, -4 }, color = "metal" },
		{ name = "strapR", parent = "base", shape = "box", size = { 5, 0.5, 0.6 }, at = { 7.2, 0.6, 5 }, color = "metal" },
		{ name = "slabA", parent = "base", shape = "wedge", size = { 6, 1.2, 4 }, at = { -6, 2.4, -6.6 }, rot = { 0, 20, 0 }, color = "hull" },
		{ name = "slabB", parent = "base", shape = "box", size = { 5, 0.8, 4 }, at = { 6, 2.2, 6 }, rot = { 0, -12, 6 }, color = "hull" },
		{ name = "teamF", parent = "base", shape = "box", size = { 5, 0.08, 1.6 }, at = { 0, 2.0, -6.4 }, color = "team" },
		{ name = "teamB", parent = "base", shape = "box", size = { 3, 0.08, 3 }, at = { -4.6, 2.0, 5.4 }, color = "team" },
		{ name = "hazard", parent = "base", shape = "box", size = { 6, 0.06, 0.5 }, at = { 3.4, 2.02, -7.4 }, color = "hazard" },
		-- ruined columns: two standing (one broken short), one toppled across the deck
		{ name = "columnA", parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 7, 1.8 }, at = { -7.4, 5.4, -6.2 }, color = "metal" },
		{ name = "capitalA", parent = "base", shape = "box", size = { 2.4, 0.6, 2.4 }, at = { -7.4, 9.2, -6.2 }, color = "metal" },
		{ name = "columnB", parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 3.4, 1.8 }, at = { 7.4, 3.6, -6 }, color = "metal" },
		{ name = "columnFallen", parent = "base", shape = "cylinder", axis = "x", size = { 7, 1.6, 1.6 }, at = { 3.4, 2.7, 5.6 }, rot = { 0, 25, 0 }, color = "metal" },
		{ name = "lampA", parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { -7.4, 9.75, -6.2 }, color = "glass" },
		-- the pedestal
		{ name = "pedestal", parent = "base", shape = "box", size = { 6, 5, 6 }, at = { 0, 4.4, 0 }, rot = { 0, 15, 0 }, color = "dark" },
		{ name = "plateL", parent = "base", shape = "box", size = { 0.6, 3.6, 4 }, at = { -3.3, 4.4, 0 }, rot = { 0, 15, 4 }, color = "hull" },
		{ name = "plateR", parent = "base", shape = "box", size = { 0.6, 3.6, 4 }, at = { 3.3, 4.4, 0 }, rot = { 0, 15, -4 }, color = "hull" },
		{ name = "eyeSlit", parent = "base", shape = "box", size = { 3, 0.4, 0.2 }, at = { -0.6, 5.6, -3.1 }, rot = { 0, 15, 0 }, color = "glass" },
		{ name = "spikeL", parent = "base", shape = "wedge", size = { 0.8, 2.6, 1.6 }, at = { -2.8, 8.1, 2.2 }, color = "metal" },
		{ name = "spikeR", parent = "base", shape = "wedge", size = { 0.8, 2.2, 1.6 }, at = { 2.8, 7.9, 2.4 }, color = "metal" },
		-- the beast: skull and six necks
		{ name = "launcher", parent = "base", shape = "box", size = { 4.2, 2.6, 3.6 }, at = { 0, 8.3, 0.4 }, pivot = { 0, 8.0, 0 }, color = "hull" },
		{ name = "jaw", parent = "launcher", shape = "wedge", size = { 4.2, 1.2, 2 }, at = { 0, 7.0, -1.6 }, rot = { 0, 180, 0 }, color = "dark" },
		{ name = "skullTeam", parent = "launcher", shape = "box", size = { 2.8, 0.08, 2.2 }, at = { 0, 9.64, 0.6 }, color = "team" },
		{ name = "neck0", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.6 }, at = { -1.5, 9.1, -3.4 }, rot = { 0, 12, 0 }, color = "metal" },
		{ name = "neck1", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 5 }, at = { 0, 9.3, -3.7 }, color = "metal" },
		{ name = "neck2", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.6 }, at = { 1.5, 9.1, -3.4 }, rot = { 0, -12, 0 }, color = "metal" },
		{ name = "neck3", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.2 }, at = { -1.6, 7.9, -3.2 }, rot = { 0, 18, 0 }, color = "metal" },
		{ name = "neck4", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.4 }, at = { 0, 7.8, -3.4 }, color = "metal" },
		{ name = "neck5", parent = "launcher", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 4.2 }, at = { 1.6, 7.9, -3.2 }, rot = { 0, -18, 0 }, color = "metal" },
		{ name = "mouth0", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.2 }, at = { -1.97, 9.1, -5.65 }, rot = { 0, 12, 0 }, color = "glass" },
		{ name = "mouth1", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.2 }, at = { 0, 9.3, -6.25 }, color = "glass" },
		{ name = "mouth2", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.2 }, at = { 1.97, 9.1, -5.65 }, rot = { 0, -12, 0 }, color = "glass" },
		{ name = "mouth3", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.2 }, at = { -2.25, 7.9, -5.2 }, rot = { 0, 18, 0 }, color = "glass" },
		{ name = "mouth4", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.2 }, at = { 0, 7.8, -5.7 }, color = "glass" },
		{ name = "mouth5", parent = "launcher", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 0.2 }, at = { 2.25, 7.9, -5.2 }, rot = { 0, -18, 0 }, color = "glass" },
		{ name = "hornL", parent = "launcher", shape = "wedge", size = { 0.6, 1.8, 2.4 }, at = { -2.0, 10.3, 1.0 }, color = "dark" },
		{ name = "hornR", parent = "launcher", shape = "wedge", size = { 0.6, 1.8, 2.4 }, at = { 2.0, 10.3, 1.0 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { 0, 9.3, -6.4 } },
	},
}

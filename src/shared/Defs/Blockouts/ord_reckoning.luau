--!strict
-- Reckoning (Order nuclear silo, T3, footprint 3): a stepped square armored
-- bunker with sloped blast walls on every side, a heavy hatch (hinged at its
-- back edge) over the silo, team plates on the upper block. Order reads
-- heavy and fortress-like (M-14). Model space, forward = -Z
-- (docs/contracts/rig.md).

return {
	id = "ord_reckoning",
	parts = {
		{ name = "base", shape = "box", size = { 20, 1.2, 20 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, -11 }, color = "hull" },
		{ name = "wallB", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, 11 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "wallL", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { -11, 0.7, 0 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "wallR", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 11, 0.7, 0 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "block", parent = "base", shape = "box", size = { 14, 1.4, 14 }, at = { 0, 1.9, 0 }, color = "hull" },
		{ name = "collar", parent = "base", shape = "cylinder", axis = "y", size = { 8.4, 0.4, 8.4 }, at = { 0, 2.8, 0 }, color = "dark" },
		{ name = "teamNW", parent = "base", shape = "box", size = { 3.2, 0.1, 3.2 }, at = { -5, 2.65, -5 }, color = "team" },
		{ name = "teamNE", parent = "base", shape = "box", size = { 3.2, 0.1, 3.2 }, at = { 5, 2.65, -5 }, color = "team" },
		{ name = "teamSW", parent = "base", shape = "box", size = { 3.2, 0.1, 3.2 }, at = { -5, 2.65, 5 }, color = "team" },
		{ name = "teamSE", parent = "base", shape = "box", size = { 3.2, 0.1, 3.2 }, at = { 5, 2.65, 5 }, color = "team" },
		{ name = "ventL", parent = "base", shape = "box", size = { 1.2, 0.3, 4 }, at = { -5.8, 2.75, 0 }, color = "dark" },
		{ name = "ventR", parent = "base", shape = "box", size = { 1.2, 0.3, 4 }, at = { 5.8, 2.75, 0 }, color = "dark" },
		{ name = "lightNW", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -9.3, 1.5, -9.3 }, color = "glass" },
		{ name = "lightNE", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 9.3, 1.5, -9.3 }, color = "glass" },
		{ name = "lightSW", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -9.3, 1.5, 9.3 }, color = "glass" },
		{ name = "lightSE", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 9.3, 1.5, 9.3 }, color = "glass" },
		{ name = "mast", parent = "base", shape = "box", size = { 0.25, 3.5, 0.25 }, at = { 6.3, 4.3, 6.3 }, color = "dark" },

		-- hatch: swings up about its back edge
		{ name = "hatch", parent = "base", shape = "box", size = { 7, 0.6, 7 }, at = { 0, 3.3, 0 }, pivot = { 0, 3.3, 3.5 }, color = "metal" },
		{ name = "hatchStripe", parent = "hatch", shape = "box", size = { 5, 0.08, 1.2 }, at = { 0, 3.64, 0 }, color = "team" },
	},
	attachments = {
		{ name = "muzzle", parent = "base", at = { 0, 2.8, 0 } },
	},
}

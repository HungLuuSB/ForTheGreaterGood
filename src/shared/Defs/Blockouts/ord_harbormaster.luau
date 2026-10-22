--!strict
-- Harbormaster (Order advanced naval builder, T2, footprint 1): the
-- Tidewright hull with a second `nano` arm and emitter and a deck crane.
-- Model space, forward = -Z.

return {
	id = "ord_harbormaster",
	parts = {
		{ name = "base", shape = "box", size = { 3.6, 1.8, 9 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 3.6, 1.8, 1.98 }, at = { 0, 0.4, -5.49 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 3.7, 0.3, 9 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 1.8, 0.08, 1.08 }, at = { 0, 1.34, -2.7 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 2.7, 1.6, 2.2 }, at = { 0, 2.1, 0.6 }, color = "hull" },
		{ name = "bridgeGlass", parent = "base", shape = "box", size = { 2.16, 0.3, 0.08 }, at = { 0, 2.5, -0.54 }, color = "glass" },
		{ name = "bridgeTeam", parent = "base", shape = "box", size = { 1.89, 0.08, 1.32 }, at = { 0, 2.94, 0.6 }, color = "team" },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 0.4, 1.6 }, at = { 0, 1.5, 2.8 }, color = "team" },
		{ name = "crane", parent = "nano", shape = "box", size = { 0.4, 0.4, 3.4 }, at = { 0, 2.6, 1.6 }, rot = { 30, 0, 0 }, color = "dark" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.8, 0.8, 0.8 }, at = { 0, 3.5, 0.1 }, color = "glass" },
		{ name = "cargo", parent = "base", shape = "box", size = { 2.16, 0.6, 1.6 }, at = { 0, 1.6, -2.6 }, color = "dark" },
		{ name = "crane2", parent = "nano", shape = "box", size = { 0.4, 0.4, 2.4 }, at = { 0, 2.3, 3.8 }, rot = { -30, 0, 0 }, color = "dark" },
		{ name = "emitter2", parent = "nano", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 0, 3, 4.8 }, color = "glass" },
		{ name = "deckCrane", parent = "base", shape = "box", size = { 0.3, 2.4, 0.3 }, at = { 1.08, 2.5, -1.4 }, color = "dark" },
		{ name = "deckJib", parent = "base", shape = "box", size = { 0.3, 0.3, 2.4 }, at = { 1.08, 3.6, -2.4 }, color = "dark" },
	},
}

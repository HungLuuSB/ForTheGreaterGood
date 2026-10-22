--!strict
-- Reaver (Chaos advanced naval builder, T2, footprint 1): the Wrecker
-- hull with a second `nano` arm and emitter and a deck crane.
-- Model space, forward = -Z.

return {
	id = "chs_reaver",
	parts = {
		{ name = "base", shape = "box", size = { 3.2, 1.8, 9.2 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 3.2, 1.8, 2.024 }, at = { 0, 0.4, -5.612 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 3.3, 0.3, 9.2 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 2.24, 0.08, 0.736 }, at = { 0, 1.34, 3.312 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 1.92, 1.04, 1.76 }, at = { 0, 1.82, 0.6 }, color = "hull" },
		{ name = "bridgeSlit", parent = "base", shape = "box", size = { 1.44, 0.2, 0.08 }, at = { 0, 2.145, -0.32 }, color = "glass" },
		{ name = "funnel", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 1.6, 0.9 }, at = { 0.48, 2.94, 1.7 }, color = "metal" },
		{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 0.4, 1.6 }, at = { 0, 1.5, 2.8 }, color = "team" },
		{ name = "crane", parent = "nano", shape = "box", size = { 0.4, 0.4, 3.4 }, at = { 0, 2.6, 1.6 }, rot = { 30, 0, 0 }, color = "dark" },
		{ name = "emitter", parent = "nano", shape = "ball", size = { 0.8, 0.8, 0.8 }, at = { 0, 3.5, 0.1 }, color = "glass" },
		{ name = "cargo", parent = "base", shape = "box", size = { 1.92, 0.6, 1.6 }, at = { 0, 1.6, -2.6 }, color = "dark" },
		{ name = "crane2", parent = "nano", shape = "box", size = { 0.4, 0.4, 2.4 }, at = { 0, 2.3, 3.8 }, rot = { -30, 0, 0 }, color = "dark" },
		{ name = "emitter2", parent = "nano", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 0, 3, 4.8 }, color = "glass" },
		{ name = "deckCrane", parent = "base", shape = "box", size = { 0.3, 2.4, 0.3 }, at = { 0.96, 2.5, -1.4 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "deckJib", parent = "base", shape = "box", size = { 0.3, 0.3, 2.4 }, at = { 0.96, 3.6, -2.4 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	},
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0, 3.5, 0.1 } },
		{ name = "nano2", parent = "nano", at = { 0, 3, 4.8 } },
	},
}

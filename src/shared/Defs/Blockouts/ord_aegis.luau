--!strict
-- Aegis (Order radar SAM site, T2, footprint 3): an armored base, a turntable
-- on a pedestal carrying an upright pack of canister cells that launch
-- straight up (the user: radar SAMs launch vertically), and a flat
-- engagement radar panel on its own block. The def turns `launcher` on the
-- pedestal's axis (M-3). Matches the mesh's layout (assets/models/ord_aegis).
-- Model space, forward = -Z.

return {
	id = "ord_aegis",
	parts = {
		{ name = "base", shape = "box", size = { 20, 1.4, 20 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, -11 }, color = "hull" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 4.4, 2, 4.4 }, at = { -3, 2.4, 1 }, color = "dark" },
		{ name = "radarBlock", parent = "base", shape = "box", size = { 4.4, 3.4, 4.4 }, at = { 6, 3.1, 5 }, color = "hull" },
		{ name = "radarPanel", parent = "base", shape = "box", size = { 5.4, 4, 0.5 }, at = { 6, 6.8, 4.6 }, rot = { 15, 0, 0 }, color = "dark", anim = { motion = "turn", axis = { 0, 1, 0 } } },
		{ name = "radarFace", parent = "base", shape = "box", size = { 4.8, 3.4, 0.1 }, at = { 6, 6.85, 4.27 }, rot = { 15, 0, 0 }, color = "glass" },
		{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 6, 1.45, -6 }, color = "team" },

		{ name = "launcher", parent = "base", shape = "cylinder", axis = "y", size = { 5, 0.6, 5 }, at = { -3, 3.7, 1 }, pivot = { -3, 3.4, 1 }, color = "metal" },
		{ name = "pack", parent = "launcher", shape = "box", size = { 4.4, 7, 4.4 }, at = { -3, 7.4, 1 }, color = "hull" },
		{ name = "packTeam", parent = "launcher", shape = "box", size = { 0.1, 4, 3.4 }, at = { -5.25, 7.4, 1 }, color = "team" },
		{ name = "cells", parent = "launcher", shape = "box", size = { 3.8, 0.12, 3.8 }, at = { -3, 10.95, 1 }, color = "dark" },
		{ name = "sensor", parent = "launcher", shape = "box", size = { 1.2, 0.4, 0.1 }, at = { -3, 9.6, -1.25 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -4.15, 10.95, 2.15 } },
	},
}

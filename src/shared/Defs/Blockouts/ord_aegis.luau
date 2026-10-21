--!strict
-- Aegis (Order radar SAM site, T2, footprint 3): an armored base, a launcher
-- of four closed canister cells on a pedestal (turned by the def, on the
-- pedestal's axis, M-3) and a flat engagement radar panel on its own block.
-- Model space, forward = -Z.

return {
	id = "ord_aegis",
	parts = {
		{ name = "base", shape = "box", size = { 20, 1.4, 20 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "wallF", parent = "base", shape = "wedge", size = { 20, 1.4, 2 }, at = { 0, 0.7, -11 }, color = "hull" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 2, 3.4 }, at = { -3, 2.4, 1 }, color = "dark" },
		{ name = "radarBlock", parent = "base", shape = "box", size = { 4.4, 3, 4.4 }, at = { 6, 2.9, 5 }, color = "hull" },
		{ name = "radarPanel", parent = "base", shape = "box", size = { 5.4, 4, 0.5 }, at = { 6, 6.4, 4.6 }, rot = { 15, 0, 0 }, color = "dark" },
		{ name = "radarFace", parent = "base", shape = "box", size = { 4.8, 3.4, 0.1 }, at = { 6, 6.45, 4.27 }, rot = { 15, 0, 0 }, color = "glass" },
		{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { 6, 1.45, -6 }, color = "team" },

		{ name = "launcher", parent = "base", shape = "box", size = { 6, 3.6, 5 }, at = { -3, 5.2, 0.6 }, pivot = { -3, 3.4, 1 }, color = "hull" },
		{ name = "launcherTeam", parent = "launcher", shape = "box", size = { 5, 0.1, 4 }, at = { -3, 7.05, 0.6 }, color = "team" },
		{ name = "cells", parent = "launcher", shape = "box", size = { 5.4, 3, 0.12 }, at = { -3, 5.2, -1.95 }, color = "dark" },
		{ name = "sensor", parent = "launcher", shape = "box", size = { 1.2, 0.4, 0.1 }, at = { -3, 6.65, -1.98 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -4.3, 5.9, -2.1 } },
	},
}

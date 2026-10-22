--!strict
-- Vehicle Plant (Order factory, T1, footprint 3): a closed armored hall with
-- sloped buttresses, a big front door over a ramp, team plates on the roof,
-- a cyan light strip over the door. Order reads heavy (M-14).
-- Model space, forward = -Z (docs/contracts/rig.md).

-- footprint 3 -> 4 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_vehplant",
	parts = {
		{ name = "base", shape = "box", size = { 22, 0.6, 22 }, at = { 0, 0.3, 0 }, color = "dark" },
		{ name = "hall", parent = "base", shape = "box", size = { 18, 6, 14 }, at = { 0, 3.6, 2.5 }, color = "hull" },
		{ name = "roofEdgeF", parent = "base", shape = "wedge", size = { 18, 1.2, 1.4 }, at = { 0, 7.2, -3.8 }, color = "hull" },
		{ name = "roof", parent = "base", shape = "box", size = { 18, 1.2, 12.6 }, at = { 0, 7.2, 3.2 }, color = "hull" },
		{ name = "roofTeamL", parent = "base", shape = "box", size = { 7, 0.12, 9 }, at = { -4.4, 7.86, 3.4 }, color = "team" },
		{ name = "roofTeamR", parent = "base", shape = "box", size = { 7, 0.12, 9 }, at = { 4.4, 7.86, 3.4 }, color = "team" },
		{ name = "door", parent = "base", shape = "box", size = { 10, 5, 0.3 }, at = { 0, 3.1, -4.6 }, color = "dark" },
		{ name = "doorLight", parent = "base", shape = "box", size = { 10, 0.3, 0.12 }, at = { 0, 5.9, -4.8 }, color = "glass" },
		{ name = "ramp", parent = "base", shape = "wedge", size = { 12, 0.6, 5 }, at = { 0, 0.9, -7.2 }, color = "metal" },
		{ name = "buttressL", parent = "base", shape = "wedge", size = { 3, 5, 3 }, at = { -10.5, 3.1, -3.6 }, rot = { 0, 90, 0 }, color = "hull" },
		{ name = "buttressR", parent = "base", shape = "wedge", size = { 3, 5, 3 }, at = { 10.5, 3.1, -3.6 }, rot = { 0, -90, 0 }, color = "hull" },
		{ name = "vent", parent = "base", shape = "box", size = { 6, 1, 3 }, at = { 0, 8.3, 7 }, color = "metal" },
		{ name = "beaconL", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { -10, 1.2, -10 }, color = "glass" },
		{ name = "beaconR", parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { 10, 1.2, -10 }, color = "glass" },
	},
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0.6, -7.4 } },
		{ name = "nano1", parent = "base", at = { -5.12, 5.5, -4.8 } },
		{ name = "nano2", parent = "base", at = { 5.12, 5.5, -4.8 } },
		{ name = "nano3", parent = "base", at = { 0, 5.85, -4.8 } },
	},
}, 1.333)

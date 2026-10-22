--!strict
-- Wind Turbine (Order, T1, footprint 1): a tall tapered tower on an armored
-- base, a nacelle with a team band, a three-blade rotor (visual piece,
-- spun by a piece script) and a cyan light on the nacelle.
-- Model space, forward = -Z (docs/contracts/rig.md).

-- footprint 1 -> 2 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({
	id = "ord_windmill",
	visualPieces = { "rotor" },
	parts = {
		{ name = "base", shape = "box", size = { 5, 1, 5 }, at = { 0, 0.5, 0 }, color = "hull" },
		{ name = "tower", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 10, 1.2 }, at = { 0, 6, 0 }, color = "hull" },
		{ name = "nacelle", parent = "base", shape = "box", size = { 1.6, 1.4, 3.2 }, at = { 0, 11.6, 0.4 }, color = "hull" },
		{ name = "band", parent = "base", shape = "box", size = { 1.7, 0.4, 2 }, at = { 0, 12.1, 0.6 }, color = "team" },
		{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.3, 0.4 }, at = { 0, 12.45, 1.6 }, color = "glass" },
		{ name = "rotor", parent = "base", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 0.8 }, at = { 0, 11.6, -1.6 }, color = "metal", anim = { motion = "spin", axis = { 0, 0, 1 } } },
		{ name = "blade1", parent = "rotor", shape = "box", size = { 0.5, 6, 0.15 }, at = { 0, 14.6, -1.75 }, color = "hull" },
		{ name = "blade2", parent = "rotor", shape = "box", size = { 0.5, 6, 0.15 }, at = { -2.6, 10.1, -1.75 }, rot = { 0, 0, 120 }, color = "hull" },
		{ name = "blade3", parent = "rotor", shape = "box", size = { 0.5, 6, 0.15 }, at = { 2.6, 10.1, -1.75 }, rot = { 0, 0, -120 }, color = "hull" },
	},
}, 1.407)

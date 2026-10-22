--!strict
-- Siren (Chaos naval jammer, T2, footprint 1): a low hull with two turning
-- emitter masts (`turret1`, `turret2`) ringed with glowing rods.
-- Model space, forward = -Z.

return {
	id = "chs_siren",
	parts = {
		{ name = "base", shape = "box", size = { 3.2, 1.8, 9.2 }, at = { 0, 0.4, 0 }, color = "hull" },
		{ name = "bow", parent = "base", shape = "wedge", size = { 3.2, 1.8, 2.024 }, at = { 0, 0.4, -5.612 }, color = "hull" },
		{ name = "waterline", parent = "base", shape = "box", size = { 3.3, 0.3, 9.2 }, at = { 0, -0.2, 0 }, color = "dark" },
		{ name = "deckTeam", parent = "base", shape = "box", size = { 2.24, 0.08, 0.736 }, at = { 0, 1.34, 3.312 }, color = "team" },
		{ name = "bridge", parent = "base", shape = "box", size = { 1.92, 1.04, 1.76 }, at = { 0, 1.82, 0.6 }, color = "hull" },
		{ name = "bridgeSlit", parent = "base", shape = "box", size = { 1.44, 0.2, 0.08 }, at = { 0, 2.145, -0.32 }, color = "glass" },
		{ name = "funnel", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 1.6, 0.9 }, at = { 0.48, 2.94, 1.7 }, color = "metal" },
		{ name = "turret1", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 0.5, 0.9 }, at = { 0, 1.55, -2.4 }, color = "dark" },
		{ name = "emitterMast1", parent = "turret1", shape = "box", size = { 0.2, 2.4, 0.2 }, at = { 0, 3, -2.4 }, color = "dark" },
		{ name = "rod10", parent = "turret1", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 3.5, -2.4 }, rot = { 0, 0, 0 }, color = "glass" },
		{ name = "rod11", parent = "turret1", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 3.85, -2.4 }, rot = { 0, 45, 0 }, color = "glass" },
		{ name = "rod12", parent = "turret1", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 4.2, -2.4 }, rot = { 0, 90, 0 }, color = "glass" },
		{ name = "rod13", parent = "turret1", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 4.55, -2.4 }, rot = { 0, 135, 0 }, color = "glass" },
		{ name = "turret2", parent = "base", shape = "cylinder", axis = "y", size = { 0.9, 0.5, 0.9 }, at = { 0, 1.55, 3 }, color = "dark" },
		{ name = "emitterMast2", parent = "turret2", shape = "box", size = { 0.2, 2.4, 0.2 }, at = { 0, 3, 3 }, color = "dark" },
		{ name = "rod20", parent = "turret2", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 3.5, 3 }, rot = { 0, 0, 0 }, color = "glass" },
		{ name = "rod21", parent = "turret2", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 3.85, 3 }, rot = { 0, 45, 0 }, color = "glass" },
		{ name = "rod22", parent = "turret2", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 4.2, 3 }, rot = { 0, 90, 0 }, color = "glass" },
		{ name = "rod23", parent = "turret2", shape = "box", size = { 0.12, 0.12, 1.2 }, at = { 0, 4.55, 3 }, rot = { 0, 135, 0 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 4.5, -2.4 } },
		{ name = "muzzle2", parent = "turret2", at = { 0, 4.5, 3 } },
	},
}

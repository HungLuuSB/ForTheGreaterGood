--!strict
-- Gauntlet (Order lobbing gun, T1, footprint 2; S-157): a sloped armored
-- emplacement with a low gun pit, a squat `turret` with a heavy shield and
-- trunnion cheeks, and a thick howitzer `barrel` (pitch; the def raises it
-- to 85 degrees for high-arc shells) with a muzzle brake. Modelled level;
-- `muzzle` at the brake. Model space, forward = -Z.

return {
	id = "ord_gauntlet",
	parts = {
		{ name = "base", shape = "box", size = { 12, 1.4, 12 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 12, 1.4, 1.2 }, at = { 0, 0.7, -6.6 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 12, 1.4, 1.2 }, at = { 0, 0.7, 6.6 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "pit", parent = "base", shape = "cylinder", axis = "y", size = { 7.6, 0.6, 7.6 }, at = { 0, 1.7, 0 }, color = "dark" },
		{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.08, 1.4 }, at = { 0, 1.44, 5.0 }, color = "team" },
		{ name = "ammoL", parent = "base", shape = "box", size = { 1.6, 1.2, 2.2 }, at = { -4.6, 2.0, 3.6 }, color = "metal" },
		{ name = "ammoR", parent = "base", shape = "box", size = { 1.6, 1.2, 2.2 }, at = { 4.6, 2.0, 3.6 }, color = "metal" },

		{ name = "turret", parent = "base", shape = "box", size = { 4.8, 1.8, 4.6 }, at = { 0, 2.9, 0.6 }, pivot = { 0, 2.0, 0 }, color = "hull" },
		{ name = "shield", parent = "turret", shape = "wedge", size = { 4.8, 1.6, 1.6 }, at = { 0, 3.8, -1.6 }, color = "hull" },
		{ name = "cheekL", parent = "turret", shape = "box", size = { 0.6, 2.0, 2.4 }, at = { -1.5, 4.4, 0.2 }, color = "hull" },
		{ name = "cheekR", parent = "turret", shape = "box", size = { 0.6, 2.0, 2.4 }, at = { 1.5, 4.4, 0.2 }, color = "hull" },
		{ name = "turretTeam", parent = "turret", shape = "box", size = { 3.0, 0.08, 1.6 }, at = { 0, 3.84, 2.0 }, color = "team" },

		{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 6.0 }, at = { 0, 4.6, -2.4 }, pivot = { 0, 4.6, 0.2 }, color = "metal" },
		{ name = "breech", parent = "barrel", shape = "box", size = { 2.2, 1.8, 1.8 }, at = { 0, 4.6, 0.8 }, color = "dark" },
		{ name = "brake", parent = "barrel", shape = "box", size = { 1.8, 1.2, 0.8 }, at = { 0, 4.6, -5.6 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "barrel", at = { 0, 4.6, -6.1 } },
	},
}

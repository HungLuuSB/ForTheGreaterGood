--!strict
-- Lamprey (Chaos submarine, T1, footprint 1): a hull mostly under the
-- waterline, a long low sail with a snorkel and an orange sensor strip;
-- torpedo doors at the bow (`turret1`) and stern (`turret2`).
-- Model space, forward = -Z.

return {
	id = "chs_lamprey",
	parts = {
		{ name = "base", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 9.4 }, at = { 0, -0.6, 0 }, color = "hull" },
		{ name = "nose", parent = "base", shape = "ball", size = { 2.2, 2.2, 2.6 }, at = { 0, -0.6, -4.7 }, color = "hull" },
		{ name = "tailCone", parent = "base", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 1.6 }, at = { 0, -0.6, 5.3 }, color = "dark" },
		{ name = "rudder", parent = "base", shape = "box", size = { 0.15, 1.8, 1 }, at = { 0, -0.4, 5.6 }, color = "team" },
		{ name = "planes", parent = "base", shape = "box", size = { 3.2, 0.12, 0.8 }, at = { 0, -0.6, 5.3 }, color = "dark" },
		{ name = "sail", parent = "base", shape = "box", size = { 1, 1.3, 3 }, at = { 0, 0.95, -0.8 }, color = "hull" },
		{ name = "sailTeam", parent = "base", shape = "box", size = { 1.04, 0.4, 1.8 }, at = { 0, 1.3, -0.8 }, color = "team" },
		{ name = "snorkel", parent = "base", shape = "box", size = { 0.2, 1, 0.2 }, at = { 0, 2.1, -0.2 }, color = "dark" },
		{ name = "sensorGlow", parent = "base", shape = "box", size = { 0.6, 0.15, 0.06 }, at = { 0, 1.2, -2.34 }, color = "glass" },
		{ name = "turret1", parent = "base", shape = "box", size = { 1, 0.4, 0.8 }, at = { 0, 0.4, -3.4 }, pivot = { 0, 0.2, -3.4 }, color = "dark" },
		{ name = "turret2", parent = "base", shape = "box", size = { 0.8, 0.3, 0.6 }, at = { 0, 0.4, 3 }, pivot = { 0, 0.2, 3 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle1", parent = "turret1", at = { 0, 0.4, -3.9 } },
		{ name = "muzzle2", parent = "turret2", at = { 0, 0.4, 2.6 } },
	},
}

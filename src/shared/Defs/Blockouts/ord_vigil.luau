--!strict
-- Vigil (Order IR SAM site, T1, footprint 1): an armored base and pedestal
-- with a launcher of two closed canister pods either side of a cyan sensor
-- head; team plates on the pods. The def turns `launcher`, on the pedestal's
-- axis (M-3). Model space, forward = -Z (docs/contracts/rig.md).

return {
	id = "ord_vigil",
	parts = {
		{ name = "base", shape = "box", size = { 5.4, 1.4, 5.4 }, at = { 0, 0.7, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 5.4, 1.4, 1 }, at = { 0, 0.7, -3.2 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 5.4, 1.4, 1 }, at = { 0, 0.7, 3.2 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 1.6, 1.6 }, at = { 0, 2.2, 0 }, color = "dark" },

		{ name = "launcher", parent = "base", shape = "box", size = { 1.4, 1.4, 1.6 }, at = { 0, 3.6, 0 }, pivot = { 0, 3.0, 0 }, color = "hull" },
		{ name = "sensor", parent = "launcher", shape = "box", size = { 0.9, 0.5, 0.1 }, at = { 0, 3.75, -0.85 }, color = "glass" },
		{ name = "podL", parent = "launcher", shape = "box", size = { 1.3, 1.5, 3.2 }, at = { -1.4, 3.6, -0.2 }, color = "hull" },
		{ name = "podR", parent = "launcher", shape = "box", size = { 1.3, 1.5, 3.2 }, at = { 1.4, 3.6, -0.2 }, color = "hull" },
		{ name = "teamL", parent = "launcher", shape = "box", size = { 1.1, 0.08, 2.6 }, at = { -1.4, 4.39, -0.2 }, color = "team" },
		{ name = "teamR", parent = "launcher", shape = "box", size = { 1.1, 0.08, 2.6 }, at = { 1.4, 4.39, -0.2 }, color = "team" },
		{ name = "capsL", parent = "launcher", shape = "box", size = { 1.1, 1.3, 0.1 }, at = { -1.4, 3.6, -1.85 }, color = "dark" },
		{ name = "capsR", parent = "launcher", shape = "box", size = { 1.1, 1.3, 0.1 }, at = { 1.4, 3.6, -1.85 }, color = "dark" },
	},
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { -1.4, 3.6, -1.95 } },
	},
}

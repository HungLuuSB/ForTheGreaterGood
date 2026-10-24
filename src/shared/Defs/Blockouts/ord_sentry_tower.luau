--!strict
-- Sentry (Order laser tower, T1, footprint 2; S-157): a chamfered armored
-- slab and a short pedestal under a compact boxy `turret` carrying one red
-- laser emitter (a ribbed tube with a glass lens) and a fire-control sensor.
-- The def turns `turret`; `muzzle` at the lens. Model space, forward = -Z.

return {
	id = "ord_sentry_tower",
	parts = {
		{ name = "base", shape = "box", size = { 11, 1.2, 11 }, at = { 0, 0.6, 0 }, color = "hull" },
		{ name = "slopeF", parent = "base", shape = "wedge", size = { 11, 1.2, 1.2 }, at = { 0, 0.6, -6.1 }, color = "hull" },
		{ name = "slopeB", parent = "base", shape = "wedge", size = { 11, 1.2, 1.2 }, at = { 0, 0.6, 6.1 }, rot = { 0, 180, 0 }, color = "hull" },
		{ name = "plinth", parent = "base", shape = "box", size = { 6, 1.2, 6 }, at = { 0, 1.8, 0 }, color = "hull" },
		{ name = "teamA", parent = "base", shape = "box", size = { 3.4, 0.08, 1.4 }, at = { 0, 1.24, 4.4 }, color = "team" },
		{ name = "hazard", parent = "base", shape = "box", size = { 6, 0.06, 0.5 }, at = { 0, 1.23, -4.6 }, color = "hazard" },
		{ name = "pedestal", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 1.2, 2.6 }, at = { 0, 3.0, 0 }, color = "dark" },

		{ name = "turret", parent = "base", shape = "box", size = { 3.4, 2.0, 3.6 }, at = { 0, 4.6, 0.3 }, pivot = { 0, 3.6, 0 }, color = "hull" },
		{ name = "turretTeam", parent = "turret", shape = "box", size = { 2.4, 0.08, 2.2 }, at = { 0, 5.64, 0.6 }, color = "team" },
		{ name = "sensor", parent = "turret", shape = "box", size = { 0.8, 0.5, 0.1 }, at = { -1.1, 5.1, -1.5 }, color = "glass" },
		{ name = "emitter", parent = "turret", shape = "cylinder", axis = "z", size = { 0.9, 0.9, 3.4 }, at = { 0, 4.5, -2.9 }, color = "metal" },
		{ name = "rib1", parent = "turret", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.3 }, at = { 0, 4.5, -2.2 }, color = "dark" },
		{ name = "rib2", parent = "turret", shape = "cylinder", axis = "z", size = { 1.2, 1.2, 0.3 }, at = { 0, 4.5, -3.4 }, color = "dark" },
		{ name = "lens", parent = "turret", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 0.2 }, at = { 0, 4.5, -4.65 }, color = "glass" },
	},
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 4.5, -4.8 } },
	},
}

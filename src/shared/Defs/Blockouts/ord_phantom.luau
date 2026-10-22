--!strict
-- Phantom (Order strategic bomber, T2, footprint 1): a stealth flying wing
-- (no tails), a raised spine with a slim canopy, a slit exhaust, a bomb
-- `bay` and a `pylon`; team panels on the wing tips.
-- Model space, forward = -Z.

return {
	id = "ord_phantom",
	parts = {
		{ name = "base", shape = "wedge", size = { 2.4, 1, 5.6 }, at = { 0, 0.6, 0.4 }, color = "hull" },
		{ name = "wing", parent = "base", shape = "wedge", size = { 8, 0.3, 4.4 }, at = { 0, 0.35, 1.4 }, color = "hull" },
		{ name = "wingTeamL", parent = "base", shape = "box", size = { 1.6, 0.06, 1 }, at = { -2.4, 0.55, 2.4 }, color = "team" },
		{ name = "wingTeamR", parent = "base", shape = "box", size = { 1.6, 0.06, 1 }, at = { 2.4, 0.55, 2.4 }, color = "team" },
		{ name = "canopy", parent = "base", shape = "wedge", size = { 0.9, 0.35, 1.2 }, at = { 0, 1.2, -1.2 }, color = "glass" },
		{ name = "exhaust", parent = "base", shape = "box", size = { 2, 0.2, 0.2 }, at = { 0, 0.5, 3.4 }, color = "glass" },
		{ name = "pylon", parent = "base", shape = "box", size = { 2, 0.2, 0.8 }, at = { 0, 0.15, 1.6 }, color = "dark" },
		{ name = "bay", parent = "base", shape = "box", size = { 1.2, 0.2, 2.6 }, at = { 0, 0.1, 0.2 }, color = "dark" },
		{ name = "bayLip", parent = "bay", shape = "box", size = { 1.4, 0.1, 0.2 }, at = { 0, 0.05, -1.1 }, color = "metal" },
	},
	attachments = {
		{ name = "muzzle", parent = "bay", at = { 0, -0.1, 0.2 } },
	},
}

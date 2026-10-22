--!strict
-- Mire (Chaos amphibious tank, T2, footprint 1): a light hull riding between
-- two pontoon floats with exposed wheels below, an open stern with a single
-- big propeller housing and a tall snorkel; a small turret with a short gun
-- (the weapon turns the turret, no pitch piece). Team plates on the floats.
-- Chaos reads light (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 3.6, 1.2, 6.4 }, at = { 0, 1.7, 0.4 }, color = "hull" },
	{ name = "bow", parent = "base", shape = "wedge", size = { 3.6, 1.2, 1.4 }, at = { 0, 1.7, -3.1 }, color = "hull" },
	{ name = "floatL", parent = "base", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 7.0 }, at = { -2.6, 1.6, 0.2 }, color = "metal" },
	{ name = "floatR", parent = "base", shape = "cylinder", axis = "z", size = { 1.4, 1.4, 7.0 }, at = { 2.6, 1.6, 0.2 }, color = "metal" },
	{ name = "floatTeamL", parent = "base", shape = "box", size = { 0.6, 0.08, 3.0 }, at = { -2.6, 2.32, 0.2 }, color = "team" },
	{ name = "floatTeamR", parent = "base", shape = "box", size = { 0.6, 0.08, 3.0 }, at = { 2.6, 2.32, 0.2 }, color = "team" },
	{ name = "prop", parent = "base", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 0.8 }, at = { 0, 1.3, 4.0 }, color = "dark" },
	{ name = "snorkel", parent = "base", shape = "box", size = { 0.3, 2.6, 0.3 }, at = { 1.2, 3.6, 2.8 }, color = "dark" },
	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 0.9, 2.6 }, at = { 0, 2.75, 0.6 }, color = "hull" },
	{ name = "sensor", parent = "turret", shape = "box", size = { 0.5, 0.25, 0.25 }, at = { -0.8, 3.1, -0.95 }, color = "glass" },
	{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 0.4, 0.4, 3.4 }, at = { 0, 2.8, -2.2 }, color = "metal" },
}
for i, z in { -2.2, 0.2, 2.6 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.5, 1.2, 1.2 }, at = { -1.7, 0.6, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.5, 1.2, 1.2 }, at = { 1.7, 0.6, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return {
	id = "chs_mire",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 2.8, -3.9 } },
	},
}

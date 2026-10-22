--!strict
-- Forgemaster (Chaos advanced builder, T2, footprint 1): a light tracked
-- chassis with exposed road wheels, an open cab cage and a scrap bin; on the
-- `nano` turntable a tall lattice crane arm with a hook and a glowing
-- emitter, plus a second short arm (the T1 Scrapper has one).
-- Team plates on the bin and turntable. Chaos reads light (M-14).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.6, 1.1, 6.8 }, at = { 0, 1.65, 0.3 }, color = "hull" },
	{ name = "trackL", parent = "base", shape = "box", size = { 0.9, 0.5, 7.4 }, at = { -2.6, 0.25, 0 }, color = "track" },
	{ name = "trackR", parent = "base", shape = "box", size = { 0.9, 0.5, 7.4 }, at = { 2.6, 0.25, 0 }, color = "track" },
	{ name = "cab", parent = "base", shape = "box", size = { 2.6, 1.0, 1.4 }, at = { -0.8, 2.7, -2.4 }, color = "hull" },
	{ name = "cabSlit", parent = "base", shape = "box", size = { 2.0, 0.2, 0.08 }, at = { -0.8, 2.9, -3.14 }, color = "glass" },
	{ name = "cabCage", parent = "base", shape = "box", size = { 2.8, 0.12, 0.12 }, at = { -0.8, 3.3, -3.2 }, color = "dark" },
	{ name = "bin", parent = "base", shape = "box", size = { 3.6, 0.9, 1.8 }, at = { 0, 2.6, 2.6 }, color = "dark" },
	{ name = "binTeam", parent = "base", shape = "box", size = { 2.6, 0.08, 1.2 }, at = { 0, 3.09, 2.6 }, color = "team" },

	{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 0.4, 2.4 }, at = { 0.8, 2.4, -0.2 }, color = "team" },
	{ name = "armA", parent = "nano", shape = "box", size = { 0.5, 0.5, 5.6 }, at = { 0.8, 4.8, -1.2 }, rot = { 50, 0, 0 }, color = "dark" },
	{ name = "armB", parent = "nano", shape = "box", size = { 0.5, 0.5, 5.6 }, at = { 1.4, 4.8, -1.2 }, rot = { 50, 0, 0 }, color = "dark" },
	{ name = "hook", parent = "nano", shape = "box", size = { 0.15, 1.2, 0.15 }, at = { 1.1, 6.1, -3.0 }, color = "dark" },
	{ name = "emitter", parent = "nano", shape = "ball", size = { 0.9, 0.9, 0.9 }, at = { 1.1, 7.0, -3.0 }, color = "glass" },
	{ name = "shortArm", parent = "nano", shape = "box", size = { 0.4, 0.4, 2.4 }, at = { 0.2, 3.3, 0.8 }, rot = { -30, 0, 0 }, color = "dark" },
	{ name = "emitter2", parent = "nano", shape = "ball", size = { 0.6, 0.6, 0.6 }, at = { 0.2, 3.9, 1.9 }, color = "glass" },
}
for i, z in { -2.4, -0.8, 0.8, 2.4 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.3, 1.3 }, at = { -2.6, 0.8, z }, color = "track" })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.3, 1.3 }, at = { 2.6, 0.8, z }, color = "track" })
end

return { id = "chs_forgemaster", parts = parts }

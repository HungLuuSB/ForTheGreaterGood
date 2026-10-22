--!strict
-- Deep Excavator (Chaos, T2, footprint 1): a taller open derrick over a
-- thick drill with a glowing band, a slat cage round the base and an engine
-- box, team plate on the platform. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 6.6, 0.4, 6.6 }, at = { 0, 0.2, 0 }, color = "dark" },
	{ name = "platform", parent = "base", shape = "box", size = { 4.8, 0.5, 4.8 }, at = { 0, 0.65, 0 }, color = "hull" },
	{ name = "team", parent = "base", shape = "box", size = { 3.4, 0.08, 1.2 }, at = { 0, 0.94, -1.6 }, color = "team" },
	{ name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 7, 1.8 }, at = { 0, 4.4, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "glow", parent = "base", shape = "cylinder", axis = "y", size = { 1.9, 0.3, 1.9 }, at = { 0, 2.4, 0 }, color = "glass" },
	{ name = "head", parent = "base", shape = "box", size = { 2.4, 1, 2.4 }, at = { 0, 8.4, 0 }, color = "hull" },
	{ name = "light", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { 0, 9.1, 0 }, color = "glass" },
	{ name = "engine", parent = "base", shape = "box", size = { 1.8, 1.8, 2.4 }, at = { 2.4, 1.8, 1.8 }, color = "hull" },
	-- T2: fuel tanks and a second engine round the derrick (T1 vs T2 check, 2026-10-22)
	{ name = "engine2", parent = "base", shape = "box", size = { 1.8, 1.8, 2.4 }, at = { 2.4, 1.8, -1.8 }, color = "hull" },
	{ name = "fuelA", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 2.6, 1.5 }, at = { -2.5, 2.2, -1.7 }, color = "metal" },
	{ name = "fuelB", parent = "base", shape = "cylinder", axis = "y", size = { 1.5, 2.6, 1.5 }, at = { -2.5, 2.2, 1.7 }, color = "metal" },
	{ name = "exhaust", parent = "base", shape = "cylinder", axis = "y", size = { 0.5, 2.4, 0.5 }, at = { 3.0, 3.9, 2.6 }, color = "dark" },
	{ name = "cageF", parent = "base", shape = "box", size = { 6, 0.15, 0.15 }, at = { 0, 1.8, -3.1 }, color = "dark" },
	{ name = "cageB", parent = "base", shape = "box", size = { 6, 0.15, 0.15 }, at = { 0, 1.8, 3.1 }, color = "dark" },
}
for i, p in { { -1.9, -1.9 }, { 1.9, -1.9 }, { -1.9, 1.9 }, { 1.9, 1.9 } } do
	table.insert(parts, { name = `leg{i}`, parent = "base", shape = "box", size = { 0.35, 8.4, 0.35 }, at = { p[1] * 0.75, 4.8, p[2] * 0.75 }, rot = { p[2] > 0 and -7 or 7, 0, p[1] > 0 and 7 or -7 }, color = "dark" })
end

-- footprint 1 -> 3 (size scale, M-26 / S-104): scaled until the redesign lands
return require("./Scale").scaled({ id = "chs_advextractor", parts = parts }, 3.0)

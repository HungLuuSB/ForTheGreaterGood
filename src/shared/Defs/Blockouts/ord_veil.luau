--!strict
-- Veil (Order mobile jammer, T2, footprint 1): an armored 8 × 8 truck
-- carrying the `array`: a squat armored emitter block on a turntable with
-- four glowing fins in a cross, a team band round it. Short range, so it's
-- compact next to the Chaos Shroud's tall mast. Order reads heavy (M-14).
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 4.8, 1.3, 7.6 }, at = { 0, 1.75, 0.1 }, color = "hull" },
	{ name = "skirtL", parent = "base", shape = "box", size = { 0.3, 0.8, 6.8 }, at = { -2.55, 1.25, 0.1 }, color = "hull" },
	{ name = "skirtR", parent = "base", shape = "box", size = { 0.3, 0.8, 6.8 }, at = { 2.55, 1.25, 0.1 }, color = "hull" },
	{ name = "cab", parent = "base", shape = "box", size = { 4.6, 1.3, 1.8 }, at = { 0, 3.05, -2.8 }, color = "hull" },
	{ name = "cabGlass", parent = "base", shape = "box", size = { 3.8, 0.35, 0.08 }, at = { 0, 3.25, -3.74 }, color = "glass" },
	{ name = "cabTeam", parent = "base", shape = "box", size = { 3.4, 0.08, 1.2 }, at = { 0, 3.74, -2.8 }, color = "team" },

	{ name = "array", parent = "base", shape = "box", size = { 2.6, 1.6, 2.6 }, at = { 0, 3.2, 1.6 }, color = "hull", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "arrayTeam", parent = "array", shape = "box", size = { 2.7, 0.4, 2.7 }, at = { 0, 3.2, 1.6 }, color = "team" },
	{ name = "arrayTop", parent = "array", shape = "box", size = { 1.0, 1.4, 1.0 }, at = { 0, 4.7, 1.6 }, color = "hull" },
	{ name = "finF", parent = "array", shape = "box", size = { 0.15, 1.6, 1.2 }, at = { 0, 4.9, 0.5 }, color = "glass" },
	{ name = "finB", parent = "array", shape = "box", size = { 0.15, 1.6, 1.2 }, at = { 0, 4.9, 2.7 }, color = "glass" },
	{ name = "finL", parent = "array", shape = "box", size = { 1.2, 1.6, 0.15 }, at = { -1.1, 4.9, 1.6 }, color = "glass" },
	{ name = "finR", parent = "array", shape = "box", size = { 1.2, 1.6, 0.15 }, at = { 1.1, 4.9, 1.6 }, color = "glass" },
}
for i, z in { -2.9, -1.3, 1.3, 2.9 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { -2.2, 0.75, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.7, 1.5, 1.5 }, at = { 2.2, 0.75, z }, color = "track", anim = { motion = "spin", axis = { 1, 0, 0 } } })
end

return { id = "ord_veil", parts = parts }

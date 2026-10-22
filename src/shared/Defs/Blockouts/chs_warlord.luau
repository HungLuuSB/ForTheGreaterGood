--!strict
-- Warlord (Chaos command vehicle, footprint 1): the unit a player must keep
-- alive, so it reads unique at any zoom: a high-riding tracked chassis with
-- exposed wheels, a slab-armored command cabin with a slit and spikes, a tall
-- lattice mast flying a big team banner plate and a beacon, and on the
-- `nano` turntable at the back a crane arm with a glowing emitter.
-- Chaos reads light (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 5.2, 1.3, 7.0 }, at = { 0, 1.8, 0.2 }, color = "hull" },
	{ name = "trackL", parent = "base", shape = "box", size = { 1.0, 0.5, 7.6 }, at = { -2.8, 0.25, 0 }, color = "track" },
	{ name = "trackR", parent = "base", shape = "box", size = { 1.0, 0.5, 7.6 }, at = { 2.8, 0.25, 0 }, color = "track" },
	{ name = "ram", parent = "base", shape = "box", size = { 5.6, 0.9, 0.4 }, at = { 0, 1.4, -3.8 }, rot = { -20, 0, 0 }, color = "dark" },
	{ name = "cabin", parent = "base", shape = "box", size = { 4.0, 1.6, 2.6 }, at = { 0, 3.25, -1.2 }, color = "hull" },
	{ name = "cabinSlit", parent = "base", shape = "box", size = { 3.0, 0.22, 0.08 }, at = { 0, 3.5, -2.54 }, color = "glass" },
	{ name = "cabinTeam", parent = "base", shape = "box", size = { 3.0, 0.08, 1.8 }, at = { 0, 4.09, -1.2 }, color = "team" },
	{ name = "spikeL", parent = "base", shape = "wedge", size = { 0.4, 1.0, 0.6 }, at = { -1.8, 4.5, -1.8 }, color = "dark" },
	{ name = "spikeR", parent = "base", shape = "wedge", size = { 0.4, 1.0, 0.6 }, at = { 1.8, 4.5, -1.8 }, color = "dark" },

	{ name = "mast", parent = "base", shape = "box", size = { 0.35, 6.0, 0.35 }, at = { -1.9, 5.5, 1.0 }, color = "dark" },
	{ name = "banner", parent = "base", shape = "box", size = { 0.08, 1.8, 1.6 }, at = { -1.9, 7.4, 1.9 }, color = "team" },
	{ name = "beacon", parent = "base", shape = "ball", size = { 0.5, 0.5, 0.5 }, at = { -1.9, 8.7, 1.0 }, color = "glass" },

	{ name = "nano", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 0.4, 2.2 }, at = { 0.8, 2.65, 2.4 }, color = "dark" },
	{ name = "arm", parent = "nano", shape = "box", size = { 0.5, 0.5, 4.0 }, at = { 0.8, 4.0, 3.0 }, rot = { -40, 0, 0 }, color = "dark" },
	{ name = "emitter", parent = "nano", shape = "ball", size = { 1.1, 1.1, 1.1 }, at = { 0.8, 5.3, 4.3 }, color = "glass" },
}
for i, z in { -2.5, -0.85, 0.85, 2.5 } do
	table.insert(parts, { name = `wheelL{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.4, 1.4 }, at = { -2.8, 0.85, z }, color = "track" })
	table.insert(parts, { name = `wheelR{i}`, parent = "base", shape = "cylinder", axis = "x", size = { 0.6, 1.4, 1.4 }, at = { 2.8, 0.85, z }, color = "track" })
end

return { id = "chs_warlord", parts = parts }

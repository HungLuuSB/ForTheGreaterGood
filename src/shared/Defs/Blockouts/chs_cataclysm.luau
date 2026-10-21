--!strict
-- Cataclysm (Chaos artillery emplacement, T2, footprint 3): an open gun pit
-- ringed with reactive-armor blocks, a squat rounded turret on an exposed
-- cradle with a huge fat barrel and a glowing breech band, ammo tanks.
-- Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "cylinder", axis = "y", size = { 20, 1, 20 }, at = { 0, 0.5, 0 }, color = "dark" },
	{ name = "teamA", parent = "base", shape = "box", size = { 4, 0.1, 4 }, at = { -6, 1.05, 5 }, color = "team" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 3, 2.4 }, at = { 6.5, 2.5, 5.5 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 3, 2.4 }, at = { 6.5, 2.5, 2.7 }, color = "metal" },

	{ name = "turret", parent = "base", shape = "cylinder", axis = "y", size = { 7, 3, 7 }, at = { 0, 2.5, 1 }, pivot = { 0, 1, 1 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 4, 0.1, 3 }, at = { 0, 4.05, 2.4 }, color = "team" },
	{ name = "cradle", parent = "turret", shape = "box", size = { 3.4, 2.4, 3 }, at = { 0, 4.6, -1.2 }, color = "dark" },
	{ name = "barrel", parent = "turret", shape = "cylinder", axis = "z", size = { 2.2, 2.2, 10 }, at = { 0, 4.8, -7 }, color = "metal" },
	{ name = "glow", parent = "turret", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 0.4 }, at = { 0, 4.8, -3.2 }, color = "glass" },
	{ name = "lip", parent = "turret", shape = "cylinder", axis = "z", size = { 2.8, 2.8, 0.8 }, at = { 0, 4.8, -12.2 }, color = "dark" },
}
for i = 0, 7 do
	local a = i * 45
	local r = math.rad(a)
	table.insert(parts, { name = `era{i}`, parent = "base", shape = "box", size = { 3, 1.4, 0.6 }, at = { math.sin(r) * 9.2, 1.5, math.cos(r) * 9.2 }, rot = { 0, a, 0 }, color = "metal" })
end

return {
	id = "chs_cataclysm",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { 0, 4.8, -12.7 } },
	},
}

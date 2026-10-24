--!strict
-- Empyrean (Order advanced rearm pad, T2, footprint 4, two landing bays;
-- sim-A's request): the Aerie grown up. A chamfered armored apron with two
-- landing circles in team rings, a hazard border and edge lights; between
-- the bays at the back an armored control tower with a glass cab and a
-- radar mast; a rearm pedestal and boom beside each bay; blast deflectors
-- behind the bays; fuel blocks with team tops. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 30, 0.8, 30 }, at = { 0, 0.4, 0 }, color = "hull" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 26, 0.06, 0.6 }, at = { 0, 0.83, -14.4 }, color = "hazard" },
	{ name = "hazardB", parent = "base", shape = "box", size = { 26, 0.06, 0.6 }, at = { 0, 0.83, 14.4 }, color = "hazard" },
	{ name = "centreLine", parent = "base", shape = "box", size = { 0.5, 0.06, 18 }, at = { 0, 0.83, 3 }, color = "dark" },
	-- control tower and its radar mast
	{ name = "tower", parent = "base", shape = "box", size = { 4.4, 7, 4.4 }, at = { 0, 4.3, 11.4 }, color = "hull" },
	{ name = "towerTeam", parent = "base", shape = "box", size = { 4.5, 1.6, 4.5 }, at = { 0, 3.2, 11.4 }, color = "team" },
	{ name = "cab", parent = "base", shape = "box", size = { 5.4, 1.8, 5.4 }, at = { 0, 8.7, 11.4 }, color = "glass" },
	{ name = "cabRoof", parent = "base", shape = "box", size = { 6, 0.5, 6 }, at = { 0, 9.85, 11.4 }, color = "dark" },
	{ name = "mast", parent = "base", shape = "cylinder", axis = "y", size = { 0.4, 3, 0.4 }, at = { 1.8, 11.6, 12.6 }, color = "metal" },
	{ name = "mastArray", parent = "base", shape = "box", size = { 2.6, 0.9, 0.2 }, at = { 1.8, 13.2, 12.6 }, color = "dark" },
	{ name = "beacon", parent = "base", shape = "box", size = { 0.4, 0.4, 0.4 }, at = { -2.0, 10.3, 13.0 }, color = "glass" },
}

-- the two bays, mirrored at x = -7.6 and +7.6
for _, sx in { -1, 1 } do
	local x = sx * 7.6
	local s = if sx < 0 then "L" else "R"
	local function add(p)
		table.insert(parts, p)
	end
	add({ name = "pad" .. s, parent = "base", shape = "cylinder", axis = "y", size = { 12.4, 0.2, 12.4 }, at = { x, 0.9, -1.4 }, color = "dark" })
	add({ name = "ring" .. s, parent = "base", shape = "cylinder", axis = "y", size = { 12.8, 0.15, 12.8 }, at = { x, 0.86, -1.4 }, color = "team" })
	add({ name = "markA" .. s, parent = "base", shape = "box", size = { 0.6, 0.06, 5.2 }, at = { x - 1.4, 1.03, -1.4 }, color = "hull" })
	add({ name = "markB" .. s, parent = "base", shape = "box", size = { 0.6, 0.06, 5.2 }, at = { x + 1.4, 1.03, -1.4 }, color = "hull" })
	add({ name = "markC" .. s, parent = "base", shape = "box", size = { 2.8, 0.06, 0.6 }, at = { x, 1.03, -1.4 }, color = "hull" })
	-- blast deflector behind the bay, leaning back
	add({ name = "deflector" .. s, parent = "base", shape = "wedge", size = { 10, 2.4, 1.6 }, at = { x, 2.0, 6.6 }, rot = { 0, 180, 0 }, color = "hull" })
	-- rearm pedestal and boom at the outer edge
	add({ name = "pedestal" .. s, parent = "base", shape = "box", size = { 1.6, 3, 1.6 }, at = { sx * 14.0, 2.3, -1.4 }, color = "hull" })
	add({ name = "boom" .. s, parent = "base", shape = "box", size = { 4.4, 0.6, 0.7 }, at = { sx * 12.0, 3.9, -1.4 }, color = "dark" })
	add({ name = "boomHead" .. s, parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { sx * 9.8, 3.7, -1.4 }, color = "glass" })
	-- fuel block with a team top
	add({ name = "fuel" .. s, parent = "base", shape = "box", size = { 3.2, 1.8, 2.4 }, at = { sx * 12.4, 1.7, 10.4 }, color = "hull" })
	add({ name = "fuelTeam" .. s, parent = "base", shape = "box", size = { 2.4, 0.08, 1.6 }, at = { sx * 12.4, 2.64, 10.4 }, color = "team" })
	-- edge lights
	add({ name = "lightF" .. s, parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { sx * 14.2, 1.05, -14.2 }, color = "glass" })
	add({ name = "lightM" .. s, parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { sx * 14.2, 1.05, 4.4 }, color = "glass" })
	add({ name = "lightB" .. s, parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { sx * 14.2, 1.05, 14.2 }, color = "glass" })
	add({ name = "lightC" .. s, parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 }, at = { sx * 1.2, 1.05, -14.2 }, color = "glass" })
end

return {
	id = "ord_empyrean",
	parts = parts,
}

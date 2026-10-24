--!strict
-- Rookery (Chaos advanced rearm pad, T2, footprint 4, two landing bays;
-- sim-A's request): the Roost grown up. A patched dark slab with grated
-- sections, two matte landing circles in team rings with amber lights; a
-- scrap barricade along the back, three strapped fuel tanks with a hose, a
-- crane stub with a hook over the left bay, a tall lattice light mast and
-- ammo crates. Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 30, 0.8, 30 }, at = { 0, 0.4, 0 }, color = "dark" },
	{ name = "patchA", parent = "base", shape = "box", size = { 8, 0.1, 6 }, at = { -9, 0.85, 9 }, rot = { 0, 8, 0 }, color = "hull" },
	{ name = "patchB", parent = "base", shape = "box", size = { 6, 0.1, 5 }, at = { 10, 0.85, -11 }, rot = { 0, -6, 0 }, color = "hull" },
	{ name = "grate", parent = "base", shape = "box", size = { 3, 0.1, 22 }, at = { 0, 0.85, -2 }, color = "metal" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 20, 0.06, 0.6 }, at = { 0, 0.83, -14.4 }, color = "hazard" },
	-- scrap barricade along the back
	{ name = "barricadeA", parent = "base", shape = "wedge", size = { 9, 2.2, 1.6 }, at = { -9, 1.9, 14 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "barricadeB", parent = "base", shape = "wedge", size = { 7, 1.8, 1.6 }, at = { 1, 1.7, 14.2 }, rot = { 0, 176, 0 }, color = "hull" },
	{ name = "barricadeTeam", parent = "base", shape = "box", size = { 5, 1.2, 0.08 }, at = { -9, 1.8, 13.1 }, color = "team" },
	-- fuel tanks and hose
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 3, 2.6 }, at = { 11.6, 2.3, 9.2 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 3, 2.6 }, at = { 11.6, 2.3, 12.2 }, color = "metal" },
	{ name = "tankC", parent = "base", shape = "cylinder", axis = "y", size = { 2.2, 2.4, 2.2 }, at = { 8.8, 2.0, 12.6 }, color = "metal" },
	{ name = "tankCap", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 0.15, 2.4 }, at = { 11.6, 3.85, 9.2 }, color = "team" },
	{ name = "hose", parent = "base", shape = "box", size = { 0.3, 0.3, 8 }, at = { 10.4, 0.95, 4.4 }, color = "dark" },
	-- crane stub over the left bay
	{ name = "craneMast", parent = "base", shape = "box", size = { 1.2, 6, 1.2 }, at = { -14, 3.8, 5 }, color = "hull" },
	{ name = "craneJib", parent = "base", shape = "box", size = { 6, 0.6, 0.6 }, at = { -11.4, 6.6, 5 }, color = "dark" },
	{ name = "craneHook", parent = "base", shape = "box", size = { 0.5, 1.4, 0.5 }, at = { -8.8, 5.6, 5 }, color = "metal" },
	-- lattice light mast
	{ name = "mastLegA", parent = "base", shape = "box", size = { 0.3, 9, 0.3 }, at = { 13.6, 5.3, -13.6 }, color = "dark" },
	{ name = "mastLegB", parent = "base", shape = "box", size = { 0.3, 9, 0.3 }, at = { 12.4, 5.3, -13.6 }, color = "dark" },
	{ name = "mastBrace", parent = "base", shape = "box", size = { 1.6, 0.25, 0.25 }, at = { 13.0, 5.3, -13.6 }, rot = { 0, 0, 35 }, color = "dark" },
	{ name = "mastLight", parent = "base", shape = "box", size = { 1.6, 0.6, 0.6 }, at = { 13.0, 10, -13.6 }, color = "glass" },
	-- ammo crates
	{ name = "crateA", parent = "base", shape = "box", size = { 1.6, 1.2, 1.2 }, at = { -12.6, 1.4, 10.6 }, color = "hull" },
	{ name = "crateB", parent = "base", shape = "box", size = { 1.6, 1.2, 1.2 }, at = { -12.6, 1.4, 12.0 }, rot = { 0, 12, 0 }, color = "hull" },
	{ name = "crateC", parent = "base", shape = "box", size = { 1.6, 1.2, 1.2 }, at = { -12.4, 2.6, 11.2 }, rot = { 0, -8, 0 }, color = "hull" },
}

for _, sx in { -1, 1 } do
	local x = sx * 7.6
	local s = if sx < 0 then "L" else "R"
	table.insert(parts, { name = "pad" .. s, parent = "base", shape = "cylinder", axis = "y", size = { 12.4, 0.2, 12.4 }, at = { x, 0.9, -2 }, color = "dark" })
	table.insert(parts, { name = "ring" .. s, parent = "base", shape = "cylinder", axis = "y", size = { 12.8, 0.15, 12.8 }, at = { x, 0.86, -2 }, color = "team" })
	table.insert(parts, { name = "markA" .. s, parent = "base", shape = "box", size = { 0.6, 0.06, 5.2 }, at = { x - 1.4, 1.03, -2 }, color = "hull" })
	table.insert(parts, { name = "markB" .. s, parent = "base", shape = "box", size = { 0.6, 0.06, 5.2 }, at = { x + 1.4, 1.03, -2 }, color = "hull" })
	table.insert(parts, { name = "markC" .. s, parent = "base", shape = "box", size = { 2.8, 0.06, 0.6 }, at = { x, 1.03, -2 }, color = "hull" })
	for k, a in { 45, 135, 225, 315 } do
		local r = math.rad(a)
		table.insert(parts, { name = "lamp" .. s .. k, parent = "base", shape = "box", size = { 0.5, 0.5, 0.5 },
			at = { x + math.cos(r) * 6.9, 1.05, -2 + math.sin(r) * 6.9 }, color = "glass" })
	end
end

return {
	id = "chs_rookery",
	parts = parts,
}

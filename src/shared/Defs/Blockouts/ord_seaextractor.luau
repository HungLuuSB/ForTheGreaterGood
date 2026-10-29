--!strict
-- Offshore Extractor (Order submerged extractor, T1, footprint 2; S-209,
-- BAR armmex): on the seabed, a stepped octagonal pyramid with buttress
-- ramps carrying team panels and amber markers, and on top a turning
-- four-bladed impeller (`drill`, turn Y). Order reads clean and heavy
-- (M-14). Model space, forward = -Z.

local TOP = 4.0

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.6, 0.7, 15.6 }, at = { 0, 0.35, 0 }, color = "dark" },
	{ name = "tier1", parent = "base", shape = "box", size = { 12.4, 0.9, 12.4 }, at = { 0, 1.15, 0 }, color = "hull" },
	{ name = "tier2", parent = "base", shape = "box", size = { 10.0, 0.9, 10.0 }, at = { 0, 2.05, 0 }, color = "hull" },
	{ name = "tier3", parent = "base", shape = "box", size = { 7.4, 0.9, 7.4 }, at = { 0, 2.95, 0 }, color = "hull" },
	{ name = "cap", parent = "base", shape = "box", size = { 5.2, 0.6, 5.2 }, at = { 0, 3.7, 0 }, color = "metal" },
	{ name = "drill", parent = "base", shape = "cylinder", axis = "y", size = { 2.6, 0.9, 2.6 }, at = { 0, TOP + 0.45, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } },
	{ name = "hub", parent = "drill", shape = "cylinder", axis = "y", size = { 1.6, 0.4, 1.6 }, at = { 0, TOP + 1.1, 0 }, color = "glass" },
	{ name = "bladeA", parent = "drill", shape = "box", size = { 9.4, 0.35, 1.5 }, at = { 0, TOP + 0.75, 0 }, rot = { 0, 45, 0 }, color = "team" },
	{ name = "bladeB", parent = "drill", shape = "box", size = { 9.4, 0.35, 1.5 }, at = { 0, TOP + 0.75, 0 }, rot = { 0, -45, 0 }, color = "team" },
}
for i, d in { { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } } do
	table.insert(parts, { name = `ramp{i}`, parent = "base", shape = "box", size = { if d[1] == 0 then 1.8 else 4.4, 0.7, if d[1] == 0 then 4.4 else 1.8 }, at = { d[1] * 5.0, 2.3, d[2] * 5.0 }, color = "hull" })
	table.insert(parts, { name = `marker{i}`, parent = "base", shape = "box", size = { 0.6, 0.5, 0.6 }, at = { d[1] * 7.4, 0.95, d[2] * 7.4 }, color = "glass" })
end

return { id = "ord_seaextractor", parts = parts }

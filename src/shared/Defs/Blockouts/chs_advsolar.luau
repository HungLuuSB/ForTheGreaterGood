--!strict
-- Advanced Sun Trap (Chaos, T1, footprint 2; S-209, BAR coradvsol): a round
-- collector bowl, an armored rim ringed by eight team-capped pods, dark
-- collector cells sloping to a hub with an orange core. Model space,
-- forward = -Z (docs/contracts/rig.md).

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.6, 0.55, 15.6 }, at = { 0, 0.28, 0 }, color = "dark" },
	{ name = "rim", parent = "base", shape = "cylinder", axis = "y", size = { 13.4, 1.6, 13.4 }, at = { 0, 1.3, 0 }, color = "hull" },
	{ name = "bowl", parent = "base", shape = "cylinder", axis = "y", size = { 10.8, 0.2, 10.8 }, at = { 0, 2.05, 0 }, color = "dark" },
	{ name = "hub", parent = "base", shape = "cylinder", axis = "y", size = { 2.5, 1.0, 2.5 }, at = { 0, 2.6, 0 }, color = "metal" },
	{ name = "core", parent = "base", shape = "cylinder", axis = "y", size = { 1.2, 0.2, 1.2 }, at = { 0, 3.2, 0 }, color = "glass" },
}
for i = 0, 7 do
	local a = math.pi * 2 * (i + 0.5) / 8
	local x, z = math.cos(a) * 6.85, math.sin(a) * 6.85
	table.insert(parts, { name = `pod{i + 1}`, parent = "base", shape = "box", size = { 1.9, 2.0, 1.5 }, at = { x, 1.25, z }, rot = { 0, -math.deg(a) + 90, 0 }, color = "hull" })
	table.insert(parts, { name = `podTeam{i + 1}`, parent = "base", shape = "box", size = { 1.6, 0.2, 1.1 }, at = { x, 2.35, z }, rot = { 0, -math.deg(a) + 90, 0 }, color = "team" })
end

return {
	id = "chs_advsolar",
	parts = parts,
}

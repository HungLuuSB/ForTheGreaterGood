--!strict
-- Great Smelter (Chaos T2 converter, footprint 3; S-209, BAR's cormmkr):
-- the T1 Smelter's furnace grown into a fortified octagonal kiln. A dark
-- housing under a sloped armored ring with team plates, a ring of glowing
-- furnace panels round a flue cap (`crucible`, pulse), a big charging hatch
-- sloping to the pad at the front, corrugated hoses to anchor blocks either
-- side. Model space, forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 23.4, 0.6, 23.4 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "housing", parent = "base", shape = "cylinder", axis = "y", size = { 17, 2.8, 17 }, at = { 0, 2, 0 }, color = "dark" },
	{ name = "armor", parent = "base", shape = "cylinder", axis = "y", size = { 18, 2.6, 18 }, at = { 0, 4.7, 0 }, color = "hull" },
	{ name = "teamL", parent = "base", shape = "box", size = { 0.1, 1.8, 5 }, at = { -8.6, 4.8, 0 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 0.1, 1.8, 5 }, at = { 8.6, 4.8, 0 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 5, 1.8, 0.1 }, at = { 0, 4.8, 8.6 }, color = "team" },
	{ name = "crucible", parent = "base", shape = "cylinder", axis = "y", size = { 12, 1.4, 12 }, at = { 0, 6.7, 0 }, color = "glass", anim = { motion = "pulse", axis = { 0, 1, 0 } } },
	{ name = "flue", parent = "base", shape = "cylinder", axis = "y", size = { 9, 0.4, 9 }, at = { 0, 7.6, 0 }, color = "metal" },
	{ name = "hatch", parent = "base", shape = "wedge", size = { 6.8, 3.4, 3.6 }, at = { 0, 2.3, -9.4 }, color = "hull" },
	{ name = "mouth", parent = "base", shape = "box", size = { 5.4, 0.5, 0.1 }, at = { 0, 1, -11.25 }, color = "glass" },
}
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `hose{tag}`, parent = "base", shape = "box", size = { 0.9, 4.4, 0.9 }, at = { sx * 9.4, 3, sz * 5.2 }, rot = { sz * 20, 0, sx * -35 }, color = "dark" })
		table.insert(parts, { name = `anchor{tag}`, parent = "base", shape = "box", size = { 2.2, 0.9, 2.2 }, at = { sx * 10.4, 1.05, sz * 6.4 }, color = "metal" })
	end
end

return { id = "chs_advconverter", parts = parts }

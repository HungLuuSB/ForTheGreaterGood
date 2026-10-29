--!strict
-- Great Hoard (Chaos hardened supply storage, T2, footprint 3; S-209, BAR's
-- coruwadvms): four squat armored silos on sloped skirts with team plates
-- and claw feet, round a tall pump tower with a team cap whose elbow pipes
-- arch down into the silos. Little glow: sealed tanks. Model space,
-- forward = -Z.

local parts: { any } = {
	{ name = "base", shape = "box", size = { 23.4, 0.6, 23.4 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "tower", parent = "base", shape = "cylinder", axis = "y", size = { 5, 10, 5 }, at = { 0, 5.6, 0 }, color = "dark" },
	{ name = "waist", parent = "base", shape = "cylinder", axis = "y", size = { 5.4, 2.8, 5.4 }, at = { 0, 7.8, 0 }, color = "hull" },
	{ name = "cap", parent = "base", shape = "cylinder", axis = "y", size = { 3.6, 0.1, 3.6 }, at = { 0, 10.65, 0 }, color = "team" },
}
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		local x, z = sx * 5.4, sz * 5.4
		table.insert(parts, { name = `skirt{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 9.2, 2.4, 9.2 }, at = { x, 1.8, z }, color = "hull" })
		table.insert(parts, { name = `tank{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 5.8, 3.9, 5.8 }, at = { x, 4.95, z }, color = "dark" })
		table.insert(parts, { name = `team{tag}`, parent = "base", shape = "box", size = { 2, 0.1, 2 }, at = { x + sx * 3, 3.05, z + sz * 3 }, color = "team" })
		table.insert(parts, { name = `pipe{tag}`, parent = "base", shape = "cylinder", axis = "x", size = { 5.6, 1.2, 1.2 }, at = { x * 0.6, 8.4, z * 0.6 }, rot = { 0, sx * sz * -45, 0 }, color = "dark" })
	end
end

return { id = "chs_advdepot", parts = parts }

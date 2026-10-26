--!strict
-- Dragon (Chaos flying fortress, T2, footprint 3; S-181; huge, tough, fast;
-- pours fire straight down, two green lasers): a dragon-headed armored hull
-- (horns, glowing eyes, a jaw), a spiked spine, broad swept wings each
-- carrying a big ducted fan (`fanL` / `fanR`, client-spun), a long tail with
-- fins. Under the hull the `belly` turret (turns) with the `flame` nozzle
-- pointing down (the fire gun fires from it); a `laser_l` / `laser_r`
-- turret at each wing tip, `laser_l_muzzle` / `laser_r_muzzle` at their
-- green lenses. Chaos reads crude and brutal (M-14). Model space,
-- forward = -Z.

local WY = 3.6 -- the wings' height
local TX, TZ = 15.2, -1.2 -- the wing-tip turrets

local parts = {
	{ name = "base", shape = "box", size = { 7, 4, 18 }, at = { 0, 3, 0 }, color = "hull" },
	-- the head
	{ name = "head", parent = "base", shape = "wedge", size = { 5, 3, 5 }, at = { 0, 3.5, -11.5 }, color = "hull" },
	{ name = "jaw", parent = "base", shape = "box", size = { 3.6, 1.2, 3.4 }, at = { 0, 1.5, -10.8 }, color = "dark" },
	{ name = "eyeL", parent = "base", shape = "box", size = { 0.8, 0.4, 0.8 }, at = { -1.6, 4.3, -10.4 }, color = "glass" },
	{ name = "eyeR", parent = "base", shape = "box", size = { 0.8, 0.4, 0.8 }, at = { 1.6, 4.3, -10.4 }, color = "glass" },
	{ name = "hornL", parent = "base", shape = "wedge", size = { 0.6, 2.4, 2.4 }, at = { -2, 5.6, -8.4 }, rot = { -20, 0, -15 }, color = "metal" },
	{ name = "hornR", parent = "base", shape = "wedge", size = { 0.6, 2.4, 2.4 }, at = { 2, 5.6, -8.4 }, rot = { -20, 0, 15 }, color = "metal" },
	-- the back and tail
	{ name = "backTeam", parent = "base", shape = "box", size = { 3.6, 0.1, 6 }, at = { 0, 5.05, 2 }, color = "team" },
	{ name = "tail", parent = "base", shape = "box", size = { 3.4, 2.6, 8 }, at = { 0, 3.6, 13 }, color = "hull" },
	{ name = "tailTip", parent = "base", shape = "wedge", size = { 3.4, 2.6, 3 }, at = { 0, 3.6, 18.5 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "finTop", parent = "base", shape = "wedge", size = { 0.4, 3.4, 4 }, at = { 0, 6.6, 14.5 }, rot = { 0, 180, 0 }, color = "team" },
	{ name = "finL", parent = "base", shape = "box", size = { 5, 0.4, 2.6 }, at = { -3.8, 3.8, 15 }, rot = { 0, 0, 10 }, color = "hull" },
	{ name = "finR", parent = "base", shape = "box", size = { 5, 0.4, 2.6 }, at = { 3.8, 3.8, 15 }, rot = { 0, 0, -10 }, color = "hull" },
}
for i, z in { -6, -3, 0, 3, 6, 9 } do -- the spined back
	table.insert(parts, { name = `spine{i}`, parent = "base", shape = "wedge", size = { 0.5, 1.6 - i * 0.12, 2 }, at = { 0, 5.8 - i * 0.06, z }, rot = { 0, 180, 0 }, color = "metal" })
end
for _, sx in { -1, 1 } do -- swept wings with ducted fans
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `wing{tag}`, parent = "base", shape = "box", size = { 12, 0.8, 8 }, at = { sx * 9.2, WY, 1.2 }, rot = { 0, sx * -10, sx * -4 }, color = "hull" })
	table.insert(parts, { name = `wingEdge{tag}`, parent = "base", shape = "box", size = { 12, 0.5, 0.8 }, at = { sx * 9.2, WY + 0.1, -3.0 }, rot = { 0, sx * -10, sx * -4 }, color = "metal" })
	table.insert(parts, { name = `duct{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 6.4, 1.6, 6.4 }, at = { sx * 8.6, WY + 0.4, 1.6 }, color = "dark" })
	table.insert(parts, { name = `fan{tag}`, parent = "base", shape = "box", size = { 5.6, 0.25, 0.9 }, at = { sx * 8.6, WY + 0.5, 1.6 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } })
	table.insert(parts, { name = `fanHub{tag}`, parent = `fan{tag}`, shape = "cylinder", axis = "y", size = { 1.2, 0.5, 1.2 }, at = { sx * 8.6, WY + 0.6, 1.6 }, color = "glass" })
	table.insert(parts, { name = `wingTeam{tag}`, parent = "base", shape = "box", size = { 3, 0.1, 3 }, at = { sx * 13, WY + 0.5, 3.6 }, color = "team" })
	table.insert(parts, { name = `claw{tag}`, parent = "base", shape = "wedge", size = { 0.6, 1.6, 2.4 }, at = { sx * 15.6, WY - 0.8, 3.6 }, rot = { 180, 0, 0 }, color = "metal" })
end
for _, p in {
	{ name = "belly", parent = "base", shape = "cylinder", axis = "y", size = { 3.8, 1.4, 3.8 }, at = { 0, 0.4, -2 }, pivot = { 0, 1, -2 }, color = "metal" },
	{ name = "flame", parent = "belly", shape = "cylinder", axis = "y", size = { 1.6, 1.8, 1.6 }, at = { 0, -1.1, -2 }, color = "dark" },
	{ name = "flameGlow", parent = "flame", shape = "cylinder", axis = "y", size = { 1.1, 0.1, 1.1 }, at = { 0, -2.05, -2 }, color = "glass" },
	{ name = "laser_l", parent = "base", shape = "box", size = { 1.8, 1.6, 2.2 }, at = { -TX, WY, TZ }, pivot = { -TX, WY, TZ + 0.6 }, color = "dark" },
	{ name = "laserBarrelL", parent = "laser_l", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 3.2 }, at = { -TX, WY, TZ - 2.6 }, color = "metal" },
	{ name = "laserLensL", parent = "laser_l", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.1 }, at = { -TX, WY, TZ - 4.25 }, color = "glass" },
	{ name = "laser_r", parent = "base", shape = "box", size = { 1.8, 1.6, 2.2 }, at = { TX, WY, TZ }, pivot = { TX, WY, TZ + 0.6 }, color = "dark" },
	{ name = "laserBarrelR", parent = "laser_r", shape = "cylinder", axis = "z", size = { 0.7, 0.7, 3.2 }, at = { TX, WY, TZ - 2.6 }, color = "metal" },
	{ name = "laserLensR", parent = "laser_r", shape = "cylinder", axis = "z", size = { 0.55, 0.55, 0.1 }, at = { TX, WY, TZ - 4.25 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_dragon",
	parts = parts,
	attachments = {
		{ name = "laser_l_muzzle", parent = "laser_l", at = { -TX, WY, TZ - 4.4 } },
		{ name = "laser_r_muzzle", parent = "laser_r", at = { TX, WY, TZ - 4.4 } },
	},
}

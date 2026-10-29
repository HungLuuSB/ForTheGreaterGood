--!strict
-- Experimental Gantry (Order T3 factory, footprint 7; S-209, BAR armshltx):
-- a tall armored hall at the back with a stepped command tower (a lit
-- screen, twin vent stacks, hazard plates), and in front a big lit pad for
-- the 24-stud Titan between two tall emitter towers, each carrying a beam
-- with three emitter heads over the pad, antennas on the right tower. Open
-- at the front (-Z) for the mech to walk out. Order reads clean and heavy
-- (M-14). Model space, forward = -Z.

local PZ = -9 -- the pad's centre
local GY = 26 -- the emitter beams' height
local TX = 16.5 -- the towers' x
local BX = 13.6 -- the emitter beams' x

local parts = {
	{ name = "base", shape = "box", size = { 54, 0.6, 54 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "pad", parent = "base", shape = "box", size = { 26, 0.2, 26 }, at = { 0, 0.7, PZ }, color = "metal" },
	{ name = "padGrid", parent = "base", shape = "box", size = { 20, 0.06, 20 }, at = { 0, 0.83, PZ }, color = "glass" },
	{ name = "padHazard", parent = "base", shape = "box", size = { 26, 0.06, 1 }, at = { 0, 0.83, PZ - 13.5 }, color = "hazard" },
	{ name = "apron", parent = "base", shape = "wedge", size = { 18, 0.6, 4 }, at = { 0, 0.9, -24.5 }, rot = { 0, 180, 0 }, color = "metal" },

	-- the hall and its command tower
	{ name = "hall", parent = "base", shape = "box", size = { 38, 16, 22 }, at = { 0, 8.6, 16 }, color = "hull" },
	{ name = "hallFront", parent = "base", shape = "wedge", size = { 38, 16, 3 }, at = { 0, 8.6, 3.5 }, color = "hull" },
	{ name = "door", parent = "base", shape = "box", size = { 20, 12, 0.3 }, at = { 0, 6.6, 4.6 }, color = "dark" },
	{ name = "doorLight", parent = "base", shape = "box", size = { 20, 0.4, 0.12 }, at = { 0, 12.9, 4.4 }, color = "glass" },
	{ name = "roofTeamL", parent = "base", shape = "box", size = { 10, 0.12, 14 }, at = { -12.5, 16.66, 17 }, color = "team" },
	{ name = "roofTeamR", parent = "base", shape = "box", size = { 10, 0.12, 14 }, at = { 12.5, 16.66, 17 }, color = "team" },
	{ name = "tower", parent = "base", shape = "box", size = { 14, 12, 12 }, at = { 0, 22.6, 17 }, color = "hull" },
	{ name = "towerFront", parent = "base", shape = "wedge", size = { 14, 12, 3 }, at = { 0, 22.6, 9.5 }, color = "hull" },
	{ name = "screen", parent = "base", shape = "box", size = { 5, 3.4, 0.12 }, at = { 0, 21, 8.9 }, rot = { -14, 0, 0 }, color = "glass" },
	{ name = "towerTeam", parent = "base", shape = "box", size = { 10, 0.12, 9 }, at = { 0, 28.66, 17.5 }, color = "team" },
	{ name = "stackL", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4, 3 }, at = { -2.4, 30.6, 19 }, color = "metal" },
	{ name = "stackR", parent = "base", shape = "cylinder", axis = "y", size = { 3, 4, 3 }, at = { 2.4, 30.6, 19 }, color = "metal" },
	{ name = "hazardL", parent = "base", shape = "box", size = { 2.6, 3, 0.1 }, at = { -5.5, 25, 10.4 }, rot = { -14, 0, 0 }, color = "hazard" },
	{ name = "hazardR", parent = "base", shape = "box", size = { 2.6, 3, 0.1 }, at = { 5.5, 25, 10.4 }, rot = { -14, 0, 0 }, color = "hazard" },
}
for _, sx in { -1, 1 } do
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `tower{tag}`, parent = "base", shape = "box", size = { 3.4, GY + 3.4, 4 }, at = { sx * TX, (GY + 3.4) / 2 + 0.6, PZ }, color = "hull" })
	table.insert(parts, { name = `towerFoot{tag}`, parent = "base", shape = "box", size = { 5.4, 5, 14 }, at = { sx * (TX + 0.6), 3.1, PZ }, color = "hull" })
	table.insert(parts, { name = `towerTeam{tag}`, parent = "base", shape = "box", size = { 0.1, 7, 2.6 }, at = { sx * (TX + 1.76), 12, PZ }, color = "team" })
	table.insert(parts, { name = `beam{tag}`, parent = "base", shape = "box", size = { 2.2, 2, 18 }, at = { sx * BX, GY + 1, PZ }, color = "hull" })
	table.insert(parts, { name = `arm{tag}`, parent = "base", shape = "box", size = { 3, 1.4, 2 }, at = { sx * (TX - 1.6), GY + 1.6, PZ }, color = "dark" })
	table.insert(parts, { name = `beamLight{tag}`, parent = "base", shape = "box", size = { 0.12, 0.3, 16 }, at = { sx * (BX - 1.16), GY + 1, PZ }, color = "glass" })
	table.insert(parts, { name = `beacon{tag}`, parent = "base", shape = "box", size = { 0.8, 0.8, 0.8 }, at = { sx * 25, 1, -25 }, color = "glass" })
end
for i = 1, 3 do
	table.insert(parts, { name = `antenna{i}`, parent = "base", shape = "box", size = { 0.4, 6 + i, 0.4 }, at = { TX - 1 + i * 0.7, GY + 3.4 + (6 + i) / 2, PZ + 1 }, color = "dark" })
end
local Z = { PZ - 6, PZ, PZ + 6 }
for i, z in Z do
	table.insert(parts, { name = `emitterL{i}`, parent = "base", shape = "box", size = { 1.4, 1.2, 1.4 }, at = { -BX, GY - 0.6, z }, color = "metal" })
	table.insert(parts, { name = `emitterR{i}`, parent = "base", shape = "box", size = { 1.4, 1.2, 1.4 }, at = { BX, GY - 0.6, z }, color = "metal" })
end

return {
	id = "ord_gantry",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0.8, PZ } },
		{ name = "nano1", parent = "base", at = { -BX, GY - 1.3, PZ - 6 } },
		{ name = "nano2", parent = "base", at = { BX, GY - 1.3, PZ - 6 } },
		{ name = "nano3", parent = "base", at = { -BX, GY - 1.3, PZ } },
		{ name = "nano4", parent = "base", at = { BX, GY - 1.3, PZ } },
		{ name = "nano5", parent = "base", at = { -BX, GY - 1.3, PZ + 6 } },
		{ name = "nano6", parent = "base", at = { BX, GY - 1.3, PZ + 6 } },
	},
}

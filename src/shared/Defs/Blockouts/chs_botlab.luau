--!strict
-- Bot Pit (Chaos bot factory, T1, footprint 4; S-181): a patched slab with a
-- round assembly pit walled by scrap plates, open at the front where a ramp
-- leads out at -Z; two lattice crane masts reach over the pit with hooks
-- that spray, a shed and fuel tanks at the back, amber lamps. Chaos reads
-- crude and exposed (M-14). Model space, forward = -Z (docs/contracts/rig.md).

local PZ = -2 -- the pit's centre
local JY = 14.2 -- the jibs' height

local parts = {
	{ name = "base", shape = "box", size = { 30, 0.5, 30 }, at = { 0, 0.25, 0 }, color = "dark" },
	{ name = "pitFloor", parent = "base", shape = "cylinder", axis = "y", size = { 17, 0.3, 17 }, at = { 0, 0.65, PZ }, color = "metal" },
	{ name = "pitGrate", parent = "base", shape = "cylinder", axis = "y", size = { 7, 0.1, 7 }, at = { 0, 0.85, PZ }, color = "glass" },
	{ name = "ramp", parent = "base", shape = "wedge", size = { 7, 1.2, 4 }, at = { 0, 1.1, PZ - 11 }, color = "metal" },
	{ name = "rampHazard", parent = "base", shape = "box", size = { 7, 0.06, 0.6 }, at = { 0, 0.53, PZ - 13.2 }, color = "hazard" },

	-- the shed and tanks at the back
	{ name = "shed", parent = "base", shape = "box", size = { 14, 6, 5 }, at = { -4, 3.25, 11.5 }, color = "hull" },
	{ name = "shedRoof", parent = "base", shape = "wedge", size = { 14, 1.4, 5 }, at = { -4, 6.95, 11.5 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "shedTeam", parent = "base", shape = "box", size = { 6, 2, 0.1 }, at = { -4, 4, 8.95 }, color = "team" },
	{ name = "tankA", parent = "base", shape = "cylinder", axis = "y", size = { 3, 5, 3 }, at = { 8, 3, 11 }, color = "metal" },
	{ name = "tankB", parent = "base", shape = "cylinder", axis = "y", size = { 3, 5, 3 }, at = { 11.5, 3, 11 }, color = "metal" },
	{ name = "teamA", parent = "base", shape = "box", size = { 5, 0.1, 5 }, at = { -10.5, 0.55, -10.5 }, color = "team" },
}
for i = 0, 7 do -- scrap walls round the pit, open at the front
	if i ~= 4 then
		local a = i * 45
		local r = math.rad(a)
		table.insert(parts, { name = `wall{i}`, parent = "base", shape = "box", size = { 6.2, 2.6 + (i % 2) * 0.8, 0.9 }, at = { math.sin(r) * 9.2, 1.8 + (i % 2) * 0.4, PZ + math.cos(r) * 9.2 }, rot = { 0, a, (i % 3 - 1) * 4 }, color = if i % 2 == 0 then "metal" else "hull" })
	end
end
for _, sx in { -1, 1 } do -- crane masts with jibs over the pit
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `mast{tag}`, parent = "base", shape = "box", size = { 1.4, JY, 1.4 }, at = { sx * 11.5, JY / 2 + 0.5, PZ }, color = "dark" })
	table.insert(parts, { name = `mastBrace{tag}`, parent = "base", shape = "box", size = { 0.4, JY * 0.8, 0.4 }, at = { sx * 12.6, JY * 0.42, PZ }, rot = { 0, 0, sx * -8 }, color = "metal" })
	table.insert(parts, { name = `jib{tag}`, parent = "base", shape = "box", size = { 10, 1, 1 }, at = { sx * 7, JY + 0.5, PZ }, color = "metal" })
	table.insert(parts, { name = `hook{tag}`, parent = "base", shape = "box", size = { 1, 1.4, 1 }, at = { sx * 3.5, JY - 0.7, PZ }, color = "dark" })
	table.insert(parts, { name = `lamp{tag}`, parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { sx * 11.5, JY + 1.3, PZ }, color = "glass" })
end

return {
	id = "chs_botlab",
	parts = parts,
	-- nanoframe anchors (M-25, rig.md 8)
	attachments = {
		{ name = "buildpad", parent = "base", at = { 0, 0.8, PZ } },
		{ name = "nano1", parent = "base", at = { -3.5, JY - 1.5, PZ } },
		{ name = "nano2", parent = "base", at = { 3.5, JY - 1.5, PZ } },
	},
}

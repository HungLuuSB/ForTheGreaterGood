--!strict
-- Rampart (Order coastal battery, T2, footprint 3; F18 redesign 2026-10-26,
-- the user's beta feedback: "turret should stand high, proud, tower above
-- others"): a sea-wall bunker with a sloped front, a tall square gun tower
-- with four round corner bartizans (team bands, lamps) and a parapet, and on
-- top (ring at RING studs) a broad turret with twin very long guns and a
-- rangefinder bar (top ~25 studs with the radar). Order reads clean and
-- heavy (M-14). Model space, forward = -Z.

local RING = 17.6 -- top of the tower, where the turret turns
local GY = RING + 2.1 -- gun height
local TZ = 1.5 -- the tower sits a little back on the sea wall

local parts = {
	{ name = "base", shape = "box", size = { 22, 4, 18 }, at = { 0, 2, 1 }, color = "hull" },
	{ name = "wallF", parent = "base", shape = "wedge", size = { 22, 4, 3 }, at = { 0, 2, -9.5 }, color = "hull" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 10, 0.1, 1 }, at = { 0, 4.05, -7.4 }, color = "hazard" },
	{ name = "tower", parent = "base", shape = "box", size = { 10, RING - 4, 10 }, at = { 0, 4 + (RING - 4) / 2, TZ }, color = "hull" },
	{ name = "glacis", parent = "base", shape = "wedge", size = { 10, 6, 2.4 }, at = { 0, 7, TZ - 6.2 }, color = "hull" },
	{ name = "towerBand", parent = "base", shape = "box", size = { 10.2, 0.7, 10.2 }, at = { 0, RING - 4.4, TZ }, color = "team" },
	{ name = "parapetF", parent = "base", shape = "box", size = { 10.4, 1, 0.6 }, at = { 0, RING + 0.3, TZ - 4.9 }, color = "hull" },
	{ name = "parapetB", parent = "base", shape = "box", size = { 10.4, 1, 0.6 }, at = { 0, RING + 0.3, TZ + 4.9 }, color = "hull" },
	{ name = "parapetL", parent = "base", shape = "box", size = { 0.6, 1, 10.4 }, at = { -4.9, RING + 0.3, TZ }, color = "hull" },
	{ name = "parapetR", parent = "base", shape = "box", size = { 0.6, 1, 10.4 }, at = { 4.9, RING + 0.3, TZ }, color = "hull" },
	{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 9, 0.6, 9 }, at = { 0, RING + 0.1, TZ - 0.3 }, color = "dark" },
	{ name = "slitF", parent = "base", shape = "box", size = { 5, 0.5, 0.1 }, at = { 0, RING - 2.4, TZ - 5.05 }, color = "glass" },
}
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do -- corner bartizans
		local x, z = sx * 5.2, TZ + sz * 5.2
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `bartizan{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 2.6, RING - 3, 2.6 }, at = { x, 4 + (RING - 3) / 2, z }, color = "hull" })
		table.insert(parts, { name = `bartizanBand{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 2.8, 0.8, 2.8 }, at = { x, RING - 4.4, z }, color = "team" })
		table.insert(parts, { name = `bartizanCap{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 3, 0.5, 3 }, at = { x, RING + 1.25, z }, color = "dark" })
		table.insert(parts, { name = `lamp{tag}`, parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { x, RING + 1.8, z }, color = "glass" })
	end
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 9, 3.8, 8 }, at = { 0, GY, TZ + 0.1 }, pivot = { 0, RING, TZ - 0.3 }, color = "hull" },
	{ name = "turretFront", parent = "turret", shape = "wedge", size = { 9, 3.8, 2.4 }, at = { 0, GY, TZ - 5.1 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 7, 0.1, 6 }, at = { 0, GY + 1.95, TZ + 0.5 }, color = "team" },
	{ name = "gunL", parent = "turret", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 14 }, at = { -1.8, GY, -12.3 }, color = "metal" },
	{ name = "gunR", parent = "turret", shape = "cylinder", axis = "z", size = { 1.1, 1.1, 14 }, at = { 1.8, GY, -12.3 }, color = "metal" },
	{ name = "sleeveL", parent = "turret", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 3 }, at = { -1.8, GY, -6.7 }, color = "dark" },
	{ name = "sleeveR", parent = "turret", shape = "cylinder", axis = "z", size = { 1.6, 1.6, 3 }, at = { 1.8, GY, -6.7 }, color = "dark" },
	{ name = "brakeL", parent = "turret", shape = "box", size = { 1.6, 1.6, 1.2 }, at = { -1.8, GY, -18.9 }, color = "dark" },
	{ name = "brakeR", parent = "turret", shape = "box", size = { 1.6, 1.6, 1.2 }, at = { 1.8, GY, -18.9 }, color = "dark" },
	{ name = "rangefinder", parent = "turret", shape = "box", size = { 9, 0.6, 0.6 }, at = { 0, GY + 2.5, TZ + 2.1 }, color = "dark" },
	{ name = "rangeL", parent = "turret", shape = "box", size = { 0.1, 0.4, 0.4 }, at = { -4.55, GY + 2.5, TZ + 2.1 }, color = "glass" },
	{ name = "rangeR", parent = "turret", shape = "box", size = { 0.1, 0.4, 0.4 }, at = { 4.55, GY + 2.5, TZ + 2.1 }, color = "glass" },
	{ name = "radarMast", parent = "turret", shape = "box", size = { 0.4, 2.6, 0.4 }, at = { 3, GY + 3.9, TZ + 3.1 }, color = "dark" },
	{ name = "radar", parent = "turret", shape = "box", size = { 2.4, 0.9, 0.2 }, at = { 3, GY + 5.3, TZ + 3.1 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_rampart",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -1.8, GY, -19.6 } },
	},
}

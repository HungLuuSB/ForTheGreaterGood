--!strict
-- Bastion (Order heavy turret, T2, footprint 3; F18 redesign 2026-10-26, the
-- user's beta feedback: "turret should stand high, proud, tower above
-- others"): a sloped armored plinth, a tall square keep with four buttresses,
-- team bands and lit firing slits, a turret ring at RING studs, and on top a
-- broad wedge turret with twin long guns and a sensor mast (top ~24 studs,
-- six Lancers tall; the T1 Sentry is 16). Order reads clean and heavy
-- (M-14). Model space, forward = -Z.

local RING = 17.4 -- top of the keep, where the turret turns
local GY = RING + 2.2 -- gun height

local parts = {
	{ name = "base", shape = "box", size = { 20, 3, 20 }, at = { 0, 1.5, 0 }, color = "hull" },
	{ name = "slopeF", parent = "base", shape = "wedge", size = { 20, 3, 1.6 }, at = { 0, 1.5, -10.8 }, color = "hull" },
	{ name = "slopeB", parent = "base", shape = "wedge", size = { 20, 3, 1.6 }, at = { 0, 1.5, 10.8 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "slopeL", parent = "base", shape = "wedge", size = { 20, 3, 1.6 }, at = { -10.8, 1.5, 0 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "slopeR", parent = "base", shape = "wedge", size = { 20, 3, 1.6 }, at = { 10.8, 1.5, 0 }, rot = { 0, -90, 0 }, color = "hull" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 8, 0.1, 1 }, at = { 0, 3.05, -8.6 }, color = "hazard" },

	-- the keep: a wide skirt, then a slimmer shaft up to the turret ring
	{ name = "skirt", parent = "base", shape = "box", size = { 13, 3, 13 }, at = { 0, 4.5, 0 }, color = "hull" },
	{ name = "keep", parent = "base", shape = "box", size = { 9, RING - 4.6, 9 }, at = { 0, 3 + (RING - 4.6) / 2, 0 }, color = "hull" },
	{ name = "keepBand", parent = "base", shape = "box", size = { 9.2, 0.7, 9.2 }, at = { 0, RING - 4.2, 0 }, color = "team" },
	{ name = "keepCap", parent = "base", shape = "box", size = { 10.4, 0.8, 10.4 }, at = { 0, RING - 1.2, 0 }, color = "dark" },
	{ name = "collar", parent = "base", shape = "cylinder", axis = "y", size = { 9.6, 0.8, 9.6 }, at = { 0, RING - 0.4, 0 }, color = "dark" },
}
for i, a in { 0, 90, 180, 270 } do -- a tall buttress on each face, sloping up the keep
	local r = math.rad(a)
	local face = { "F", "L", "B", "R" }
	table.insert(parts, { name = `buttress{face[i]}`, parent = "base", shape = "wedge", size = { 4, 9, 2.4 }, at = { -math.sin(r) * 5.7, 10.5, -math.cos(r) * 5.7 }, rot = { 0, a, 0 }, color = "hull" })
	table.insert(parts, { name = `slit{face[i]}`, parent = "base", shape = "box", size = { 3.4, 0.5, 0.1 }, at = { -math.sin(r) * 4.55, RING - 2.6, -math.cos(r) * 4.55 }, rot = { 0, a, 0 }, color = "glass" })
end
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do -- corner lights on the plinth
		table.insert(parts, { name = `light{sx}{sz}`, parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { sx * 9.2, 3.35, sz * 9.2 }, color = "glass" })
	end
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 9, 3.6, 8.5 }, at = { 0, GY, 0.6 }, pivot = { 0, RING, 0 }, color = "hull" },
	{ name = "turretFront", parent = "turret", shape = "wedge", size = { 9, 3.6, 2.2 }, at = { 0, GY, -4.75 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 7, 0.1, 5.5 }, at = { 0, GY + 1.85, 1 }, color = "team" },
	{ name = "mantlet", parent = "turret", shape = "box", size = { 4.4, 2.2, 1 }, at = { 0, GY, -6.2 }, color = "dark" },
	{ name = "gunL", parent = "turret", shape = "cylinder", axis = "z", size = { 1, 1, 10 }, at = { -1.2, GY, -11.4 }, color = "metal" },
	{ name = "gunR", parent = "turret", shape = "cylinder", axis = "z", size = { 1, 1, 10 }, at = { 1.2, GY, -11.4 }, color = "metal" },
	{ name = "brakeL", parent = "turret", shape = "box", size = { 1.5, 1.5, 1 }, at = { -1.2, GY, -16 }, color = "dark" },
	{ name = "brakeR", parent = "turret", shape = "box", size = { 1.5, 1.5, 1 }, at = { 1.2, GY, -16 }, color = "dark" },
	{ name = "sight", parent = "turret", shape = "box", size = { 1, 0.5, 0.1 }, at = { 3, GY + 1, -4.1 }, color = "glass" },
	{ name = "sensorMast", parent = "turret", shape = "box", size = { 0.4, 2.6, 0.4 }, at = { -3, GY + 3.2, 3 }, color = "dark" },
	{ name = "sensorHead", parent = "turret", shape = "box", size = { 1.8, 0.8, 0.8 }, at = { -3, GY + 4.7, 3 }, color = "dark" },
	{ name = "sensorGlass", parent = "turret", shape = "box", size = { 1.4, 0.4, 0.06 }, at = { -3, GY + 4.7, 2.58 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_bastion",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = { -1.2, GY, -16.6 } },
	},
}

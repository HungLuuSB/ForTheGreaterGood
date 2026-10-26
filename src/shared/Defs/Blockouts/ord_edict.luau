--!strict
-- Edict (Order artillery emplacement, T2, footprint 3; F18 redesign
-- 2026-10-26, the user's beta feedback: "turret should stand high, proud,
-- tower above others"): a stepped three-tier fortress with a team band and
-- lit slits, a turret ring at 14.8 studs, and on top a big casemate turret
-- with a very long gun raised 20 degrees, recoil cylinders, a muzzle brake
-- and a radar mast (gun tip ~23 studs). Order reads clean and heavy (M-14).
-- Model space, forward = -Z.

local GUN = 20 -- elevation, degrees
local PIVOT = { 0, 17.4, -5.2 } -- where the gun leaves the casemate

local function along(d: number): { number }
	local r = math.rad(GUN)
	return { PIVOT[1], PIVOT[2] + math.sin(r) * d, PIVOT[3] - math.cos(r) * d }
end

local parts = {
	{ name = "base", shape = "box", size = { 22, 3, 22 }, at = { 0, 1.5, 0 }, color = "hull" },
	{ name = "wallF", parent = "base", shape = "wedge", size = { 22, 3, 1 }, at = { 0, 1.5, -11.5 }, color = "hull" },
	{ name = "tier2", parent = "base", shape = "box", size = { 16, 5, 16 }, at = { 0, 5.5, 1 }, color = "hull" },
	{ name = "tier2Band", parent = "base", shape = "box", size = { 16.2, 0.6, 16.2 }, at = { 0, 6.8, 1 }, color = "team" },
	{ name = "tier3", parent = "base", shape = "box", size = { 11, 6, 11 }, at = { 0, 11, 1 }, color = "hull" },
	{ name = "slitF", parent = "base", shape = "box", size = { 6, 0.5, 0.1 }, at = { 0, 12.4, -4.55 }, color = "glass" },
	{ name = "slitL", parent = "base", shape = "box", size = { 0.1, 0.5, 5 }, at = { -5.55, 12.4, 1 }, color = "glass" },
	{ name = "slitR", parent = "base", shape = "box", size = { 0.1, 0.5, 5 }, at = { 5.55, 12.4, 1 }, color = "glass" },
	{ name = "ring", parent = "base", shape = "cylinder", axis = "y", size = { 10, 0.8, 10 }, at = { 0, 14.4, 1 }, color = "dark" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 10, 0.1, 1 }, at = { 0, 3.05, -9 }, color = "hazard" },
	{ name = "ammo", parent = "base", shape = "box", size = { 2.4, 3, 3 }, at = { 6.6, 9.5, 6.5 }, color = "hull" },
	{ name = "ammoDoor", parent = "base", shape = "box", size = { 0.1, 2, 2 }, at = { 7.85, 9.2, 6.5 }, color = "dark" },
}
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do -- corner lights on the first tier
		table.insert(parts, { name = `light{sx}{sz}`, parent = "base", shape = "box", size = { 0.7, 0.7, 0.7 }, at = { sx * 10, 3.35, sz * 10 }, color = "glass" })
	end
end
local tip = along(15.4)
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 9, 4.4, 10 }, at = { 0, 17, 2 }, pivot = { 0, 14.8, 1 }, color = "hull" },
	{ name = "turretFront", parent = "turret", shape = "wedge", size = { 9, 4.4, 2.6 }, at = { 0, 17, -4.3 }, color = "hull" },
	{ name = "roofTeam", parent = "turret", shape = "box", size = { 7, 0.1, 7 }, at = { 0, 19.25, 2.4 }, color = "team" },
	{ name = "sight", parent = "turret", shape = "box", size = { 1, 0.5, 0.1 }, at = { 3, 18.4, -3.1 }, color = "glass" },
	{ name = "mantlet", parent = "turret", shape = "box", size = { 3.4, 3, 1.4 }, at = along(-0.2), rot = { GUN, 0, 0 }, color = "dark" },
	{ name = "gun", parent = "turret", shape = "cylinder", axis = "z", size = { 1.3, 1.3, 15 }, at = along(7.5), rot = { GUN, 0, 0 }, color = "metal" },
	{ name = "recoilL", parent = "turret", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 3.4 }, at = { -0.9, along(1.8)[2] + 0.8, along(1.8)[3] }, rot = { GUN, 0, 0 }, color = "metal" },
	{ name = "recoilR", parent = "turret", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 3.4 }, at = { 0.9, along(1.8)[2] + 0.8, along(1.8)[3] }, rot = { GUN, 0, 0 }, color = "metal" },
	{ name = "brake", parent = "turret", shape = "box", size = { 1.9, 1.5, 1.4 }, at = along(14.6), rot = { GUN, 0, 0 }, color = "dark" },
	{ name = "radarMast", parent = "turret", shape = "box", size = { 0.4, 3, 0.4 }, at = { -3, 20.7, 5.5 }, color = "dark" },
	{ name = "radar", parent = "turret", shape = "box", size = { 2.6, 1, 0.2 }, at = { -3, 22.4, 5.5 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_edict",
	parts = parts,
	attachments = {
		{ name = "muzzle", parent = "turret", at = tip },
	},
}

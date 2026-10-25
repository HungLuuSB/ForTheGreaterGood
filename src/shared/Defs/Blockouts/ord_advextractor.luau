--!strict
-- Advanced Extractor (Order, T2, footprint 4; F6 / S-184, 2026-10-26: built
-- centred over the player's own T1 extractor on its 2 x 2 deposit patch,
-- which it replaces when finished, S-108): a gantry astride the deposit.
-- Four armored corner pylons outside the T1's 16-stud footprint with team
-- bands and fuel tanks, bridge beams 9 studs up (clear over the T1 while it
-- works on underneath), and on them a drill housing with a team roof and
-- two big drills (`drillL` / `drillR`, client-turned) reaching down into
-- the patch, lit rings at the ground. Order reads clean and heavy (M-14).
-- Model space, forward = -Z.

local BY = 9.0 -- underside of the bridge beams
local P = 11.5 -- the pylons' offset from the centre

local parts = {
	{ name = "base", shape = "box", size = { 30, 0.6, 30 }, at = { 0, 0.3, 0 }, color = "dark" },
	{ name = "patch", parent = "base", shape = "cylinder", axis = "y", size = { 14, 0.1, 14 }, at = { 0, 0.65, 0 }, color = "glass" },
	{ name = "beamF", parent = "base", shape = "box", size = { 2 * P, 2, 3 }, at = { 0, BY + 1, -P }, color = "hull" },
	{ name = "beamB", parent = "base", shape = "box", size = { 2 * P, 2, 3 }, at = { 0, BY + 1, P }, color = "hull" },
	{ name = "beamL", parent = "base", shape = "box", size = { 3, 2, 2 * P }, at = { -P, BY + 1, 0 }, color = "hull" },
	{ name = "beamR", parent = "base", shape = "box", size = { 3, 2, 2 * P }, at = { P, BY + 1, 0 }, color = "hull" },
	{ name = "crossX", parent = "base", shape = "box", size = { 2 * P, 1.4, 2.4 }, at = { 0, BY + 1.3, 0 }, color = "dark" },
	{ name = "crossZ", parent = "base", shape = "box", size = { 2.4, 1.4, 2 * P }, at = { 0, BY + 1.3, 0 }, color = "dark" },
	{ name = "beamLight", parent = "base", shape = "box", size = { 14, 0.25, 0.1 }, at = { 0, BY + 1, -P - 1.55 }, color = "glass" },
	{ name = "housing", parent = "base", shape = "box", size = { 10, 5, 8 }, at = { 0, BY + 4.5, 0 }, color = "hull" },
	{ name = "housingSlopeF", parent = "base", shape = "wedge", size = { 10, 2.4, 1.4 }, at = { 0, BY + 3.2, -4.7 }, color = "hull" },
	{ name = "housingSlopeB", parent = "base", shape = "wedge", size = { 10, 2.4, 1.4 }, at = { 0, BY + 3.2, 4.7 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "roofTeam", parent = "base", shape = "box", size = { 7, 0.12, 5 }, at = { 0, BY + 7.06, 0 }, color = "team" },
	{ name = "vent", parent = "base", shape = "box", size = { 3, 0.8, 2 }, at = { 3, BY + 7.4, 2.4 }, color = "metal" },
	{ name = "hazardF", parent = "base", shape = "box", size = { 12, 0.06, 0.8 }, at = { 0, 0.63, -8.6 }, color = "hazard" },
}
for _, sx in { -1, 1 } do
	for _, sz in { -1, 1 } do -- corner pylons
		local tag = `{if sx < 0 then "L" else "R"}{if sz < 0 then "F" else "B"}`
		table.insert(parts, { name = `pylon{tag}`, parent = "base", shape = "box", size = { 5, BY + 2, 5 }, at = { sx * P, (BY + 2) / 2 + 0.6, sz * P }, color = "hull" })
		table.insert(parts, { name = `pylonBand{tag}`, parent = "base", shape = "box", size = { 5.2, 0.7, 5.2 }, at = { sx * P, 5, sz * P }, color = "team" })
		table.insert(parts, { name = `pylonCap{tag}`, parent = "base", shape = "box", size = { 5.6, 0.6, 5.6 }, at = { sx * P, BY + 2.9, sz * P }, color = "dark" })
		table.insert(parts, { name = `pylonLight{tag}`, parent = "base", shape = "box", size = { 0.6, 0.6, 0.6 }, at = { sx * P, BY + 3.5, sz * P }, color = "glass" })
	end
	local tag = if sx < 0 then "L" else "R"
	table.insert(parts, { name = `tank{tag}`, parent = "base", shape = "cylinder", axis = "z", size = { 2.6, 2.6, 8 }, at = { sx * 13.6, 2.2, 0 }, color = "metal" })
	table.insert(parts, { name = `pipe{tag}`, parent = "base", shape = "box", size = { 7, 0.6, 0.6 }, at = { sx * 7.5, BY + 3.0, 2.8 }, color = "metal" })
	-- the drills: client-turned, down from the housing into the patch
	table.insert(parts, { name = `drill{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 2.6, BY + 4, 2.6 }, at = { sx * 2.4, (BY + 4) / 2 + 0.6, 0 }, color = "metal", anim = { motion = "turn", axis = { 0, 1, 0 } } })
	table.insert(parts, { name = `ring{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 3.4, 0.3, 3.4 }, at = { sx * 2.4, 1.6, 0 }, color = "glass" })
	table.insert(parts, { name = `drillCap{tag}`, parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 0.8, 1.8 }, at = { sx * 2.4, BY + 7.4, 0 }, color = "dark" })
end

return {
	id = "ord_advextractor",
	parts = parts,
}

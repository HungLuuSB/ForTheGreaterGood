--!strict
-- Blister (Chaos amphibious crawling bomb, T2): a low tick on four short
-- clawed legs, its swollen sac glowing through a cage of ribs, a hazard band. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.4, 0.7, 1.8 }, at = { 0, 1, 0 }, color = "dark" },
}
local visual = Bots.spider(parts, { legs = 4, hipR = 0.65, hipY = 1, kneeR = 1.35, kneeY = 1.7, footR = 1.8, thick = 0.24, color = "hull" })
for _, p in {
	{ name = "sac", parent = "base", shape = "ball", size = { 1.7, 1.2, 1.9 }, at = { 0, 1.55, 0.2 }, color = "glass" },
	{ name = "rib1", parent = "base", shape = "box", size = { 1.9, 0.15, 0.15 }, at = { 0, 2.05, -0.3 }, color = "metal" },
	{ name = "rib2", parent = "base", shape = "box", size = { 1.9, 0.15, 0.15 }, at = { 0, 2.05, 0.2 }, color = "metal" },
	{ name = "rib3", parent = "base", shape = "box", size = { 1.9, 0.15, 0.15 }, at = { 0, 2.05, 0.7 }, color = "metal" },
	{ name = "hazard", parent = "base", shape = "box", size = { 1.5, 0.2, 0.08 }, at = { 0, 1, -0.94 }, color = "hazard" },
	{ name = "teamBand", parent = "base", shape = "box", size = { 1.5, 0.2, 0.08 }, at = { 0, 1, 0.94 }, color = "team" },
	{ name = "mandibleL", parent = "base", shape = "wedge", size = { 0.2, 0.3, 0.6 }, at = { -0.35, 0.8, -1.15 }, color = "metal" },
	{ name = "mandibleR", parent = "base", shape = "wedge", size = { 0.2, 0.3, 0.6 }, at = { 0.35, 0.8, -1.15 }, color = "metal" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_blister",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "base", at = { 0, 0.9, -1.3 } },
	},
}

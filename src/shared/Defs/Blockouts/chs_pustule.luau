--!strict
-- Pustule (Chaos cloaked amphibious crawling bomb, big blast, T2): a fat tick on
-- four clawed legs, a huge glowing sac caged in metal ribs, dark plates. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 2.2 }, at = { 0, 1.2, 0 }, color = "dark" },
}
local visual = Bots.spider(parts, { legs = 4, hipR = 0.85, hipY = 1.2, kneeR = 1.75, kneeY = 2.2, footR = 2.4, thick = 0.3, color = "dark" })
for _, p in {
	{ name = "sac", parent = "base", shape = "ball", size = { 2.4, 1.8, 2.6 }, at = { 0, 2, 0.3 }, color = "glass" },
	{ name = "rib1", parent = "base", shape = "box", size = { 2.6, 0.18, 0.18 }, at = { 0, 2.75, -0.5 }, color = "metal" },
	{ name = "rib2", parent = "base", shape = "box", size = { 2.6, 0.18, 0.18 }, at = { 0, 2.75, 0.2 }, color = "metal" },
	{ name = "rib3", parent = "base", shape = "box", size = { 2.6, 0.18, 0.18 }, at = { 0, 2.75, 0.9 }, color = "metal" },
	{ name = "spine", parent = "base", shape = "box", size = { 0.2, 0.2, 2.4 }, at = { 0, 2.95, 0.3 }, color = "metal" },
	{ name = "hazard", parent = "base", shape = "box", size = { 1.9, 0.25, 0.08 }, at = { 0, 1.2, -1.14 }, color = "hazard" },
	{ name = "teamBand", parent = "base", shape = "box", size = { 1.9, 0.25, 0.08 }, at = { 0, 1.2, 1.14 }, color = "team" },
	{ name = "torso", parent = "base", shape = "box", size = { 1, 0.5, 0.4 }, at = { 0, 1.15, -1.3 }, pivot = { 0, 1.15, -1.1 }, color = "dark" },
	{ name = "eyes", parent = "torso", shape = "box", size = { 0.6, 0.1, 0.05 }, at = { 0, 1.25, -1.52 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_pustule",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 0, 1.15, -1.55 } },
	},
}

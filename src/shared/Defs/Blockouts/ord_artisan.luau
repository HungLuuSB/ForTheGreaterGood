--!strict
-- Artisan (Order bot constructor, T1, footprint 1; S-181): an upright
-- two-legged worker, a boxy body with a visor and a backpack, a short left
-- arm, and on the right shoulder the `nano`: a jointed emitter arm whose tip
-- sprays (`nano1`). Legs are client pieces (Bots.luau). Order reads clean
-- (M-14). Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.8, 0 }, color = "hull" },
	{ name = "body", parent = "base", shape = "box", size = { 2.2, 1.8, 1.8 }, at = { 0, 4.1, 0.1 }, color = "hull" },
	{ name = "visor", parent = "base", shape = "box", size = { 1.4, 0.4, 0.1 }, at = { 0, 4.55, -0.82 }, color = "glass" },
	{ name = "pack", parent = "base", shape = "box", size = { 1.6, 1.6, 0.9 }, at = { 0, 4.0, 1.4 }, color = "dark" },
	{ name = "packTeam", parent = "base", shape = "box", size = { 1.0, 0.8, 0.08 }, at = { 0, 4.1, 1.88 }, color = "team" },
	{ name = "chestTeam", parent = "base", shape = "box", size = { 0.8, 0.5, 0.08 }, at = { -0.5, 3.75, -0.83 }, color = "team" },
	{ name = "armL", parent = "base", shape = "box", size = { 0.5, 1.4, 0.5 }, at = { -1.4, 3.9, 0 }, color = "metal" },
}
local legs = Bots.legs(parts, { hipY = 2.6, hipX = 0.7, thick = 0.55, color = "hull", team = true })
for _, p in {
	{ name = "nano", parent = "base", shape = "box", size = { 0.6, 0.6, 2.2 }, at = { 1.45, 4.6, -0.7 }, pivot = { 1.35, 4.6, 0 }, color = "metal" },
	{ name = "nanoHead", parent = "nano", shape = "cylinder", axis = "z", size = { 0.5, 0.5, 0.4 }, at = { 1.45, 4.6, -1.95 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_artisan",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "nano1", parent = "nano", at = { 1.45, 4.6, -2.2 } },
	},
}

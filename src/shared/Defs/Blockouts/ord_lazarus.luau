--!strict
-- Lazarus (Order helper bot, T1, footprint 1; S-181; repairs, resurrects,
-- reclaims, builds nothing): a field medic. A round body with a glass dome
-- head and a team cross on the chest, a tool arm on the right, and on the
-- left the `nano`: the repair emitter arm whose lens sprays (`nano1`). Legs
-- are client pieces (Bots.luau). Order reads clean (M-14). Model space,
-- forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.8, 0 }, color = "hull" },
	{ name = "body", parent = "base", shape = "cylinder", axis = "y", size = { 2.4, 1.8, 2.4 }, at = { 0, 4.1, 0 }, color = "hull" },
	{ name = "collar", parent = "base", shape = "cylinder", axis = "y", size = { 2.0, 0.3, 2.0 }, at = { 0, 5.15, 0 }, color = "dark" },
	{ name = "dome", parent = "base", shape = "ball", size = { 1.7, 1.3, 1.7 }, at = { 0, 5.55, 0 }, color = "glass" },
	{ name = "crossH", parent = "base", shape = "box", size = { 0.9, 0.28, 0.08 }, at = { 0, 4.2, -1.2 }, color = "team" },
	{ name = "crossV", parent = "base", shape = "box", size = { 0.28, 0.9, 0.08 }, at = { 0, 4.2, -1.2 }, color = "team" },
	{ name = "pack", parent = "base", shape = "box", size = { 1.4, 1.2, 0.7 }, at = { 0, 4.1, 1.45 }, color = "dark" },
	{ name = "armR", parent = "base", shape = "box", size = { 0.45, 0.45, 1.6 }, at = { 1.4, 4.1, -0.5 }, color = "metal" },
	{ name = "armRTip", parent = "base", shape = "box", size = { 0.55, 0.3, 0.4 }, at = { 1.4, 4.1, -1.45 }, color = "dark" },
}
local legs = Bots.legs(parts, { hipY = 2.6, hipX = 0.7, thick = 0.55, color = "hull", team = true })
for _, p in {
	{ name = "nano", parent = "base", shape = "box", size = { 0.5, 0.5, 2.0 }, at = { -1.45, 4.5, -0.75 }, pivot = { -1.35, 4.5, 0 }, color = "metal" },
	{ name = "nanoLens", parent = "nano", shape = "cylinder", axis = "z", size = { 0.6, 0.6, 0.3 }, at = { -1.45, 4.5, -1.85 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_lazarus",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "nano1", parent = "nano", at = { -1.45, 4.5, -2.05 } },
	},
}

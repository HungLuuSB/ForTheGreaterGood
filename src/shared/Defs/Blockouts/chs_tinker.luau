--!strict
-- Tinker (Chaos bot constructor, T1, footprint 1; S-181): a hunched scrap
-- worker on bowed legs, a slab body with an amber eye slit and an exhaust
-- pipe, and the `nano`: a crane boom from its back over the right shoulder,
-- a claw at the tip that sprays (`nano1`). Legs are client pieces
-- (Bots.luau). Chaos reads crude (M-14). Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.4, 0 }, color = "dark" },
	{ name = "body", parent = "base", shape = "box", size = { 2.4, 1.6, 2.2 }, at = { 0, 3.6, 0.3 }, color = "hull" },
	{ name = "hunch", parent = "base", shape = "wedge", size = { 2.4, 0.9, 2.2 }, at = { 0, 4.85, 0.3 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "eye", parent = "base", shape = "box", size = { 1.2, 0.25, 0.1 }, at = { 0, 3.9, -0.82 }, color = "glass" },
	{ name = "pipe", parent = "base", shape = "cylinder", axis = "y", size = { 0.35, 1.4, 0.35 }, at = { -0.8, 5.0, 1.1 }, color = "metal" },
	{ name = "sideTeam", parent = "base", shape = "box", size = { 0.08, 0.8, 1.2 }, at = { -1.24, 3.6, 0.3 }, color = "team" },
	{ name = "armL", parent = "base", shape = "box", size = { 0.55, 1.3, 0.55 }, at = { -1.5, 3.3, -0.1 }, color = "metal" },
}
local legs = Bots.legs(parts, { hipY = 2.3, hipX = 0.75, thick = 0.6, color = "hull", foot = "metal" })
for _, p in {
	{ name = "nano", parent = "base", shape = "box", size = { 0.4, 0.4, 3.4 }, at = { 0.95, 5.2, -0.5 }, pivot = { 0.95, 4.7, 1.0 }, rot = { 14, 0, 0 }, color = "metal" },
	{ name = "claw", parent = "nano", shape = "box", size = { 0.7, 0.5, 0.6 }, at = { 0.95, 5.55, -2.2 }, color = "dark" },
	{ name = "clawLamp", parent = "nano", shape = "box", size = { 0.3, 0.2, 0.1 }, at = { 0.95, 5.55, -2.55 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_tinker",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0.95, 5.4, -2.65 } },
	},
}

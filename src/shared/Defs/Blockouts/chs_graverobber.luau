--!strict
-- Graverobber (Chaos helper bot, T1, footprint 1; S-181; repairs,
-- resurrects, reclaims, builds nothing): a hunched scavenger with a scrap
-- hopper on its back (scrap sticking out), a small head with an amber eye,
-- and the `nano`: a long claw arm on the right that grabs and sprays
-- (`nano1`). Legs are client pieces (Bots.luau). Chaos reads crude (M-14).
-- Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.4, 0 }, color = "dark" },
	{ name = "body", parent = "base", shape = "box", size = { 2.2, 1.6, 2.0 }, at = { 0, 3.6, 0 }, color = "hull" },
	{ name = "head", parent = "base", shape = "box", size = { 1.0, 0.8, 0.9 }, at = { -0.3, 4.4, -1.1 }, color = "hull" },
	{ name = "eye", parent = "base", shape = "box", size = { 0.6, 0.2, 0.1 }, at = { -0.3, 4.45, -1.56 }, color = "glass" },
	{ name = "hopper", parent = "base", shape = "box", size = { 2.4, 1.8, 1.6 }, at = { 0, 4.5, 1.5 }, color = "metal" },
	{ name = "hopperTop", parent = "base", shape = "box", size = { 2.0, 0.1, 1.2 }, at = { 0, 5.42, 1.5 }, color = "dark" },
	{ name = "scrapA", parent = "base", shape = "box", size = { 0.3, 1.2, 0.8 }, at = { -0.5, 5.8, 1.4 }, rot = { 15, 20, 10 }, color = "hull" },
	{ name = "scrapB", parent = "base", shape = "box", size = { 0.9, 0.3, 0.3 }, at = { 0.5, 5.7, 1.7 }, rot = { 0, 30, -25 }, color = "dark" },
	{ name = "hopperTeam", parent = "base", shape = "box", size = { 0.08, 1.0, 1.0 }, at = { -1.24, 4.5, 1.5 }, color = "team" },
	{ name = "armL", parent = "base", shape = "box", size = { 0.5, 1.4, 0.5 }, at = { -1.4, 3.3, -0.2 }, color = "metal" },
}
local legs = Bots.legs(parts, { hipY = 2.3, hipX = 0.75, thick = 0.6, color = "hull", foot = "metal" })
for _, p in {
	{ name = "nano", parent = "base", shape = "box", size = { 0.5, 0.5, 2.6 }, at = { 1.45, 3.7, -1.1 }, pivot = { 1.35, 4.0, 0 }, rot = { -10, 0, 0 }, color = "metal" },
	{ name = "clawA", parent = "nano", shape = "wedge", size = { 0.3, 0.5, 0.9 }, at = { 1.25, 3.35, -2.6 }, rot = { 0, 0, 0 }, color = "dark" },
	{ name = "clawB", parent = "nano", shape = "wedge", size = { 0.3, 0.5, 0.9 }, at = { 1.65, 3.35, -2.6 }, rot = { 0, 0, 0 }, color = "dark" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_graverobber",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "nano1", parent = "nano", at = { 1.45, 3.35, -3.0 } },
	},
}

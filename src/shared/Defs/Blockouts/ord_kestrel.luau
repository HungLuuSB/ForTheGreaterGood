--!strict
-- Kestrel (Order anti-air bot, T1, footprint 1; S-181): an upright bot whose
-- `torso` (turns) carries a sensor mast on the left shoulder and, on the
-- right, the `launcher` (pitches): a box pod with four missile cells, ready
-- lit; `muzzle` at the cells. Legs are client pieces (Bots.luau). Order
-- reads clean (M-14). Model space, forward = -Z.

local Bots = require("./Bots")

local LX, LY = 1.5, 5.0 -- the launcher's centre

local parts: { any } = {
	{ name = "base", shape = "box", size = { 1.8, 0.8, 1.4 }, at = { 0, 2.9, 0 }, color = "hull" },
}
local legs = Bots.legs(parts, { hipY = 2.7, hipX = 0.7, thick = 0.55, color = "hull", team = true })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.0, 1.6, 1.6 }, at = { 0, 4.1, 0 }, pivot = { 0, 3.3, 0 }, color = "hull" },
	{ name = "visor", parent = "torso", shape = "box", size = { 1.2, 0.35, 0.1 }, at = { -0.2, 4.5, -0.84 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 0.08, 0.7, 1.0 }, at = { -1.04, 4.0, 0 }, color = "team" },
	{ name = "mast", parent = "torso", shape = "box", size = { 0.2, 1.2, 0.2 }, at = { -0.8, 5.5, 0.3 }, color = "dark" },
	{ name = "sensor", parent = "torso", shape = "box", size = { 0.8, 0.4, 0.2 }, at = { -0.8, 6.2, 0.3 }, color = "metal" },
	{ name = "launcher", parent = "torso", shape = "box", size = { 1.2, 1.2, 1.8 }, at = { LX, LY, 0 }, pivot = { LX, LY - 0.2, 0.2 }, color = "hull" },
	{ name = "cells", parent = "launcher", shape = "box", size = { 0.9, 0.9, 0.1 }, at = { LX, LY, -0.92 }, color = "glass" },
	{ name = "launcherTeam", parent = "launcher", shape = "box", size = { 0.08, 0.6, 1.2 }, at = { LX + 0.64, LY, 0.1 }, color = "team" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_kestrel",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "launcher", at = { LX, LY, -1.0 } },
	},
}

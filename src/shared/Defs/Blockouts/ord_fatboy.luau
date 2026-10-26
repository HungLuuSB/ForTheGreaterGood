--!strict
-- Fatboy (Order heavy plasma bot, T2, footprint 2; S-181; slow, flattens
-- bases from long range): a fat armored body on short thick legs, sloped
-- front armor, team plates on its flanks, lit vents, and on top the
-- `cannon` (turns): a turret block with a huge plasma barrel, glowing coils
-- and a muzzle ring; `muzzle` at the mouth. Legs are client pieces
-- (Bots.luau). Order reads clean and heavy (M-14). Model space,
-- forward = -Z.

local Bots = require("./Bots")

local CY = 9.2 -- the barrel's height

local parts: { any } = {
	{ name = "base", shape = "box", size = { 7.4, 4.6, 6.4 }, at = { 0, 5.7, 0.2 }, color = "hull" },
	{ name = "front", parent = "base", shape = "wedge", size = { 7.4, 2.6, 1.4 }, at = { 0, 4.7, -3.7 }, rot = { 0, 0, 0 }, color = "hull" },
	{ name = "belly", parent = "base", shape = "box", size = { 5.6, 0.8, 5 }, at = { 0, 3.1, 0.2 }, color = "dark" },
	{ name = "teamL", parent = "base", shape = "box", size = { 0.08, 2.2, 3.6 }, at = { -3.74, 6, 0.4 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 0.08, 2.2, 3.6 }, at = { 3.74, 6, 0.4 }, color = "team" },
	{ name = "ventL", parent = "base", shape = "box", size = { 1.6, 0.3, 0.1 }, at = { -2, 6.8, -2.95 }, color = "glass" },
	{ name = "ventR", parent = "base", shape = "box", size = { 1.6, 0.3, 0.1 }, at = { 2, 6.8, -2.95 }, color = "glass" },
	{ name = "pack", parent = "base", shape = "box", size = { 5, 3, 1.6 }, at = { 0, 6.2, 4.2 }, color = "dark" },
	{ name = "packGlow", parent = "base", shape = "box", size = { 3.6, 0.4, 0.1 }, at = { 0, 6.8, 5.02 }, color = "glass" },
}
local legs = Bots.legs(parts, { hipY = 3.6, hipX = 2.5, thick = 1.5, color = "hull", team = true })
for _, p in {
	{ name = "cannon", parent = "base", shape = "box", size = { 4.4, 2.4, 4.8 }, at = { 0, CY, 0.6 }, pivot = { 0, 8, 0.2 }, color = "hull" },
	{ name = "cannonTeam", parent = "cannon", shape = "box", size = { 3, 0.1, 2.4 }, at = { 0, CY + 1.25, 1.4 }, color = "team" },
	{ name = "breech", parent = "cannon", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 1.4 }, at = { 0, CY, -2.2 }, color = "dark" },
	{ name = "barrel", parent = "cannon", shape = "cylinder", axis = "z", size = { 1.7, 1.7, 5.4 }, at = { 0, CY, -5.4 }, color = "metal" },
	{ name = "coil1", parent = "cannon", shape = "cylinder", axis = "z", size = { 2.1, 2.1, 0.35 }, at = { 0, CY, -4.0 }, color = "glass" },
	{ name = "coil2", parent = "cannon", shape = "cylinder", axis = "z", size = { 2.1, 2.1, 0.35 }, at = { 0, CY, -5.6 }, color = "glass" },
	{ name = "mouth", parent = "cannon", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 0.8 }, at = { 0, CY, -8.3 }, color = "dark" },
	{ name = "sight", parent = "cannon", shape = "box", size = { 0.8, 0.5, 0.1 }, at = { 1.6, CY + 0.6, -1.75 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "ord_fatboy",
	parts = parts,
	visualPieces = legs,
	attachments = {
		{ name = "muzzle", parent = "cannon", at = { 0, CY, -8.8 } },
	},
}

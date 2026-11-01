--!strict
-- Pandemonium (Chaos heavy rocket mech, T3): a stooped mech with a massive
-- rocket box on each shoulder, nine amber tubes each, a small armoured head and
-- spikes. Laid out at bot size and scaled x2.0. Batch 2 of the BAR roster (2026-11-01): drawn from the role ahead of the def. Model space, forward = -Z.

local Bots = require("./Bots")

local parts: { any } = {
	{ name = "base", shape = "box", size = { 2.3, 0.8, 1.8 }, at = { 0, 3, 0 }, color = "dark" },
}
local visual = Bots.legs(parts, { hipY = 2.8, hipX = 1, thick = 0.85, color = "hull", foot = "metal" })
for _, p in {
	{ name = "torso", parent = "base", shape = "box", size = { 2.6, 1.9, 2.2 }, at = { 0, 4.35, 0.1 }, pivot = { 0, 3.4, 0 }, color = "hull" },
	{ name = "head", parent = "torso", shape = "box", size = { 0.9, 0.55, 0.8 }, at = { 0, 4.8, -1.35 }, color = "hull" },
	{ name = "slit", parent = "torso", shape = "box", size = { 0.7, 0.12, 0.06 }, at = { 0, 4.85, -1.77 }, color = "glass" },
	{ name = "chestTeam", parent = "torso", shape = "box", size = { 1.2, 0.5, 0.08 }, at = { 0, 4, -1.03 }, color = "team" },
	{ name = "boxR", parent = "torso", shape = "box", size = { 1.8, 1.8, 2.4 }, at = { 2.25, 5.6, 0.1 }, color = "hull" },
	{ name = "boxTeamR", parent = "torso", shape = "box", size = { 0.06, 1, 1.6 }, at = { 3.17, 5.6, 0.2 }, color = "team" },
	{ name = "tubeR11", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.75, 5.1, -1.12 }, color = "glass" },
	{ name = "tubeR12", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.75, 5.6, -1.12 }, color = "glass" },
	{ name = "tubeR13", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 1.75, 6.1, -1.12 }, color = "glass" },
	{ name = "tubeR21", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 2.25, 5.1, -1.12 }, color = "glass" },
	{ name = "tubeR22", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 2.25, 5.6, -1.12 }, color = "glass" },
	{ name = "tubeR23", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 2.25, 6.1, -1.12 }, color = "glass" },
	{ name = "tubeR31", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 2.75, 5.1, -1.12 }, color = "glass" },
	{ name = "tubeR32", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 2.75, 5.6, -1.12 }, color = "glass" },
	{ name = "tubeR33", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { 2.75, 6.1, -1.12 }, color = "glass" },
	{ name = "spikeR1", parent = "torso", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { 2.25, 6.85, 0.4 }, color = "metal" },
	{ name = "boxL", parent = "torso", shape = "box", size = { 1.8, 1.8, 2.4 }, at = { -2.25, 5.6, 0.1 }, color = "hull" },
	{ name = "boxTeamL", parent = "torso", shape = "box", size = { 0.06, 1, 1.6 }, at = { -3.17, 5.6, 0.2 }, color = "team" },
	{ name = "tubeL11", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -2.75, 5.1, -1.12 }, color = "glass" },
	{ name = "tubeL12", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -2.75, 5.6, -1.12 }, color = "glass" },
	{ name = "tubeL13", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -2.75, 6.1, -1.12 }, color = "glass" },
	{ name = "tubeL21", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -2.25, 5.1, -1.12 }, color = "glass" },
	{ name = "tubeL22", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -2.25, 5.6, -1.12 }, color = "glass" },
	{ name = "tubeL23", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -2.25, 6.1, -1.12 }, color = "glass" },
	{ name = "tubeL31", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -1.75, 5.1, -1.12 }, color = "glass" },
	{ name = "tubeL32", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -1.75, 5.6, -1.12 }, color = "glass" },
	{ name = "tubeL33", parent = "torso", shape = "cylinder", axis = "z", size = { 0.36, 0.36, 0.12 }, at = { -1.75, 6.1, -1.12 }, color = "glass" },
	{ name = "spikeL1", parent = "torso", shape = "wedge", size = { 0.3, 0.7, 0.5 }, at = { -2.25, 6.85, 0.4 }, color = "metal" },
} do
	table.insert(parts, p)
end

return require("./Scale").scaled({
	id = "chs_pandemonium",
	parts = parts,
	visualPieces = visual,
	attachments = {
		{ name = "muzzle", parent = "torso", at = { 2.25, 5.6, -1.3 } },
		{ name = "muzzle2", parent = "torso", at = { -2.25, 5.6, -1.3 } },
	},
}, 2)

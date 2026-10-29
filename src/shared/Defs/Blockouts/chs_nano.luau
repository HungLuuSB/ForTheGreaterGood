--!strict
-- Construction Turret (Chaos nano turret, T1, footprint 2; S-209, BAR
-- cornanotc): a dark slab, a squat octagonal tower with a hazard front and
-- salvaged crates stacked round its foot, and on top the `turret` (yaws to
-- its work): a boxy armored head carrying the `nano` emitter (the def's
-- piece): a heavy pod with a big glowing lens that reads from 150 studs;
-- `nano1` at the lens (rig.md 8). Chaos reads rugged (M-14). Model space,
-- forward = -Z.

local DECK = 6.2 -- top of the tower, where the turret turns

local parts: { any } = {
	{ name = "base", shape = "box", size = { 15.6, 0.9, 15.6 }, at = { 0, 0.45, 0 }, color = "dark" },
	{ name = "tower", parent = "base", shape = "box", size = { 6.8, DECK - 0.9, 6.8 }, at = { 0, 0.9 + (DECK - 0.9) / 2, 0 }, color = "hull" },
	{ name = "stripe", parent = "base", shape = "box", size = { 2.2, 3.6, 0.08 }, at = { 0, 2.9, -3.44 }, color = "dark" },
	{ name = "vent", parent = "base", shape = "box", size = { 1.4, 0.2, 0.08 }, at = { 0, 4.4, -3.46 }, color = "glass" },
}
for i, c in { { -4.6, -3.8 }, { 4.6, -3.8 }, { -5.2, 0.4 }, { 5.2, 0.4 }, { -4.2, 4.4 }, { 4.4, 4.6 }, { 0, 5.2 } } do
	table.insert(parts, { name = `crate{i}`, parent = "base", shape = "box", size = { 2.6, 2.3, 2.0 }, at = { c[1], 2.1, c[2] }, color = if i % 3 == 0 then "metal" else "team" })
end
for _, p in {
	{ name = "turret", parent = "base", shape = "box", size = { 4.0, 3.3, 3.8 }, at = { 0, 8.35, 0.7 }, pivot = { 0, DECK, 0 }, color = "hull" },
	{ name = "plateL", parent = "turret", shape = "box", size = { 0.3, 2.4, 3.0 }, at = { -2.1, 8.4, 0.9 }, color = "team" },
	{ name = "plateR", parent = "turret", shape = "box", size = { 0.3, 2.4, 3.0 }, at = { 2.1, 8.4, 0.9 }, color = "team" },
	{ name = "nano", parent = "turret", shape = "cylinder", axis = "z", size = { 3.4, 3.4, 2.1 }, at = { 0, 8.0, -2.0 }, pivot = { 0, 8.0, -0.9 }, color = "dark" },
	{ name = "lens", parent = "nano", shape = "cylinder", axis = "z", size = { 2.4, 2.4, 0.3 }, at = { 0, 8.0, -3.1 }, color = "glass" },
} do
	table.insert(parts, p)
end

return {
	id = "chs_nano",
	parts = parts,
	-- nanoframe anchor (M-25, rig.md 8)
	attachments = {
		{ name = "nano1", parent = "nano", at = { 0, 8.0, -3.25 } },
	},
}

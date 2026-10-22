--!strict
-- Shield generator (Order, T2 structure, proposed footprint 3; no def yet,
-- M-17): a stepped armored block with four capacitor pylons at its corners
-- and a raised deck carrying the shield `emitter` (the FX emitter device,
-- assets/fx/shield: hex plinth, three prongs leaning in round a glowing
-- core). The `core` attachment is where the shield's light beam starts
-- (docs/contracts/fx.md). Team plates on the lower ring. Order reads heavy
-- and fortress-like (M-14). Model space, forward = -Z.

local parts = {
	{ name = "base", shape = "box", size = { 21, 1.4, 21 }, at = { 0, 0.7, 0 }, color = "hull" },
	{ name = "wallF", parent = "base", shape = "wedge", size = { 21, 1.4, 1.5 }, at = { 0, 0.7, -11.25 }, color = "hull" },
	{ name = "wallB", parent = "base", shape = "wedge", size = { 21, 1.4, 1.5 }, at = { 0, 0.7, 11.25 }, rot = { 0, 180, 0 }, color = "hull" },
	{ name = "wallL", parent = "base", shape = "wedge", size = { 21, 1.4, 1.5 }, at = { -11.25, 0.7, 0 }, rot = { 0, 90, 0 }, color = "hull" },
	{ name = "wallR", parent = "base", shape = "wedge", size = { 21, 1.4, 1.5 }, at = { 11.25, 0.7, 0 }, rot = { 0, -90, 0 }, color = "hull" },
	{ name = "block", parent = "base", shape = "box", size = { 13, 2.2, 13 }, at = { 0, 2.5, 0 }, color = "hull" },
	{ name = "deck", parent = "base", shape = "cylinder", axis = "y", size = { 9, 1.2, 9 }, at = { 0, 4.2, 0 }, color = "dark" },
	{ name = "teamF", parent = "base", shape = "box", size = { 5, 0.1, 1.6 }, at = { 0, 1.45, -8.3 }, color = "team" },
	{ name = "teamB", parent = "base", shape = "box", size = { 5, 0.1, 1.6 }, at = { 0, 1.45, 8.3 }, color = "team" },
	{ name = "teamL", parent = "base", shape = "box", size = { 1.6, 0.1, 5 }, at = { -8.3, 1.45, 0 }, color = "team" },
	{ name = "teamR", parent = "base", shape = "box", size = { 1.6, 0.1, 5 }, at = { 8.3, 1.45, 0 }, color = "team" },

	-- the emitter: hex plinth, collar, glowing core, three prongs leaning in
	{ name = "emitter", parent = "base", shape = "cylinder", axis = "y", size = { 6, 1.1, 6 }, at = { 0, 5.35, 0 }, color = "hull" },
	{ name = "collar", parent = "emitter", shape = "cylinder", axis = "y", size = { 4.3, 1.0, 4.3 }, at = { 0, 6.4, 0 }, color = "dark" },
	{ name = "coreGlow", parent = "emitter", shape = "cylinder", axis = "y", size = { 1.6, 3.2, 1.6 }, at = { 0, 8.5, 0 }, color = "glass" },
}
-- capacitor pylons at the corners: posts with glowing bands and caps
for i, c in { { -8, -8 }, { 8, -8 }, { -8, 8 }, { 8, 8 } } do
	table.insert(parts, { name = `pylon{i}`, parent = "base", shape = "cylinder", axis = "y", size = { 1.6, 4.4, 1.6 }, at = { c[1], 3.6, c[2] }, color = "metal" })
	table.insert(parts, { name = `pylonBand{i}`, parent = "base", shape = "cylinder", axis = "y", size = { 1.8, 0.3, 1.8 }, at = { c[1], 4.6, c[2] }, color = "glass" })
	table.insert(parts, { name = `pylonCap{i}`, parent = "base", shape = "box", size = { 2.0, 0.4, 2.0 }, at = { c[1], 6.0, c[2] }, color = "dark" })
end
for i = 1, 3 do
	local a = math.pi / 2 + (i - 1) * 2 * math.pi / 3
	local ox, oz = math.cos(a), math.sin(a)
	-- prong from the collar's rim up to beside the core's top, leaning in 16°
	table.insert(parts, {
		name = `prong{i}`, parent = "emitter", shape = "box", size = { 1.5, 6.0, 1.0 },
		at = { ox * 2.6, 8.4, oz * 2.6 },
		rot = { -16, 90 - math.deg(a), 0 },
		color = "hull",
	})
	table.insert(parts, { name = `prongTip{i}`, parent = "emitter", shape = "box", size = { 1.0, 0.6, 1.2 }, at = { ox * 2.0, 11.6, oz * 2.0 }, color = "dark" })
end

return {
	id = "ord_shieldgen",
	parts = parts,
	attachments = {
		{ name = "core", parent = "emitter", at = { 0, 10.1, 0 } },
	},
}

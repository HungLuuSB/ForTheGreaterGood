--!strict
-- Style-review variants (docs/art/style-guide.md, M-6): candidate blockouts
-- for one unit def each, with the palette proposed for their faction. Not in
-- Blockouts/Registry, so the game keeps the registered blockout; a variant
-- replaces it only once its direction is approved. Each is a valid Blockout
-- for its def (Blockout.validate).

-- RGB 0..255 per palette key, same keys as Blockout.PALETTES.
local PALETTES = {
	-- Order: light grey or sand base, darker grey details, dark tinted glass
	orderGrey = {
		hull = { 166, 170, 162 },
		dark = { 92, 96, 92 },
		track = { 44, 45, 43 },
		metal = { 120, 124, 118 },
		glass = { 34, 48, 60 },
		team = { 210, 210, 210 },
	},
	orderSand = {
		hull = { 186, 170, 132 },
		dark = { 110, 100, 80 },
		track = { 48, 46, 42 },
		metal = { 138, 130, 110 },
		glass = { 36, 46, 52 },
		team = { 210, 210, 210 },
	},
	-- Chaos: dark olive or gunmetal base, near-black tiles and cages
	chaosOlive = {
		hull = { 80, 86, 60 },
		dark = { 50, 54, 40 },
		track = { 36, 36, 32 },
		metal = { 90, 94, 82 },
		glass = { 40, 52, 48 },
		team = { 210, 210, 210 },
	},
	chaosGunmetal = {
		hull = { 76, 80, 84 },
		dark = { 46, 48, 52 },
		track = { 34, 34, 34 },
		metal = { 98, 102, 106 },
		glass = { 44, 58, 62 },
		team = { 210, 210, 210 },
	},
}

export type Variant = {
	key: string,
	label: string,
	blockout: any,
	palette: { [string]: { number } },
}

local VARIANTS: { Variant } = {
	{ key = "ord_lancer_a", label = "Lancer A (Leopard 2 lines, grey)", blockout = require("./ord_lancer_a"), palette = PALETTES.orderGrey },
	{ key = "ord_lancer_b", label = "Lancer B (Abrams lines, sand)", blockout = require("./ord_lancer_b"), palette = PALETTES.orderSand },
	{ key = "chs_ravager_a", label = "Ravager A (T-90M lines, olive)", blockout = require("./chs_ravager_a"), palette = PALETTES.chaosOlive },
	{ key = "chs_ravager_b", label = "Ravager B (T-14 lines, gunmetal)", blockout = require("./chs_ravager_b"), palette = PALETTES.chaosGunmetal },
}

return {
	PALETTES = PALETTES,
	VARIANTS = VARIANTS,
}

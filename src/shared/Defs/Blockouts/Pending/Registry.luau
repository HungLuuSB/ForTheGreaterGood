--!strict
-- Blockouts for units that have no def yet (docs/design/factions.md, M-17):
-- each comes with the def fields it was built for (`defs`, a proposal for the
-- sim session) and, for units that change shape, review poses (`poses`:
-- piece -> { rx, ry, rz } degrees for Motor6D.Transform). Not in
-- Blockouts/Registry: once a def exists with these pieces, the blockout moves
-- up to Blockouts/ and is registered there.

return {
	blockouts = {
		chs_cyclops = require("./chs_cyclops"),
		chs_locust = require("./chs_locust"),
		chs_minotaur = require("./chs_minotaur"),
		ord_barrier = require("./ord_barrier"),
		ord_citadel = require("./ord_citadel"),
		ord_warden = require("./ord_warden"),
	},
	defs = {
		ord_warden = { id = "ord_warden", model = "ord_warden", faction = "order", tier = 2, domain = "ground", footprint = 2, pieces = { "base", "turret", "barrel", "muzzle" } },
		chs_minotaur = { id = "chs_minotaur", model = "chs_minotaur", faction = "chaos", tier = 2, domain = "ground", footprint = 2, pieces = { "base", "turret", "barrel", "muzzle" } },
		chs_locust = { id = "chs_locust", model = "chs_locust", faction = "chaos", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "turret", "barrel", "muzzle" } },
		chs_cyclops = { id = "chs_cyclops", model = "chs_cyclops", faction = "chaos", tier = 2, domain = "ground", footprint = 2, pieces = { "base", "turret", "barrel", "muzzle" } },
		ord_barrier = { id = "ord_barrier", model = "ord_barrier", faction = "order", tier = 1, domain = "structure", footprint = 1, pieces = { "base" } },
		ord_citadel = { id = "ord_citadel", model = "ord_citadel", faction = "order", tier = 3, domain = "structure", footprint = 3, pieces = { "base", "turret", "barrel", "muzzle", "launcher", "muzzle2", "radar" } },
	},
	poses = {
		ord_warden = {
			packed = {},
			deployed = { spadeL = { 100, 0, 0 }, spadeR = { 100, 0, 0 }, shield = { -80, 0, 0 } },
		},
	},
}

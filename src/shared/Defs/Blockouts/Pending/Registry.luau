--!strict
-- Review poses for units that change shape (docs/decisions/models.md M-17):
-- poses.<id>.<pose> = { piece = { rx, ry, rz, dx?, dy?, dz? } }, degrees and
-- studs, as Motor6D.Transform = CFrame.Angles(rx, ry, rz) * CFrame.new(dx, dy, dz)
-- (rig.md 2). `base` moves the whole model. The client's piece scripts own
-- the real animation; these are what the review lineups show.
-- `blockouts` holds blockouts for units without a def yet, `defs` the def
-- fields each was built for (a proposal for the sim session, M-17).

return {
	blockouts = {
		chs_basilisk = require("./chs_basilisk"),
		ord_lucent = require("./ord_lucent"),
	},
	-- beam towers (client request 2, sim request 43): proposed IDs and pieces
	defs = {
		ord_lucent = { id = "ord_lucent", model = "ord_lucent", faction = "order", tier = 2, domain = "structure", footprint = 2, pieces = { "base", "turret", "barrel", "muzzle" } },
		chs_basilisk = { id = "chs_basilisk", model = "chs_basilisk", faction = "chaos", tier = 2, domain = "structure", footprint = 2, pieces = { "base", "turret", "barrel", "muzzle" } },
	},
	poses = {
		-- switched off: the turret sinks into the drum, the emitter folds down, the shells close
		ord_lucent = {
			retracted = {
				turret = { 0, 0, 0, 0, -7.6, 0 },
				barrel = { -90, 0, 0 },
				shellL = { 0, 0, -90 },
				shellR = { 0, 0, 90 },
			},
		},
		chs_basilisk = {
			retracted = {
				turret = { 0, 0, 0, 0, -7.4, 0 },
				barrel = { -90, 0, 0 },
				shellL = { 0, 0, -90 },
				shellR = { 0, 0, 90 },
			},
		},
		ord_warden = {
			packed = {},
			deployed = {
				base = { 0, 0, 0, 0, -0.4, 0 },
				spades = { 100, 0, 0 },
				jacks = { 0, 0, 0, 0, -0.5, 0 },
				shieldL = { 0, 90, 0 },
				shieldR = { 0, -90, 0 },
				barrel = { 12, 0, 0 },
			},
		},
	},
}

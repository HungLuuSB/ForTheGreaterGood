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
		chs_cerberus = require("./chs_cerberus"),
		chs_chimera = require("./chs_chimera"),
		ord_custodian = require("./ord_custodian"),
		ord_providence = require("./ord_providence"),
	},
	-- anti-nukes (the user's request 2026-10-23): proposed IDs and pieces for the sim
	defs = {
		ord_providence = { id = "ord_providence", model = "ord_providence", faction = "order", tier = 2, domain = "structure", footprint = 3, pieces = { "base", "hatch", "muzzle" } },
		chs_cerberus = { id = "chs_cerberus", model = "chs_cerberus", faction = "chaos", tier = 2, domain = "structure", footprint = 3, pieces = { "base", "launcher", "muzzle" } },
		-- mobile anti-nukes (the user's request 2026-10-23): proposed IDs and pieces
		ord_custodian = { id = "ord_custodian", model = "ord_custodian", faction = "order", tier = 2, domain = "ground", footprint = 1, pieces = { "base", "launcher", "muzzle" } },
		chs_chimera = { id = "chs_chimera", model = "chs_chimera", faction = "chaos", tier = 2, domain = "ground", footprint = 1, pieces = { "base", "launcher", "muzzle" } },
	},
	poses = {
		-- anti-nukes: ready to launch
		ord_providence = {
			open = { hatch = { 100, 0, 0 } },
		},
		chs_cerberus = {
			raised = { launcher = { 75, 0, 0 } },
		},
		ord_custodian = {
			raised = { launcher = { 80, 0, 0 } },
		},
		chs_chimera = {
			raised = { launcher = { 75, 0, 0 } },
		},
		-- switched off (beam towers, S-96): the turret sinks into the drum, the
		-- emitter folds down, the lids close over the pit
		ord_radiance = {
			retracted = {
				turret = { 0, 0, 0, 0, -11.4, 0 }, -- x1.5 with the fp 3 blockout (S-104)
				barrel = { -90, 0, 0 },
				shellL = { 0, 0, -90 },
				shellR = { 0, 0, 90 },
			},
		},
		chs_inferno = {
			retracted = {
				turret = { 0, 0, 0, 0, -11.1, 0 }, -- x1.5 with the fp 3 blockout (S-104)
				barrel = { -90, 0, 0 },
				shellL = { 0, 0, -90 },
				shellR = { 0, 0, 90 },
			},
		},
		-- the Commander mechs mid-stride (M-31): left leg forward, right leg
		-- back, the arms swinging against them, the torso turned a little
		ord_sovereign = {
			stride = {
				base = { 0, 0, 0, 0, -0.12, 0 },
				torso = { 0, -6, 0 },
				thighL = { 28, 0, 0 },
				shinL = { -18, 0, 0 },
				footL = { -10, 0, 0 },
				thighR = { -22, 0, 0 },
				shinR = { -30, 0, 0 },
				footR = { 20, 0, 0 },
				armL = { -18, 0, 0 },
				armR = { 15, 0, 0 },
			},
		},
		chs_warlord = {
			stride = {
				base = { 0, 0, 0, 0, -0.12, 0 },
				torso = { 0, 6, 0 },
				thighL = { 26, 0, 0 },
				shinL = { -16, 0, 0 },
				footL = { -10, 0, 0 },
				thighR = { -20, 0, 0 },
				shinR = { -28, 0, 0 },
				footR = { 18, 0, 0 },
				armL = { -14, 0, 0 },
				armR = { 12, 0, 0 },
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

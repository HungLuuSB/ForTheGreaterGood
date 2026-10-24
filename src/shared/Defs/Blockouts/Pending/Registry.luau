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
		chs_rookery = require("./chs_rookery"),
		chs_scylla = require("./chs_scylla"),
		ord_empyrean = require("./ord_empyrean"),
		ord_pharos = require("./ord_pharos"),
	},
	-- sim-A's request 2026-10-24 (IDs fixed by the sim; the defs land with its next merge)
	defs = {
		ord_pharos = { id = "ord_pharos", model = "ord_pharos", faction = "order", tier = 2, domain = "structure", footprint = 3, pieces = { "base", "launcher", "muzzle" } },
		chs_scylla = { id = "chs_scylla", model = "chs_scylla", faction = "chaos", tier = 2, domain = "structure", footprint = 3, pieces = { "base", "launcher", "muzzle" } },
		ord_empyrean = { id = "ord_empyrean", model = "ord_empyrean", faction = "order", tier = 2, domain = "structure", footprint = 4, pieces = { "base" } },
		chs_rookery = { id = "chs_rookery", model = "chs_rookery", faction = "chaos", tier = 2, domain = "structure", footprint = 4, pieces = { "base" } },
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
		-- the laser towers aiming up (S-157: pitch -60..+60 degrees)
		ord_sentry_tower = { aimed = { barrel = { 35, 0, 0 } } },
		chs_guard = { aimed = { barrel = { 35, 0, 0 } } },
		ord_overwatch = { aimed = { mount = { 35, 0, 0 } } },
		chs_twin_guard = { aimed = { mount = { 35, 0, 0 } } },
		chs_geryon = { aimed = { mount = { 35, 0, 0 } } },
		-- the lobbing guns at high trajectory (S-157: the barrel pitches up to 85 degrees)
		ord_gauntlet = {
			raised = { barrel = { 70, 0, 0 } },
		},
		chs_talos = {
			raised = { barrel = { 70, 0, 0 } },
		},
		chs_bulwark = { -- S-157, Inferno's replacement: the beam head sinks onto its armored collar, the barrel folds down
			aimed = { barrel = { 25, 0, 0 }, laser_mount = { 35, 0, 0 } },
			retracted = {
				turret = { 0, 0, 0, 0, -2.0, 0 },
				barrel = { -35, 0, 0 },
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
		-- the Commander mechs mid-stride (M-31, the heroic redesign M-32): left leg forward, right leg
		-- back, the arms swinging against them, the torso turned a little
		ord_sovereign = {
			stride = {
				base = { 0, 0, 0, 0, -0.2, 0 },
				torso = { 0, -6, 0 },
				thighL = { 24, 0, 0 },
				shinL = { -8, 0, 0 },
				footL = { -16, 0, 0 },
				thighR = { -18, 0, 0 },
				shinR = { -22, 0, 0 },
				footR = { 30, 0, 0 },
				armL = { -16, 0, 0 },
				armR = { 14, 0, 0 },
			},
		},
		chs_warlord = {
			stride = {
				base = { 0, 0, 0, 0, -0.25, 0 },
				torso = { 0, 7, 0 },
				thighL = { 22, 0, 0 },
				shinL = { -6, 0, 0 },
				footL = { -16, 0, 0 },
				thighR = { -16, 0, 0 },
				shinR = { -20, 0, 0 },
				footR = { 28, 0, 0 },
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

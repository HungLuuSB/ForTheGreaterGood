--!strict
-- Review poses for units that change shape (docs/decisions/models.md M-17):
-- poses.<id>.<pose> = { piece = { rx, ry, rz, dx?, dy?, dz? } }, degrees and
-- studs, as Motor6D.Transform = CFrame.Angles(rx, ry, rz) * CFrame.new(dx, dy, dz)
-- (rig.md 2). `base` moves the whole model. The client's piece scripts own
-- the real animation; these are what the review lineups show.
-- `blockouts` holds blockouts for units without a def yet, `defs` the def
-- fields each was built for (a proposal for the sim session, M-17).

return {
	blockouts = {},
	defs = {},
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
		chs_bulwark = { -- S-157, Inferno's replacement: the beam turret sinks into the pit, the lids close
			retracted = {
				turret = { 0, 0, 0, 0, -10.5, 0 },
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

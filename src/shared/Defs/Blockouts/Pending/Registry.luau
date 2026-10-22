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
		-- switched off (beam towers, S-96): the turret sinks into the drum, the
		-- emitter folds down, the lids close over the pit
		ord_radiance = {
			retracted = {
				turret = { 0, 0, 0, 0, -7.6, 0 },
				barrel = { -90, 0, 0 },
				shellL = { 0, 0, -90 },
				shellR = { 0, 0, 90 },
			},
		},
		chs_inferno = {
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

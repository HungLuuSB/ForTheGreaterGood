--!strict
-- Review poses for units that change shape (docs/decisions/models.md M-17):
-- poses.<id>.<pose> = { piece = { rx, ry, rz, dx?, dy?, dz? } }, degrees and
-- studs, as Motor6D.Transform = CFrame.Angles(rx, ry, rz) * CFrame.new(dx, dy, dz)
-- (rig.md 2). `base` moves the whole model. The client's piece scripts own
-- the real animation; these are what the review lineups show.
-- (`blockouts` and `defs` held blockouts waiting for a def; empty now.)

return {
	blockouts = {},
	defs = {},
	poses = {
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

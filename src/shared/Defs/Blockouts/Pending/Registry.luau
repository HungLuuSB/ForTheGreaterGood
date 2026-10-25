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
		-- S-181 (the playtest's new units, defs on m-sim-2 2b3ca0e): move up and register once they're in main
		ord_botlab = require("./ord_botlab"),
		chs_botlab = require("./chs_botlab"),
		ord_advbotlab = require("./ord_advbotlab"),
		chs_advbotlab = require("./chs_advbotlab"),
		ord_artisan = require("./ord_artisan"),
		chs_tinker = require("./chs_tinker"),
		ord_lazarus = require("./ord_lazarus"),
		chs_graverobber = require("./chs_graverobber"),
		ord_glint = require("./ord_glint"),
		chs_skitter = require("./chs_skitter"),
		ord_mace = require("./ord_mace"),
		chs_thug = require("./chs_thug"),
		ord_kestrel = require("./ord_kestrel"),
		chs_needle = require("./chs_needle"),
		ord_fatboy = require("./ord_fatboy"),
		chs_tzar = require("./chs_tzar"),
		chs_centurion = require("./chs_centurion"),
		chs_dragon = require("./chs_dragon"),
		ord_liche = require("./ord_liche"),
	},
	defs = {
		ord_botlab = { id = "ord_botlab", model = "ord_botlab", faction = "order", tier = 1, domain = "structure", footprint = 4, pieces = { "base" } },
		chs_botlab = { id = "chs_botlab", model = "chs_botlab", faction = "chaos", tier = 1, domain = "structure", footprint = 4, pieces = { "base" } },
		ord_advbotlab = { id = "ord_advbotlab", model = "ord_advbotlab", faction = "order", tier = 2, domain = "structure", footprint = 5, pieces = { "base" } },
		chs_advbotlab = { id = "chs_advbotlab", model = "chs_advbotlab", faction = "chaos", tier = 2, domain = "structure", footprint = 5, pieces = { "base" } },
		ord_artisan = { id = "ord_artisan", model = "ord_artisan", faction = "order", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "nano" }, moveClass = "WALKER" },
		chs_tinker = { id = "chs_tinker", model = "chs_tinker", faction = "chaos", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "nano" }, moveClass = "WALKER" },
		ord_lazarus = { id = "ord_lazarus", model = "ord_lazarus", faction = "order", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "nano" }, moveClass = "WALKER" },
		chs_graverobber = { id = "chs_graverobber", model = "chs_graverobber", faction = "chaos", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "nano" }, moveClass = "WALKER" },
		ord_glint = { id = "ord_glint", model = "ord_glint", faction = "order", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "torso", "arm_l", "arm_r" }, moveClass = "WALKER" },
		chs_skitter = { id = "chs_skitter", model = "chs_skitter", faction = "chaos", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "torso", "muzzle" }, moveClass = "WALKER" },
		ord_mace = { id = "ord_mace", model = "ord_mace", faction = "order", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "torso", "muzzle" }, moveClass = "WALKER" },
		chs_thug = { id = "chs_thug", model = "chs_thug", faction = "chaos", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "torso", "muzzle" }, moveClass = "WALKER" },
		ord_kestrel = { id = "ord_kestrel", model = "ord_kestrel", faction = "order", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "torso", "launcher", "muzzle" }, moveClass = "WALKER" },
		chs_needle = { id = "chs_needle", model = "chs_needle", faction = "chaos", tier = 1, domain = "ground", footprint = 1, pieces = { "base", "torso", "launcher", "muzzle" }, moveClass = "WALKER" },
		ord_fatboy = { id = "ord_fatboy", model = "ord_fatboy", faction = "order", tier = 2, domain = "ground", footprint = 2, pieces = { "base", "cannon", "muzzle" }, moveClass = "WALKER" },
		chs_tzar = { id = "chs_tzar", model = "chs_tzar", faction = "chaos", tier = 2, domain = "ground", footprint = 2, pieces = { "base", "turret", "muzzle" }, moveClass = "HEAVY_TRACKED" },
		chs_centurion = { id = "chs_centurion", model = "chs_centurion", faction = "chaos", tier = 2, domain = "ground", footprint = 2, pieces = { "base", "torso", "muzzle" }, moveClass = "WALKER" },
		chs_dragon = { id = "chs_dragon", model = "chs_dragon", faction = "chaos", tier = 2, domain = "air", footprint = 3, pieces = { "base", "belly", "flame", "laser_l", "laser_l_muzzle", "laser_r", "laser_r_muzzle" }, moveClass = "HELI" },
		ord_liche = { id = "ord_liche", model = "ord_liche", faction = "order", tier = 2, domain = "air", footprint = 2, pieces = { "base", "bay", "muzzle" }, moveClass = "JET" },
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

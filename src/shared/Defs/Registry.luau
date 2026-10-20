--!strict
-- Every def module, keyed by file name. Neither runtime can list a folder
-- portably (Roblox has Instances, Lune has the file system), so new defs are
-- registered here by hand. Defs.load() checks each key against the def's id.

return {
	units = {
		chs_ravager = require("./Units/chs_ravager"),
		ord_lancer = require("./Units/ord_lancer"),
	},
	weapons = {
		chs_light_cannon = require("./Weapons/chs_light_cannon"),
		ord_light_cannon = require("./Weapons/ord_light_cannon"),
	},
}

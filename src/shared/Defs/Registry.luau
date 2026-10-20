--!strict
-- Every def module, keyed by file name. Neither runtime can list a folder
-- portably (Roblox has Instances, Lune has the file system), so new defs are
-- registered here by hand. Defs.load() checks each key against the def's id.

return {
	units = {
		chs_extractor = require("./Units/chs_extractor"),
		chs_hellmouth = require("./Units/chs_hellmouth"),
		chs_generator = require("./Units/chs_generator"),
		chs_ravager = require("./Units/chs_ravager"),
		chs_scrapper = require("./Units/chs_scrapper"),
		chs_shroud = require("./Units/chs_shroud"),
		chs_vehplant = require("./Units/chs_vehplant"),
		chs_warlord = require("./Units/chs_warlord"),
		chs_watcher = require("./Units/chs_watcher"),
		ord_extractor = require("./Units/ord_extractor"),
		ord_generator = require("./Units/ord_generator"),
		ord_lancer = require("./Units/ord_lancer"),
		ord_mason = require("./Units/ord_mason"),
		ord_oracle = require("./Units/ord_oracle"),
		ord_sovereign = require("./Units/ord_sovereign"),
		ord_vehplant = require("./Units/ord_vehplant"),
		ord_veil = require("./Units/ord_veil"),
		ord_verdict = require("./Units/ord_verdict"),
	},
	weapons = {
		chs_light_cannon = require("./Weapons/chs_light_cannon"),
		chs_mortar = require("./Weapons/chs_mortar"),
		ord_howitzer = require("./Weapons/ord_howitzer"),
		ord_light_cannon = require("./Weapons/ord_light_cannon"),
	},
}

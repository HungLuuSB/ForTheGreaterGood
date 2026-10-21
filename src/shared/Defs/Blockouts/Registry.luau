--!strict
-- Hand-made blockouts by unit def ID (C-6). Units not listed here get a
-- generic blockout (Blockout.generic). Register new files by hand: neither
-- runtime can list a folder portably.

return {
	chs_hellmouth = require("./chs_hellmouth"),
	chs_hornet = require("./chs_hornet"),
	chs_jackal = require("./chs_jackal"),
	chs_juggernaut = require("./chs_juggernaut"),
	chs_ravager = require("./chs_ravager"),
	chs_scrapper = require("./chs_scrapper"),
	chs_watcher = require("./chs_watcher"),
	ord_halo = require("./ord_halo"),
	ord_herald = require("./ord_herald"),
	ord_lancer = require("./ord_lancer"),
	ord_mason = require("./ord_mason"),
	ord_oracle = require("./ord_oracle"),
	ord_verdict = require("./ord_verdict"),
}

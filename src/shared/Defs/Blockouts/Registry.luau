--!strict
-- Hand-made blockouts by unit def ID (C-6). Units not listed here get a
-- generic blockout (Blockout.generic). Register new files by hand: neither
-- runtime can list a folder portably.

return {
	chs_juggernaut = require("./chs_juggernaut"),
	chs_ravager = require("./chs_ravager"),
	ord_lancer = require("./ord_lancer"),
}

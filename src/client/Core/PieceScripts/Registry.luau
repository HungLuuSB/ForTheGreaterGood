--!strict
-- Piece scripts by unit def ID (C-30); every other unit runs Default.
-- Register new files by hand (neither runtime can list a folder portably).

local Default = require("./Default")
local BeamTower = require("./BeamTower")
local Commander = require("./Commander")

local Registry = {}

Registry.SCRIPTS = table.freeze({
	chs_juggernaut = require("./chs_juggernaut"),
	ord_warden = require("./ord_warden"),
	chs_minotaur = require("./chs_minotaur"),
	ord_radiance = BeamTower,
	chs_inferno = BeamTower,
	ord_sovereign = Commander, -- walking mechs (M-31, C-146)
	chs_warlord = Commander,
}) :: { [string]: any }

function Registry.forDef(def: any): any
	return Registry.SCRIPTS[def.id] or Default
end

return Registry

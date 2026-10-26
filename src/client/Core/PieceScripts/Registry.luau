--!strict
-- Piece scripts by unit def ID (C-30); every other unit runs Default.
-- Register new files by hand (neither runtime can list a folder portably).

local Default = require("./Default")
local BeamTower = require("./BeamTower")
local Commander = require("./Commander")
local Bot = require("./Bot")

local Registry = {}

Registry.SCRIPTS = table.freeze({
	chs_juggernaut = require("./chs_juggernaut"),
	ord_warden = require("./ord_warden"),
	chs_minotaur = require("./chs_minotaur"),
	ord_radiance = BeamTower,
	chs_inferno = BeamTower,
	ord_sovereign = Commander, -- walking mechs (M-31, C-146)
	chs_warlord = Commander,
	-- the walking bots (S-181): the Commander's stride without the torso twist
	ord_artisan = Bot,
	chs_tinker = Bot,
	ord_lazarus = Bot,
	chs_graverobber = Bot,
	ord_glint = Bot,
	ord_mace = Bot,
	chs_thug = Bot,
	ord_kestrel = Bot,
	chs_needle = Bot,
	ord_fatboy = Bot,
	chs_centurion = Bot,
	chs_skitter = Bot, -- four legs: a diagonal gait
	chs_dragon = Bot.Dragon, -- its ducted fans
}) :: { [string]: any }

function Registry.forDef(def: any): any
	return Registry.SCRIPTS[def.id] or Default
end

return Registry

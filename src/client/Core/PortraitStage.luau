--!strict
-- What a unit portrait stands the unit on (C-192, the user: "unit should be
-- rendered with its accessible terrain, ... apply to all portraits"): a
-- patch of ground for land units and structures, water for ships and water
-- structures, a shore (half ground, half water) for amphibious and hover
-- units, and ground far below for aircraft. Pure Luau; UI/Portrait builds it.

local MoveClasses = require("@shared/Defs/MoveClasses")

local PortraitStage = {}

export type Kind = "ground" | "water" | "shore" | "air"

function PortraitStage.kind(def: any): Kind
	local mc = def.moveClass and (MoveClasses :: any)[def.moveClass]
	local surface = mc and mc.surface
	if def.domain == "air" or surface == "air" then
		return "air"
	elseif def.domain == "naval" or surface == "water" or def.placement == "water" then
		return "water"
	elseif surface == "amphib" or surface == "hover" then
		return "shore"
	end
	return "ground"
end

-- Where the water surface sits on a floating model, as a fraction of its
-- height up from its lowest point (a ship's hull sits a little in the water).
PortraitStage.WATERLINE = 0.18
-- How far below an aircraft the ground is, in its own heights.
PortraitStage.AIR_GAP = 1.2

return PortraitStage

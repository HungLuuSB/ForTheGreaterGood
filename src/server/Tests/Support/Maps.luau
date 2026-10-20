--!strict
-- Test map builders shared by the pathing and movement specs.

local Passability = require("@shared/Grid/Passability")
local TestMap = require("@shared/Grid/TestMap")
local FlowField = require("../../Sim/Path/FlowField")
local Quadtree = require("../../Sim/Path/Quadtree")
local Route = require("../../Sim/Path/Route")

local Maps = {}

-- Flat land at height 10; `water(cx, cz)` > 0 floods a cell (blocks land units).
function Maps.flatWith(cellsX: number, cellsZ: number, water: ((number, number) -> number)?): Passability.PassMap
	return Passability.build(TestMap.build(cellsX, cellsZ, function(cx, cz)
		return 10, if water then water(cx, cz) else 0
	end))
end

-- cellsX × cellsZ map with water walls forming a zig-zag maze: a wall every
-- `spacing` columns, alternately open at the top and the bottom.
function Maps.maze(cellsX: number, cellsZ: number, spacing: number): Passability.PassMap
	return Maps.flatWith(cellsX, cellsZ, function(cx, cz)
		if cx % spacing ~= spacing // 2 or cx < spacing // 2 then
			return 0
		end
		local wall = cx // spacing
		local openTop = wall % 2 == 0
		local gap = math.max(2, cellsZ // 8)
		if openTop and cz < gap then
			return 0
		elseif not openTop and cz >= cellsZ - gap then
			return 0
		end
		return 10
	end)
end

-- Builds the tree, route, corridor and one-shot field from start to goal.
function Maps.field(
	pm: Passability.PassMap,
	moveClass: string,
	footprint: number,
	startCell: number,
	goalCell: number,
	keepCost: boolean?
): (FlowField.Field, Quadtree.Tree, Route.Corridor)
	local tree = Quadtree.build(pm, moveClass, Passability.requiredClearance(footprint))
	local route, failure = Route.find(tree, startCell, goalCell)
	if route == nil then
		error(`Maps.field: no route ({failure})`, 2)
	end
	local corridor = Route.corridor(tree, route)
	return FlowField.build(tree, corridor, goalCell, keepCost), tree, corridor
end

return Maps

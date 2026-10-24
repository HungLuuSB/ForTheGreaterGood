--!strict
-- Terrain types and their speed modifiers (guide 5.2 `terrainType`, 6.3,
-- 12.1 "heavies are slow on sand"; S-37). Shared: the server moves and
-- paths with it, the client can draw the types and predict speeds.
--
-- A unit's top speed is its maxSpeed × SPEED[moveClass][type] of the cell it
-- is on. Flow fields cost a step (best factor of the class on the map) /
-- (factor of the cells), so paths prefer good ground; the cost is never below 1, which
-- the flow field's bucket queue needs. Classes without a row (ships,
-- submarines, aircraft) ignore terrain.

local Layers = require("./Layers")

local Terrain = {}

Terrain.Type = Layers.Terrain

local GRASS, ROCK, SAND, ROAD = Layers.Terrain.GRASS, Layers.Terrain.ROCK, Layers.Terrain.SAND, Layers.Terrain.ROAD

-- Placeholder numbers (M8 balance): speed factors per move class, by type.
Terrain.SPEED = table.freeze({
	WHEELED = table.freeze({ [GRASS] = 1, [ROCK] = 0.8, [SAND] = 0.7, [ROAD] = 1.25 }),
	TRACKED = table.freeze({ [GRASS] = 1, [ROCK] = 0.9, [SAND] = 0.8, [ROAD] = 1.1 }),
	HEAVY_TRACKED = table.freeze({ [GRASS] = 1, [ROCK] = 0.9, [SAND] = 0.6, [ROAD] = 1.1 }),
	AMPHIB = table.freeze({ [GRASS] = 1, [ROCK] = 0.9, [SAND] = 0.85, [ROAD] = 1.1 }),
	HOVER = table.freeze({ [GRASS] = 1, [ROCK] = 0.8, [SAND] = 1, [ROAD] = 1.1 }),
	WALKER = table.freeze({ [GRASS] = 1, [ROCK] = 0.95, [SAND] = 0.85, [ROAD] = 1.05 }), -- legs mind the ground less (S-159)
} :: { [string]: { [number]: number } })

-- The speed factor of `moveClass` on cell `index` (1 for classes and cells
-- without one).
function Terrain.factor(layers: Layers.Layers, moveClass: string, index: number): number
	local row = Terrain.SPEED[moveClass]
	if row == nil then
		return 1
	end
	return row[Layers.getTerrain(layers, index)] or 1
end

-- Flow-field step-cost multipliers of `moveClass` on `layers` (f32 per cell,
-- each >= 1: the best factor on this map / the cell's), or nil when terrain
-- changes nothing for it here.
function Terrain.stepCosts(layers: Layers.Layers, moveClass: string): buffer?
	local row = Terrain.SPEED[moveClass]
	if row == nil then
		return nil
	end
	local n = layers.grid.cellCount
	-- relative to the best type on this map, so an all-grass map costs 1
	local best, worst = 0, math.huge
	for i = 0, n - 1 do
		local f = row[Layers.getTerrain(layers, i)] or 1
		best, worst = math.max(best, f), math.min(worst, f)
	end
	if best == worst then
		return nil
	end
	local out = buffer.create(n * 4)
	for i = 0, n - 1 do
		buffer.writef32(out, i * 4, best / (row[Layers.getTerrain(layers, i)] or 1))
	end
	return out
end

return Terrain

--!strict
-- The drawn ground of a map (C-28): one smooth surface for the 3D terrain
-- and for everything that stands on it (units, rings, bars, effects).
-- Heights are per cell on the wire and in the sim (guide 5.2); drawn, they
-- are bilinear between cell centers, so flat ground stays exact (start
-- plateaus, deposits) and a step between cells becomes a slope 8 studs
-- wide instead of a wall. Water is flat: a water cell's surface is its
-- height plus its depth. Pure Luau (C-7); Render/Terrain draws it.

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")

local Terrain = {}

local CELL = Grid.CELL_SIZE

Terrain.DEPOSIT_LIFT = 0.35 -- studs: deposit plates float this far over the cell's height (deposits on gentle slopes)

local function heightAt(layers: Layers.Layers, cx: number, cz: number): number
	local g = layers.grid
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	return Layers.getHeight(layers, cz * g.cellsX + cx)
end

-- Smooth ground height at (x, z): bilinear between the four nearest cell
-- centers (clamped at the map edge).
function Terrain.groundY(layers: Layers.Layers, x: number, z: number): number
	local g = layers.grid
	local fx = (x - g.originX) / CELL - 0.5
	local fz = (z - g.originZ) / CELL - 0.5
	local cx, cz = math.floor(fx), math.floor(fz)
	local tx, tz = fx - cx, fz - cz
	local h00, h10 = heightAt(layers, cx, cz), heightAt(layers, cx + 1, cz)
	local h01, h11 = heightAt(layers, cx, cz + 1), heightAt(layers, cx + 1, cz + 1)
	local a = h00 + (h10 - h00) * tx
	local b = h01 + (h11 - h01) * tx
	return a + (b - a) * tz
end

-- Water surface at (x, z), or nil on dry land (the cell's own value).
function Terrain.waterY(layers: Layers.Layers, x: number, z: number): number?
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	local i = cz * g.cellsX + cx
	local w = Layers.getWater(layers, i)
	if w <= 0 then
		return nil
	end
	return Layers.getHeight(layers, i) + w
end

-- What floating units and the camera stand on: the water surface where
-- there is water, else the ground.
function Terrain.surfaceY(layers: Layers.Layers, x: number, z: number): number
	local ground = Terrain.groundY(layers, x, z)
	local water = Terrain.waterY(layers, x, z)
	return if water and water > ground then water else ground
end

-- Ground kind at (x, z): the sim's terrain type of the cell (Layers.terrain,
-- guide 5.2, S-37), so ground drawn as sand or road is where units slow
-- down or speed up (C-66; the client's own slope and shore rules are gone).
export type Kind = "grass" | "rock" | "sand" | "road"
local KIND: { [number]: Kind } = {
	[Layers.Terrain.GRASS] = "grass",
	[Layers.Terrain.ROCK] = "rock",
	[Layers.Terrain.SAND] = "sand",
	[Layers.Terrain.ROAD] = "road",
}
function Terrain.kind(layers: Layers.Layers, x: number, z: number): Kind
	local g = layers.grid
	local cx, cz = g:cellAt(x, z)
	cx = math.clamp(cx, 0, g.cellsX - 1)
	cz = math.clamp(cz, 0, g.cellsZ - 1)
	return KIND[Layers.getTerrain(layers, cz * g.cellsX + cx)] or "grass"
end

-- What a hand-made map's cell is (Normandy.feature: "hedge", "house",
-- "road", ...), for finer materials than the four terrain types.
export type Feature = (cx: number, cz: number) -> string

-- Material name at (x, z): the map's feature where it has a look of its own
-- (C-66), else the terrain type. House cells give "ground" (their walls and
-- roofs are parts, Render/Ground).
local FEATURE: { [string]: string } = {
	hedge = "leafy",
	house = "ground",
	road = "road",
	bridge = "bridge",
	beach = "sand",
	bluff = "rock",
	draw = "ground",
	sea = "sand",
	river = "sand",
	field = "grass",
}
function Terrain.material(layers: Layers.Layers, x: number, z: number, feature: Feature?): string
	if feature then
		local g = layers.grid
		local cx, cz = g:cellAt(x, z)
		local name = FEATURE[feature(math.clamp(cx, 0, g.cellsX - 1), math.clamp(cz, 0, g.cellsZ - 1))]
		if name then
			return name
		end
	end
	return Terrain.kind(layers, x, z)
end

-- The map's water surface (lakes and seas share one level in MapGen), or
-- nil for a dry map.
function Terrain.waterLevel(layers: Layers.Layers): number?
	local g = layers.grid
	for i = 0, g.cellCount - 1 do
		local w = Layers.getWater(layers, i)
		if w > 0 then
			return Layers.getHeight(layers, i) + w
		end
	end
	return nil
end

-- Lowest ground and highest ground or water surface (the terrain's y range).
function Terrain.bounds(layers: Layers.Layers): (number, number)
	local lo, hi = math.huge, -math.huge
	for i = 0, layers.grid.cellCount - 1 do
		local h = Layers.getHeight(layers, i)
		lo = math.min(lo, h)
		hi = math.max(hi, h + Layers.getWater(layers, i))
	end
	return lo, hi
end

return Terrain

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

Terrain.STEEP = 1.2 -- rise / run above which ground is drawn as rock (~50°)
Terrain.SHORE = 2.5 -- studs above a water surface nearby: sand
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

-- Ground kind of a terrain column at (x, z), for its material:
-- "rock" (steep), "sand" (shore and lake / sea bed), "grass".
export type Kind = "grass" | "rock" | "sand"
function Terrain.kind(layers: Layers.Layers, x: number, z: number, waterLevel: number?): Kind
	local h = Terrain.groundY(layers, x, z)
	local d = CELL / 2
	local sx = (Terrain.groundY(layers, x + d, z) - Terrain.groundY(layers, x - d, z)) / (2 * d)
	local sz = (Terrain.groundY(layers, x, z + d) - Terrain.groundY(layers, x, z - d)) / (2 * d)
	if math.sqrt(sx * sx + sz * sz) > Terrain.STEEP then
		return "rock"
	end
	if Terrain.waterY(layers, x, z) ~= nil then
		return "sand"
	end
	if waterLevel and h < waterLevel + Terrain.SHORE then
		return "sand"
	end
	return "grass"
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

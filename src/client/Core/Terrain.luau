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
Terrain.DEPOSIT_LIFT = 0.35 -- studs: the drawn ground stays this close to flat under a deposit (Render/Deposits sits on it, C-123)

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

-- The baked mesh ground's height at (x, z) on a map baked with height
-- samples every `step` studs from its corner (models-C's `coarsen`, the
-- Lakelands at 8: C-235). Each sample is the smooth ground's height there
-- (on the 8-stud grid: the average of the four cells round a corner), and
-- each square between samples is two flat triangles split along its
-- flatter diagonal, as `assets/maps/tools/ground.py` builds them. So units
-- stand on what is drawn, not on the cell centres the coarse mesh skips.
function Terrain.drawnY(layers: Layers.Layers, x: number, z: number, step: number): number
	local g = layers.grid
	local nx, nz = math.floor(g.sizeX / step), math.floor(g.sizeZ / step) -- squares per side
	local fx = math.clamp((x - g.originX) / step, 0, nx)
	local fz = math.clamp((z - g.originZ) / step, 0, nz)
	local i, j = math.min(math.floor(fx), nx - 1), math.min(math.floor(fz), nz - 1)
	local tx, tz = fx - i, fz - j
	local x0, z0 = g.originX + i * step, g.originZ + j * step
	local h00, h10 = Terrain.groundY(layers, x0, z0), Terrain.groundY(layers, x0 + step, z0)
	local h01, h11 = Terrain.groundY(layers, x0, z0 + step), Terrain.groundY(layers, x0 + step, z0 + step)
	if math.abs(h00 - h11) <= math.abs(h10 - h01) then
		-- split along 00-11: (00, 11, 10) where tx >= tz, else (00, 01, 11)
		if tx >= tz then
			return h00 + tx * (h10 - h00) + tz * (h11 - h10)
		end
		return h00 + tz * (h01 - h00) + tx * (h11 - h01)
	end
	-- split along 10-01: (00, 01, 10) below it, else (10, 01, 11)
	if tx + tz <= 1 then
		return h00 + tx * (h10 - h00) + tz * (h01 - h00)
	end
	return h11 + (1 - tx) * (h01 - h11) + (1 - tz) * (h10 - h11)
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
-- roofs are parts, Render/Ground), and so do supply deposits: bare scraped
-- ground, so no grass blades cover the deposit's low rocks (C-123).
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
	-- The Canyon (Canyon.feature, S-132): a pale desert floor, red rock belts
	floor = "desert",
	badlands = "redrock",
	apron = "redrock",
	cliff = "redrock",
	mesa = "redrock",
	boulder = "redrock",
	-- Supreme Strait (SupremeStrait.feature, S-195): sea, beach, grass, mesa as above
	mountain = "rock",
	crater = "ground",
	pond = "sand",
}
function Terrain.material(layers: Layers.Layers, x: number, z: number, feature: Feature?): string
	local lg = layers.grid
	local dx, dz = lg:cellAt(x, z)
	if lg:inBounds(dx, dz) and Layers.getSupply(layers, lg:index(dx, dz)) > 0 then
		return "ground"
	end
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

-- The map's water as flat rectangles (C-236, S-192: water drawn as mesh
-- planes, not terrain voxels), world studs, `level` the surface. Water
-- cells of one surface merge into rectangles that never overlap (two
-- see-through planes over each other would show as a darker seam). Dry
-- cells next to water (a shore band one cell wide) join the rectangles at
-- their highest water neighbour's level: the smooth ground crosses the
-- surface somewhere in that cell, so the plane runs on under the shore and
-- the ground draws the waterline.
export type WaterRect = { x0: number, z0: number, x1: number, z1: number, level: number }
function Terrain.waterRects(layers: Layers.Layers): { WaterRect }
	local g = layers.grid
	local w, d = g.cellsX, g.cellsZ
	local level: { [number]: number } = {}
	for i = 0, g.cellCount - 1 do
		local water = Layers.getWater(layers, i)
		if water > 0 then
			level[i] = math.floor((Layers.getHeight(layers, i) + water) * 100 + 0.5) / 100
		end
	end
	local shore: { [number]: number } = {}
	for cz = 0, d - 1 do
		for cx = 0, w - 1 do
			local i = cz * w + cx
			if level[i] then
				continue
			end
			local best: number? = nil
			for dz = -1, 1 do
				for dx = -1, 1 do
					local nx, nz = cx + dx, cz + dz
					if nx >= 0 and nz >= 0 and nx < w and nz < d then
						local l = level[nz * w + nx]
						if l and (best == nil or l > best) then
							best = l
						end
					end
				end
			end
			if best then
				shore[i] = best
			end
		end
	end
	for i, l in shore do
		level[i] = l
	end
	local rects: { WaterRect } = {}
	local done: { [number]: boolean } = {}
	local cell = CELL
	for cz = 0, d - 1 do
		for cx = 0, w - 1 do
			local i = cz * w + cx
			local l = level[i]
			if l == nil or done[i] then
				continue
			end
			-- grow right, then down, while the cells match
			local ex = cx
			while ex + 1 < w and level[cz * w + ex + 1] == l and not done[cz * w + ex + 1] do
				ex += 1
			end
			local ez = cz
			while ez + 1 < d do
				local row = (ez + 1) * w
				local ok = true
				for x = cx, ex do
					if level[row + x] ~= l or done[row + x] then
						ok = false
						break
					end
				end
				if not ok then
					break
				end
				ez += 1
			end
			for z = cz, ez do
				for x = cx, ex do
					done[z * w + x] = true
				end
			end
			table.insert(rects, { x0 = g.originX + cx * cell, z0 = g.originZ + cz * cell, x1 = g.originX + (ex + 1) * cell, z1 = g.originZ + (ez + 1) * cell, level = l })
		end
	end
	return rects
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

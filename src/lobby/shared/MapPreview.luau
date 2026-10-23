--!strict
-- A small top-down picture of a map for the room's map picker (L-5). The
-- server builds it once per map from the map's layers (MapRegistry) and
-- sends it to clients, which color it. Pure Luau.
--
-- One byte per pixel: class * 32 + shade (0..31), north (−Z) at the top.
--   class 0 grass, 1 rock, 2 sand, 3 road (shade: height, low to high),
--   class 4 water (shade: depth, shallow to deep), class 5 supply deposit.

local MapPreview = {}

MapPreview.CLASSES = table.freeze({ GRASS = 0, ROCK = 1, SAND = 2, ROAD = 3, WATER = 4, DEPOSIT = 5 })

export type Preview = {
	w: number,
	h: number,
	data: buffer, -- w * h bytes, row by row from the north edge
	starts: { { number } }, -- start positions as {u, v} in 0..1 (u east, v south), player order
	cells: { number }, -- the map's size in cells {x, z}
}

-- `layers` is a Grid/Layers.Layers; `maxSide` the larger side in pixels.
function MapPreview.build(layers: any, maxSide: number): Preview
	local g = layers.grid
	local cellsX, cellsZ = g.cellsX, g.cellsZ
	local scale = math.max(cellsX, cellsZ) / maxSide
	local w = math.max(1, math.floor(cellsX / scale + 0.5))
	local h = math.max(1, math.floor(cellsZ / scale + 0.5))
	local readi16, readu8 = buffer.readi16, buffer.readu8
	-- height range over dry land, for the shading
	local lo, hi = math.huge, -math.huge
	for i = 0, g.cellCount - 1 do
		if readi16(layers.waterDepth, i * 2) <= 0 then
			local y = readi16(layers.height, i * 2)
			lo, hi = math.min(lo, y), math.max(hi, y)
		end
	end
	if lo > hi then
		lo, hi = 0, 1
	end
	local span = math.max(hi - lo, 1)
	local deepest = 1
	for i = 0, g.cellCount - 1 do
		deepest = math.max(deepest, readi16(layers.waterDepth, i * 2))
	end
	local data = buffer.create(w * h)
	for py = 0, h - 1 do
		for px = 0, w - 1 do
			-- the pixel's cells: any deposit wins, else the centre cell
			local cx0, cx1 = math.floor(px * scale), math.max(math.floor(px * scale), math.floor((px + 1) * scale) - 1)
			local cz0, cz1 = math.floor(py * scale), math.max(math.floor(py * scale), math.floor((py + 1) * scale) - 1)
			cx1, cz1 = math.min(cx1, cellsX - 1), math.min(cz1, cellsZ - 1)
			local value: number? = nil
			for cz = cz0, cz1 do
				for cx = cx0, cx1 do
					if readu8(layers.supply, cz * cellsX + cx) > 0 then
						value = MapPreview.CLASSES.DEPOSIT * 32 + 31
					end
				end
			end
			if value == nil then
				local i = math.min((cz0 + cz1) // 2, cellsZ - 1) * cellsX + math.min((cx0 + cx1) // 2, cellsX - 1)
				local depth = readi16(layers.waterDepth, i * 2)
				if depth > 0 then
					value = MapPreview.CLASSES.WATER * 32 + math.clamp(math.floor(depth / deepest * 31 + 0.5), 0, 31)
				else
					local class = math.clamp(readu8(layers.terrain, i), 0, 3)
					local shade = math.clamp(math.floor((readi16(layers.height, i * 2) - lo) / span * 31 + 0.5), 0, 31)
					value = class * 32 + shade
				end
			end
			buffer.writeu8(data, py * w + px, value :: number)
		end
	end
	local starts = {}
	for _, s in layers.starts do
		table.insert(starts, { (s[1] - g.originX) / g.sizeX, (s[2] - g.originZ) / g.sizeZ })
	end
	return { w = w, h = h, data = data, starts = starts, cells = { cellsX, cellsZ } }
end

-- The color of a preview byte, as {r, g, b} 0..255 (the client draws it).
local BASE = {
	[0] = { { 46, 70, 40 }, { 120, 140, 92 } }, -- grass: low, high
	[1] = { { 70, 66, 62 }, { 150, 144, 136 } }, -- rock
	[2] = { { 120, 100, 66 }, { 206, 182, 132 } }, -- sand
	[3] = { { 92, 88, 80 }, { 128, 124, 116 } }, -- road
	[4] = { { 52, 96, 140 }, { 18, 36, 70 } }, -- water: shallow, deep
	[5] = { { 238, 186, 92 }, { 238, 186, 92 } }, -- deposit: the kit's accent
}
function MapPreview.color(byte: number): (number, number, number)
	local class, shade = byte // 32, (byte % 32) / 31
	local pair = BASE[class] or BASE[0]
	local a, b = pair[1], pair[2]
	return math.floor(a[1] + (b[1] - a[1]) * shade), math.floor(a[2] + (b[2] - a[2]) * shade), math.floor(a[3] + (b[3] - a[3]) * shade)
end

return MapPreview

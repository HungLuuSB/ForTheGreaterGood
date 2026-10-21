--!strict
-- Renders a procedural test map to debug_out/map_<seed>.ppm and .png.
--   lune run debug_map [seed] [cells]
-- or any MapRegistry map (e.g. map:ridgeline, mapgen:ffa4:5:192:sea) to
-- debug_out/map_<id>.png: terrain shaded by height, cells TRACKED units
-- can't enter in dark red, water in blue, deposits in yellow (brighter =
-- richer), starts as white squares.
--   lune run debug_map <mapId>

local process = require("@lune/process")

local Layers = require("../src/shared/Grid/Layers")
local Ppm = require("./lib/Ppm")
local TestMap = require("../src/shared/Grid/TestMap")

local MapRegistry = require("../src/shared/Grid/MapRegistry")
local Passability = require("../src/shared/Grid/Passability")

local arg1 = process.args[1]
if arg1 and tonumber(arg1) == nil then
	local layers = MapRegistry.load(arg1) :: Layers.Layers
	local pm = Passability.build(layers)
	local g = layers.grid
	local img = Ppm.new(g.cellsX, g.cellsZ)
	local tracked = pm.clearance.TRACKED
	for cz = 0, g.cellsZ - 1 do
		for cx = 0, g.cellsX - 1 do
			local i = g:index(cx, cz)
			local h, w, s = Layers.getHeight(layers, i), Layers.getWater(layers, i), Layers.getSupply(layers, i)
			if s > 0 then
				Ppm.set(img, cx, cz, 255, 180 + 12 * s, 0)
			elseif w > 0 then
				local d = math.min(w / 20, 1)
				Ppm.set(img, cx, cz, 40 - 30 * d, 110 - 70 * d, 200 - 80 * d)
			elseif buffer.readu8(tracked, i) == 0 then
				Ppm.set(img, cx, cz, 110, 30, 30)
			else
				local t = math.clamp((h - 8) / 40, 0, 1)
				Ppm.set(img, cx, cz, 70 + 150 * t, 130 + 90 * t, 60 + 120 * t)
			end
		end
	end
	for _, st in layers.starts do
		local sx, sz = g:cellAt(st[1], st[2])
		for dz = -1, 1 do
			for dx = -1, 1 do
				Ppm.set(img, sx + dx, sz + dz, 255, 255, 255)
			end
		end
	end
	local base = `debug_out/map_{string.gsub(arg1, "[^%w_]", "_")}`
	Ppm.writePng(Ppm.scale(img, 4), base .. ".png")
	print(`wrote {base}.png ({g.cellsX}x{g.cellsZ})`)
	return
end

local seed = tonumber(process.args[1]) or 1
local cells = tonumber(process.args[2]) or 128
local amplitude = 48

local layers = TestMap.generate({ seed = seed, cellsX = cells, amplitude = amplitude })
local g = layers.grid
local img = Ppm.new(g.cellsX, g.cellsZ)
for cz = 0, g.cellsZ - 1 do
	for cx = 0, g.cellsX - 1 do
		local i = g:index(cx, cz)
		local h, w = Layers.getHeight(layers, i), Layers.getWater(layers, i)
		if w > 0 then
			local d = math.min(w / 12, 1)
			Ppm.set(img, cx, cz, 40 - 30 * d, 110 - 70 * d, 200 - 80 * d)
		else
			local s = h / amplitude
			Ppm.set(img, cx, cz, 70 + 150 * s, 130 + 90 * s, 60 + 120 * s)
		end
	end
end

local base = `debug_out/map_{seed}`
Ppm.write(img, base .. ".ppm")
Ppm.writePng(Ppm.scale(img, 3), base .. ".png")
print(`wrote {base}.ppm and .png ({g.cellsX}x{g.cellsZ})`)

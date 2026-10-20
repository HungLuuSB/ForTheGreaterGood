--!strict
-- Renders a procedural test map to debug_out/map_<seed>.ppm and .png.
--   lune run debug_map [seed] [cells]

local process = require("@lune/process")

local Layers = require("../src/shared/Grid/Layers")
local Ppm = require("./lib/Ppm")
local TestMap = require("../src/shared/Grid/TestMap")

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

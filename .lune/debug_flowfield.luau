--!strict
-- Renders a flow field to debug_out/flowfield_<map>.png (and .ppm).
--   lune run debug_flowfield [maze|hills] [seed]
--
-- Each cell is 8 × 8 px: blocked cells dark, cells outside the corridor grey,
-- corridor cells shaded by integration cost (yellow near the goal → purple far
-- away) with a line pointing along the flow direction. The goal is red, the
-- start green.

local process = require("@lune/process")

local FlowField = require("../src/server/Sim/Path/FlowField")
local Layers = require("../src/shared/Grid/Layers")
local Passability = require("../src/shared/Grid/Passability")
local Ppm = require("./lib/Ppm")
local Quadtree = require("../src/server/Sim/Path/Quadtree")
local Route = require("../src/server/Sim/Path/Route")
local TestMap = require("../src/shared/Grid/TestMap")

local kind = process.args[1] or "maze"
local seed = tonumber(process.args[2]) or 4
local PX = 8

local layers
if kind == "hills" then
	layers = TestMap.generate({ seed = seed, cellsX = 96, cellsZ = 64 })
else
	layers = TestMap.build(96, 64, function(cx, cz)
		local wall = cx % 16 == 8 and cx >= 8
		local openTop = (cx // 16) % 2 == 0
		if wall and ((openTop and cz >= 8) or (not openTop and cz < 56)) then
			return 10, 10
		end
		return 10, 0
	end)
end
local pm = Passability.build(layers)
local tree = Quadtree.build(pm, "TRACKED", 1)
local g = pm.grid

-- Start near the left edge, goal near the right edge, both open and connected.
local function firstOpen(fromX: number, step: number): number
	local x = fromX
	while x >= 0 and x < g.cellsX do
		for dz = 0, g.cellsZ // 2 do
			for _, z in { g.cellsZ // 2 + dz, g.cellsZ // 2 - dz } do
				if z >= 0 and z < g.cellsZ and Quadtree.isOpen(tree, g:index(x, z)) then
					return g:index(x, z)
				end
			end
		end
		x += step
	end
	error("no open cell")
end
local start = firstOpen(1, 1)
local goal = firstOpen(g.cellsX - 2, -1)
local route, failure = Route.find(tree, start, goal)
assert(route, failure)
local corridor = Route.corridor(tree, route)
local field = FlowField.build(tree, corridor, goal, true)
local cost = field.cost :: { number }

local maxCost = 0
for c = 0, g.cellCount - 1 do
	if cost[c + 1] < math.huge then
		maxCost = math.max(maxCost, cost[c + 1])
	end
end

local img = Ppm.new(g.cellsX * PX, g.cellsZ * PX)
for cz = 0, g.cellsZ - 1 do
	for cx = 0, g.cellsX - 1 do
		local c = g:index(cx, cz)
		local r, gr, b
		if not Quadtree.isOpen(tree, c) then
			local water = Layers.getWater(layers, c) > 0
			r, gr, b = if water then 20 else 40, if water then 40 else 40, if water then 90 else 40
		elseif not Route.inCorridor(corridor, c) then
			r, gr, b = 150, 150, 150
		else
			local s = cost[c + 1] / math.max(maxCost, 1)
			r, gr, b = 250 - 130 * s, 230 - 200 * s, 60 + 120 * s
		end
		if c == goal then
			r, gr, b = 230, 30, 30
		elseif c == start then
			r, gr, b = 30, 200, 30
		end
		for py = 0, PX - 1 do
			for px = 0, PX - 1 do
				Ppm.set(img, cx * PX + px, cz * PX + py, r, gr, b)
			end
		end
		local d = FlowField.direction(field, c)
		if d ~= FlowField.NONE then
			local vx, vz = FlowField.vector(d)
			for k = 0, 3 do
				Ppm.set(img, cx * PX + 3 + math.round(vx * k), cz * PX + 3 + math.round(vz * k), 20, 20, 20)
			end
		end
	end
end

local base = `debug_out/flowfield_{kind}`
Ppm.write(img, base .. ".ppm")
Ppm.writePng(img, base .. ".png")
print(`wrote {base}.png: {corridor.cellCount} corridor cells, route {#route} leaves`)

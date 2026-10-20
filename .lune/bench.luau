--!strict
-- Flow field benchmark on 256 × 256 maps (open, maze, island).
--   lune run bench [runs]
-- Prints a table and writes it to debug_out/bench.txt.
--
-- For each map: quadtree build, coarse route, corridor, and the flow field
-- (integration + directions) for a far-apart start/goal pair, timed over
-- several runs (median and best). Also derives work units per millisecond,
-- which calibrates the deterministic per-tick Pathing budget (DECISIONS D29).

local fs = require("@lune/fs")
local process = require("@lune/process")

local FlowField = require("../src/server/Sim/Path/FlowField")
local Passability = require("../src/shared/Grid/Passability")
local Quadtree = require("../src/server/Sim/Path/Quadtree")
local Route = require("../src/server/Sim/Path/Route")
local TestMap = require("../src/shared/Grid/TestMap")

local RUNS = tonumber(process.args[1]) or 7
local SIZE = 256
local BUDGET_MS = 8

local function maze()
	return TestMap.build(SIZE, SIZE, function(cx, cz)
		local spacing = 16
		if cx % spacing == spacing // 2 and cx >= spacing // 2 then
			local openTop = (cx // spacing) % 2 == 0
			local gap = 12
			if (openTop and cz >= gap) or (not openTop and cz < SIZE - gap) then
				return 10, 10
			end
		end
		return 10, 0
	end)
end

local function island()
	-- A round island (radius 110 cells) in deep water, with hills and lakes
	-- from the noise map inside it.
	local hills = TestMap.generate({ seed = 3, cellsX = SIZE, amplitude = 48 })
	local Layers = require("../src/shared/Grid/Layers")
	return TestMap.build(SIZE, SIZE, function(cx, cz)
		local dx, dz = cx - SIZE / 2 + 0.5, cz - SIZE / 2 + 0.5
		if dx * dx + dz * dz > 110 * 110 then
			return 0, 20
		end
		local i = cz * SIZE + cx
		return Layers.getHeight(hills, i), Layers.getWater(hills, i)
	end)
end

local MAPS = {
	{ name = "open", layers = function()
		return TestMap.build(SIZE, SIZE, function()
			return 10, 0
		end)
	end },
	{ name = "maze", layers = maze },
	{ name = "island", layers = island },
}

local function median(xs: { number }): number
	local s = table.clone(xs)
	table.sort(s)
	return s[(#s + 1) // 2]
end

local function ms(f: () -> ()): number
	local t0 = os.clock()
	f()
	return (os.clock() - t0) * 1000
end

-- Two open cells in the same component, as far apart as the scan allows:
-- the first open cell near the west edge and the last near the east edge.
local function endpoints(tree: Quadtree.Tree): (number, number)
	local g = tree.grid
	local best, bestComp
	for cx = 0, g.cellsX - 1 do
		for cz = 0, g.cellsZ - 1 do
			local c = g:index(cx, cz)
			if Quadtree.isOpen(tree, c) then
				best, bestComp = c, Quadtree.component(tree, c)
				break
			end
		end
		if best then
			break
		end
	end
	for cx = g.cellsX - 1, 0, -1 do
		for cz = g.cellsZ - 1, 0, -1 do
			local c = g:index(cx, cz)
			if Quadtree.isOpen(tree, c) and Quadtree.component(tree, c) == bestComp then
				return best :: number, c
			end
		end
	end
	error("no endpoints")
end

local lines = {}
local function out(s: string)
	print(s)
	table.insert(lines, s)
end

out(`Flow field benchmark, {SIZE}x{SIZE} cells, TRACKED footprint 1, {RUNS} runs (median / best, ms)`)
out(string.format("%-7s %10s %8s %10s %9s %13s %13s %10s %12s", "map", "pass", "tree", "route", "corridor", "field", "integr.", "units", "units/ms"))

local results = {}
for _, m in MAPS do
	local layers = m.layers()
	local pm
	local passMs = ms(function()
		pm = Passability.build(layers)
	end)
	local treeTimes, routeTimes, corridorTimes, fieldTimes, integTimes = {}, {}, {}, {}, {}
	local units, cells, routeLen = 0, 0, 0
	for _ = 1, RUNS do
		local tree
		table.insert(treeTimes, ms(function()
			tree = Quadtree.build(pm, "TRACKED", 1)
		end))
		local start, goal = endpoints(tree)
		local route
		table.insert(routeTimes, ms(function()
			route = Route.find(tree, start, goal)
		end))
		routeLen = #route
		local corridor
		table.insert(corridorTimes, ms(function()
			corridor = Route.corridor(tree, route)
		end))
		cells = corridor.cellCount
		local job = FlowField.newJob(tree, corridor, goal)
		local integ = ms(function()
			while job.phase == "integrate" do
				FlowField.run(job, 1000)
			end
		end)
		local direct = ms(function()
			FlowField.run(job)
		end)
		table.insert(integTimes, integ)
		table.insert(fieldTimes, integ + direct)
		units = job.workDone
	end
	local fieldMed = median(fieldTimes)
	local unitsPerMs = units / fieldMed
	results[m.name] = { field = fieldMed, units = units, unitsPerMs = unitsPerMs, cells = cells }
	out(string.format(
		"%-7s %10.1f %4.1f/%-4.1f %4.2f/%-5.2f %9.2f %6.1f/%-6.1f %6.1f/%-6.1f %10d %12.0f",
		m.name,
		passMs,
		median(treeTimes),
		math.min(table.unpack(treeTimes)),
		median(routeTimes),
		math.min(table.unpack(routeTimes)),
		median(corridorTimes),
		fieldMed,
		math.min(table.unpack(fieldTimes)),
		median(integTimes),
		math.min(table.unpack(integTimes)),
		units,
		unitsPerMs
	))
	out(string.format("        corridor %d cells, route %d leaves", cells, routeLen))
end

local slowest = math.huge
for _, r in results do
	slowest = math.min(slowest, r.unitsPerMs)
end
out("")
out(string.format("Pathing budget %d ms -> about %d work units per tick at the slowest measured rate.", BUDGET_MS, math.floor(slowest * BUDGET_MS)))
for _, m in MAPS do
	local r = results[m.name]
	local ticks = math.ceil(r.units / (slowest * BUDGET_MS))
	out(string.format("  %-7s full field %.1f ms -> %s; ~%d ticks (%.0f ms) when sliced", m.name, r.field, if r.field <= BUDGET_MS then "within budget" else "OVER budget", ticks, ticks * 1000 / 15))
end

if not fs.isDir("debug_out") then
	fs.writeDir("debug_out")
end
fs.writeFile("debug_out/bench.txt", table.concat(lines, "\n") .. "\n")

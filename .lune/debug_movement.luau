--!strict
-- Runs the 50-unit march and renders unit tracks to debug_out/movement_<map>.png.
--   lune run debug_movement [mapId] [ticks]
-- Terrain: land green, water blue, impassable for TRACKED dark. Tracks are
-- colored per unit; final positions are white dots, goals black.

local process = require("@lune/process")

local Layers = require("../src/shared/Grid/Layers")
local Packer = require("../src/shared/Net/Packer")
local Passability = require("../src/shared/Grid/Passability")
local Ppm = require("./lib/Ppm")
local Schema = require("../src/shared/Net/Schema")
local Sim = require("../src/server/Sim/Sim")

local mapId = process.args[1] or "gen:7:96"
local maxTicks = tonumber(process.args[2]) or 3000
local PX = 4

local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = mapId })
local nav = sim.nav :: any
local g = nav.grid
local w = sim.world

-- Target: the open TRACKED cell nearest the east edge's middle, in the units' component.
local Quadtree = require("../src/server/Sim/Path/Quadtree")
local tree = Quadtree.build(nav.pm, "TRACKED", 1)
local ux, uz = g:cellAt(w.posX[w.ids[1]], w.posZ[w.ids[1]])
local comp = Quadtree.component(tree, g:index(ux, uz))
local target
for cx = g.cellsX - 6, 0, -1 do
	for dz = 0, g.cellsZ // 2 - 1 do
		for _, cz in { g.cellsZ // 2 + dz, g.cellsZ // 2 - dz - 1 } do
			local c = g:index(cx, cz)
			if Quadtree.isOpen(tree, c) and Quadtree.component(tree, c) == comp and Passability.clearance(nav.pm, "TRACKED", c) >= 3 then
				target = c
				break
			end
		end
		if target then
			break
		end
	end
	if target then
		break
	end
end
assert(target, "no target")

local wr = Packer.Writer.new()
local tc, tx, tz = g:encode(g:cellCenter(g:coords(target))) -- a wire position (S-189)
Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = table.clone(w.ids), cell = tc, offX = tx, offZ = tz })
assert(Sim.submit(sim, 1, wr:finish()))

Sim.step(sim)
local slots = {}
for _, id in w.ids do
	slots[id] = { w.goalX[id], w.goalZ[id] }
end

local tracks: { [number]: { { number } } } = {}
for _, id in w.ids do
	tracks[id] = { { w.posX[id], w.posZ[id] } }
end
local t0 = os.clock()
local arrivedAt = nil
for _ = 1, maxTicks do
	Sim.step(sim)
	local busy = false
	for _, id in w.ids do
		table.insert(tracks[id], { w.posX[id], w.posZ[id] })
		busy = busy or w.orderId[id] ~= 0
	end
	if not busy then
		arrivedAt = sim.tick
		break
	end
end
local elapsed = os.clock() - t0

local img = Ppm.new(g.cellsX * PX, g.cellsZ * PX)
for cz = 0, g.cellsZ - 1 do
	for cx = 0, g.cellsX - 1 do
		local c = g:index(cx, cz)
		local r, gr, b = 90, 150, 80
		if Layers.getWater(nav.pm.layers, c) > 0 then
			r, gr, b = 50, 90, 170
		end
		if not Passability.canEnter(nav.pm, "TRACKED", c) then
			r, gr, b = r * 0.5, gr * 0.5, b * 0.5
		end
		for py = 0, PX - 1 do
			for px = 0, PX - 1 do
				Ppm.set(img, cx * PX + px, cz * PX + py, r, gr, b)
			end
		end
	end
end
local function plot(x: number, z: number, r: number, gr: number, b: number)
	Ppm.set(img, math.floor((x - g.originX) / 8 * PX), math.floor((z - g.originZ) / 8 * PX), r, gr, b)
end
for i, id in w.ids do
	local hue = (i * 37) % 360
	local r = 128 + 127 * math.cos(math.rad(hue))
	local gr = 128 + 127 * math.cos(math.rad(hue - 120))
	local b = 128 + 127 * math.cos(math.rad(hue + 120))
	for _, pt in tracks[id] do
		plot(pt[1], pt[2], r, gr, b)
	end
end
for _, id in w.ids do
	plot(w.goalX[id], w.goalZ[id], 0, 0, 0)
	plot(w.posX[id], w.posZ[id], 255, 255, 255)
end

local worstSlot, exact = 0, 0
for _, id in w.ids do
	local d = math.sqrt((slots[id][1] - w.posX[id]) ^ 2 + (slots[id][2] - w.posZ[id]) ^ 2)
	worstSlot = math.max(worstSlot, d)
	if d <= 2 then
		exact += 1
	end
end
local minSlack = math.huge
for i, a in w.ids do
	for j = i + 1, #w.ids do
		local b = w.ids[j]
		local d = math.sqrt((w.posX[a] - w.posX[b]) ^ 2 + (w.posZ[a] - w.posZ[b]) ^ 2)
		minSlack = math.min(minSlack, d - nav.profiles[w.defIndex[a]].radius - nav.profiles[w.defIndex[b]].radius)
	end
end
print(string.format("  final: %d/%d within 2 studs of their slot, worst %.1f studs; closest pair gap %.2f studs (negative = overlap)", exact, #w.ids, worstSlot, minSlack))

local base = `debug_out/movement_{string.gsub(mapId, ":", "_")}`
Ppm.write(img, base .. ".ppm")
Ppm.writePng(img, base .. ".png")
print(string.format(
	"%s: %d units, %s after %d ticks (%.0f ms sim time, %.2f ms/tick); fields built %d, work units %d",
	mapId,
	#w.ids,
	if arrivedAt then "all arrived" else "NOT all arrived",
	sim.tick,
	elapsed * 1000,
	elapsed * 1000 / sim.tick,
	nav.stats.fieldsBuilt,
	nav.stats.workUnits
))
print(`wrote {base}.png`)

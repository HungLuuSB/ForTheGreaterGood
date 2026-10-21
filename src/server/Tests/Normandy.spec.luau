--!strict
-- "map:normandy" (S-53, client request 31): zones where the client's
-- profile expects them, and what blocks or lets land units through.
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Normandy = require("@shared/Grid/Normandy")
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local T = Layers.Terrain
local LAND = { "WHEELED", "TRACKED", "HEAVY_TRACKED" }

return function(t: RunAll.Context)
	local layers = MapRegistry.load("map:normandy") :: Layers.Layers
	local g = layers.grid
	local pm = Passability.build(layers)
	local function cell(x: number, z: number): number
		local cx, cz = g:cellAt(x, z)
		return g:index(cx, cz)
	end
	local function featureAt(x: number, z: number): string
		local cx, cz = g:cellAt(x, z)
		return Normandy.feature(cx, cz)
	end

	t.test("zones: 2048 studs centred on 0, sea, beach, bluffs, plateau, river, starts", function()
		t.equal(g.cellsX, 256)
		t.equal(g.cellsZ, 256)
		t.equal(g.originX, -1024)
		t.equal(g.originZ, -1024)
		t.expect(Layers.getWater(layers, cell(0, 900)) >= 20, "deep sea in the north")
		t.equal(Layers.getHeight(layers, cell(0, 900)) + Layers.getWater(layers, cell(0, 900)), 10, "sea surface at 10")
		t.equal(Layers.getTerrain(layers, cell(300, 700)), T.SAND, "sand beach")
		t.expect(math.abs(Layers.getHeight(layers, cell(300, 750)) - 10) < 1 and math.abs(Layers.getHeight(layers, cell(300, 645)) - 14) < 1, "beach 10 → 14")
		t.expect(math.abs(Layers.getHeight(layers, cell(300, 400)) - 34) <= 2, "plateau at ~34")
		t.equal(featureAt(300, -380), "river")
		t.expect(Layers.getWater(layers, cell(300, -380)) >= 3, "the river is deep enough to stop wheels and tracks")
		for _, bx in Normandy.BRIDGES do
			t.equal(featureAt(bx, -380), "bridge", `bridge at x = {bx}`)
			t.equal(Layers.getTerrain(layers, cell(bx, -380)), T.ROAD)
		end
		t.equal(#layers.starts, 2)
		t.expect(layers.starts[1][2] > 640 and layers.starts[2][2] < -420, "player 1 on the beach, player 2 south of the river")
		t.equal(Layers.getSupply(layers, cell(0, 0)), 0, "no deposits")
	end)

	t.test("the bluffs, river, hedges and houses stop land units; draws, bridges and gaps let them through", function()
		for _, mc in LAND do
			t.expect(not Passability.canEnter(pm, mc, cell(300, 628)), `{mc}: the cliff is too steep`)
			t.expect(not Passability.canEnter(pm, mc, cell(300, -380)), `{mc}: the river`)
			for _, dx in Normandy.DRAWS do
				for _, z in { 630, 600, 570 } do
					t.expect(Passability.canEnter(pm, mc, cell(dx, z)), `{mc}: the draw at x = {dx}, z = {z}`)
				end
			end
			for _, bx in Normandy.BRIDGES do
				t.expect(Passability.canEnter(pm, mc, cell(bx, -380)), `{mc}: the bridge at x = {bx}`)
			end
		end
		local hedges, houses = 0, 0
		for cz = 0, 255 do
			for cx = 0, 255 do
				local f = Normandy.feature(cx, cz)
				if f == "hedge" or f == "house" then
					if f == "hedge" then
						hedges += 1
					else
						houses += 1
					end
					for _, mc in LAND do
						t.expect(not Passability.canEnter(pm, mc, g:index(cx, cz)), `{mc} can't enter a {f}`)
					end
					local _, z = g:cellCenter(cx, cz)
					t.expect(z > -200 and z < 280 or f == "house", "hedges only in the bocage")
					t.expect(not (z >= 280 and z <= 540) and not (z >= -340 and z <= -200), "the staging fields are open")
				end
			end
		end
		print(`    normandy: {hedges} hedge cells, {houses} house cells`)
		t.expect(hedges > 500 and houses >= 16, "bocage and two villages")
	end)

	t.test("every land class can get from one start to the other", function()
		for _, mc in LAND do
			local from = cell(layers.starts[2][1], layers.starts[2][2])
			local to = cell(layers.starts[1][1], layers.starts[1][2])
			local seen = { [from] = true }
			local queue, head = { from }, 1
			while head <= #queue and not seen[to] do
				local i = queue[head]
				head += 1
				local cx, cz = i % 256, i // 256
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nx, nz = cx + d[1], cz + d[2]
					if nx >= 0 and nx < 256 and nz >= 0 and nz < 256 then
						local j = g:index(nx, nz)
						if not seen[j] and Passability.canEnter(pm, mc, j) then
							seen[j] = true
							table.insert(queue, j)
						end
					end
				end
			end
			t.expect(seen[to] == true, `{mc} reaches the beach from the south`)
		end
	end)

	t.test("a tank drives over a bridge", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "map:normandy" })
		local tank = Spawn.unit(sim, "chs_ravager", 2, 120, -600, 0)
		local cellId, ox, oz = g:encode(80, -200)
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tank }, cell = cellId, offX = ox, offZ = oz })
		assert(Sim.submit(sim, 2, w:finish()))
		local crossedAt: number? = nil
		for _ = 1, 1500 do
			Sim.step(sim)
			local z = sim.world.posZ[tank]
			if z > -360 and crossedAt == nil then
				crossedAt = sim.tick
				local x = sim.world.posX[tank]
				t.expect(math.abs(x - 100) <= 24, `it crossed on the bridge at x = 100 (x = {x})`)
			end
			if z > -220 then
				break
			end
		end
		t.expect(crossedAt ~= nil, "it crossed the river")
		t.expect(sim.world.posZ[tank] > -230, `it reached the north bank fields (z = {sim.world.posZ[tank]})`)
	end)

	t.test("the map is the same every time", function()
		local again = MapRegistry.load("map:normandy") :: Layers.Layers
		t.expect(buffer.tostring(again.height) == buffer.tostring(layers.height), "heights")
		t.expect(buffer.tostring(again.waterDepth) == buffer.tostring(layers.waterDepth), "water")
		t.expect(buffer.tostring(again.terrain) == buffer.tostring(layers.terrain), "terrain")
	end)
end

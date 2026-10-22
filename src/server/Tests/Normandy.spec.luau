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

	t.test("zones: 2048 studs centred on 0, sea and bluffs on the north flank, a river before each side's rear, starts west and east", function()
		t.equal(g.cellsX, 256)
		t.equal(g.cellsZ, 256)
		t.equal(g.originX, -1024)
		t.equal(g.originZ, -1024)
		t.expect(Layers.getWater(layers, cell(0, 900)) >= 20, "deep sea in the north")
		t.equal(Layers.getHeight(layers, cell(0, 900)) + Layers.getWater(layers, cell(0, 900)), 10, "sea surface at 10")
		t.equal(Layers.getTerrain(layers, cell(300, 700)), T.SAND, "sand beach")
		t.expect(math.abs(Layers.getHeight(layers, cell(300, 750)) - 10) < 1 and math.abs(Layers.getHeight(layers, cell(300, 645)) - 14) < 1, "beach 10 → 14")
		t.expect(math.abs(Layers.getHeight(layers, cell(300, 400)) - 34) <= 2, "plateau at ~34")
		for _, rx in { -Normandy.RIVER_X, Normandy.RIVER_X } do
			t.equal(featureAt(rx, -500), "river", `a river at x = {rx}`)
			t.expect(Layers.getWater(layers, cell(rx, -500)) >= 3, "deep enough to stop wheels and tracks")
			for _, bz in Normandy.BRIDGES do
				t.equal(featureAt(rx, bz), "bridge", `bridge at ({rx}, {bz})`)
				t.equal(Layers.getTerrain(layers, cell(rx, bz)), T.ROAD)
			end
		end
		t.equal(#layers.starts, 2)
		t.expect(layers.starts[1][1] < -672 and layers.starts[2][1] > 672, "player 1 in the west rear, player 2 in the east")
		t.expect(math.abs(layers.starts[1][2] - layers.starts[2][2]) < 1, "facing each other across the map")
		-- mirrored about x = 0 south of the bluffs: neither side has better ground
		local mirrored = true
		for cz = 0, 255 do
			local _, z = g:cellCenter(0, cz)
			if z < 560 then
				for cx = 0, 127 do
					if Normandy.feature(cx, cz) ~= Normandy.feature(255 - cx, cz) or Layers.getHeight(layers, g:index(cx, cz)) ~= Layers.getHeight(layers, g:index(255 - cx, cz)) then
						mirrored = false
					end
				end
			end
		end
		t.expect(mirrored, "west and east are mirror images")
		-- supply deposits (S-98): mirrored, on open fields, 15 per side
		local count, value, onField, symmetric = 0, 0, true, true
		for cz = 0, 255 do
			for cx = 0, 255 do
				local v = Layers.getSupply(layers, g:index(cx, cz))
				if v > 0 then
					count += 1
					value += v
					onField = onField and Normandy.feature(cx, cz) == "field"
					symmetric = symmetric and Layers.getSupply(layers, g:index(255 - cx, cz)) == v
				end
			end
		end
		t.equal(count, 30, "30 deposits: 14 a side and a rich pair in the middle")
		t.equal(value, 104, "worth 104 in all")
		t.expect(onField, "every deposit on an open field cell")
		t.expect(symmetric, "west and east deposits mirror each other")
		local west = 0
		for cx = 0, 127 do
			for cz = 0, 255 do
				local v = Layers.getSupply(layers, g:index(cx, cz))
				local x = g:cellCenter(cx, cz)
				if v > 0 and x < -Normandy.RIVER_X then
					west += 1
				end
			end
		end
		t.equal(west, 8, "8 behind the west river: home and rear")
	end)

	t.test("the bluffs, river, hedges and houses stop land units; draws, bridges and gaps let them through", function()
		for _, mc in LAND do
			t.expect(not Passability.canEnter(pm, mc, cell(300, 628)), `{mc}: the cliff is too steep`)
			t.expect(not Passability.canEnter(pm, mc, cell(Normandy.RIVER_X, -500)), `{mc}: the river`)
			for _, dx in Normandy.DRAWS do
				for _, z in { 630, 600, 570 } do
					t.expect(Passability.canEnter(pm, mc, cell(dx, z)), `{mc}: the draw at x = {dx}, z = {z}`)
				end
			end
			for _, bz in Normandy.BRIDGES do
				t.expect(Passability.canEnter(pm, mc, cell(-Normandy.RIVER_X, bz)) and Passability.canEnter(pm, mc, cell(Normandy.RIVER_X, bz)), `{mc}: the bridges at z = {bz}`)
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
					local x = g:cellCenter(cx, cz)
					t.expect(math.abs(x) < 400, "hedges and houses only in the bocage: staging fields and rears are open")
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
			t.expect(seen[to] == true, `{mc} gets from the east start to the west start`)
		end
	end)

	t.test("a tank drives over a bridge", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "map:normandy" })
		local tank = Spawn.unit(sim, "chs_ravager", 2, 860, 230, -math.pi / 2)
		local cellId, ox, oz = g:encode(500, 260)
		local w = Packer.Writer.new()
		Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tank }, cell = cellId, offX = ox, offZ = oz })
		assert(Sim.submit(sim, 2, w:finish()))
		local crossedAt: number? = nil
		for _ = 1, 1500 do
			Sim.step(sim)
			local x = sim.world.posX[tank]
			if x < Normandy.RIVER_X - 12 and crossedAt == nil then
				crossedAt = sim.tick
				local z = sim.world.posZ[tank]
				t.expect(math.abs(z - 250) <= 24, `it crossed on the bridge at z = 250 (z = {z})`)
			end
			if x < 520 then
				break
			end
		end
		t.expect(crossedAt ~= nil, "it crossed the river")
		t.expect(sim.world.posX[tank] < 530, `it reached its staging field (x = {sim.world.posX[tank]})`)
	end)

	t.test("the map is the same every time", function()
		local again = MapRegistry.load("map:normandy") :: Layers.Layers
		t.expect(buffer.tostring(again.height) == buffer.tostring(layers.height), "heights")
		t.expect(buffer.tostring(again.waterDepth) == buffer.tostring(layers.waterDepth), "water")
		t.expect(buffer.tostring(again.terrain) == buffer.tostring(layers.terrain), "terrain")
	end)
end

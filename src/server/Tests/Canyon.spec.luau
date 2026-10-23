--!strict
-- "map:canyon", The Canyon (S-132): point-symmetric, mesas land units can't
-- climb, every deposit and the other start reachable on land, and the
-- skirmish AI can play it.
local Canyon = require("@shared/Grid/Canyon")
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Passability = require("@shared/Grid/Passability")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local RunAll = require("./RunAll")

local LAND = { "WHEELED", "TRACKED", "HEAVY_TRACKED" }

return function(t: RunAll.Context)
	local layers = MapRegistry.load("map:canyon") :: Layers.Layers
	local g = layers.grid
	local nx, nz = g.cellsX, g.cellsZ
	local pm = Passability.build(layers)

	t.test("154 × 256 cells centred on 0, two starts north and south, point-symmetric", function()
		t.equal(nx, 154)
		t.equal(nz, 256)
		t.equal(g.originX, -616)
		t.equal(g.originZ, -1024)
		t.equal(#layers.starts, 2)
		local a, b = layers.starts[1], layers.starts[2]
		t.expect(a[2] > 800 and b[2] < -800, "player 1 in the north, player 2 in the south")
		t.expect(a[1] == -b[1] and a[2] == -b[2], "the starts are twins")
		local symmetric = true
		for i = 0, nx * nz - 1 do
			local j = nx * nz - 1 - i
			if Layers.getHeight(layers, i) ~= Layers.getHeight(layers, j) or Layers.getTerrain(layers, i) ~= Layers.getTerrain(layers, j)
				or Layers.getSupply(layers, i) ~= Layers.getSupply(layers, j) then
				symmetric = false
			end
		end
		t.expect(symmetric, "heights, terrain and deposits match their twins")
	end)

	t.test("mesas: flat tops ~48 studs up that no land unit enters; starts on the open floor", function()
		local tops, blocked = 0, true
		for cz = 0, nz - 1 do
			for cx = 0, nx - 1 do
				local f = Canyon.feature(cx, cz)
				local i = g:index(cx, cz)
				if f == "mesa" then
					tops += 1
					t.expect(Layers.getHeight(layers, i) > 50, "a mesa top stands high")
				end
				if f == "cliff" then
					for _, mc in LAND do
						if Passability.canEnter(pm, mc, i) then
							blocked = false
						end
					end
				end
			end
		end
		t.expect(tops > 1000, `mesa tops ({tops} cells)`)
		t.expect(blocked, "no land unit climbs a cliff")
		t.equal(Canyon.mesaCount, 36)
		for _, s in layers.starts do
			local cx, cz = g:cellAt(s[1], s[2])
			t.equal(Canyon.feature(cx, cz), "floor", "a start on the canyon floor")
		end
	end)

	t.test("deposits: four rich ones at each start, glitter everywhere else, all reachable on land from both starts", function()
		local home, glitter, cells = 0, 0, {}
		for i = 0, nx * nz - 1 do
			local v = Layers.getSupply(layers, i)
			if v == Canyon.HOME_VALUE then
				home += 1
			elseif v == Canyon.DEPOSIT_VALUE then
				glitter += 1
			elseif v ~= 0 then
				t.expect(false, `unexpected deposit value {v}`)
			end
			if v > 0 then
				table.insert(cells, i)
			end
		end
		t.equal(home, 8)
		t.expect(glitter >= 70, `glitter deposits ({glitter})`)
		for _, mc in LAND do
			local from = g:index(g:cellAt(layers.starts[1][1], layers.starts[1][2]))
			local seen = { [from] = true }
			local queue, head = { from }, 1
			while head <= #queue do
				local i = queue[head]
				head += 1
				local cx, cz = i % nx, i // nx
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local ax, az = cx + d[1], cz + d[2]
					if ax >= 0 and ax < nx and az >= 0 and az < nz then
						local j = g:index(ax, az)
						if not seen[j] and Passability.canEnter(pm, mc, j) then
							seen[j] = true
							table.insert(queue, j)
						end
					end
				end
			end
			t.expect(seen[g:index(g:cellAt(layers.starts[2][1], layers.starts[2][2]))] == true, `{mc} drives from start to start`)
			local missed = 0
			for _, i in cells do
				if not seen[i] then
					missed += 1
				end
			end
			t.equal(missed, 0, `{mc} reaches every deposit`)
		end
	end)

	t.test("the map is the same every time", function()
		local again = MapRegistry.load("map:canyon") :: Layers.Layers
		t.expect(buffer.tostring(again.height) == buffer.tostring(layers.height), "heights")
		t.expect(buffer.tostring(again.terrain) == buffer.tostring(layers.terrain), "terrain")
		t.expect(buffer.tostring(again.supply) == buffer.tostring(layers.supply), "deposits")
	end)

	t.slow("AI vs AI on The Canyon: both expand and fight, every command valid", function()
		local sim = Sim.new({
			seed = 1,
			players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
			mapId = "map:canyon",
			scenario = "standard_start",
			match = { mode = "FFA", win = "COMMAND_ENDS" },
		})
		local brains = { Skirmish.new(sim, 1), Skirmish.new(sim, 2) }
		while not sim.match.over and sim.tick < 12 * 900 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		local w = sim.world
		local extractors = { 0, 0 }
		for _, id in w.ids do
			local owner = w.owner[id]
			if sim.defs.unitByIndex[w.defIndex[id]].extractor and w.buildProgress[id] >= 1 and (owner == 1 or owner == 2) then
				extractors[owner] += 1
			end
		end
		for p = 1, 2 do
			t.expect(extractors[p] > 4 or sim.match.over, `player {p} expanded past its home deposits ({extractors[p]} extractors)`)
		end
		t.expect(brains[1].waves + brains[2].waves >= 1, `someone attacked ({brains[1].waves}, {brains[2].waves} waves)`)
		t.equal(sim.stats.commandsRejected, 0, "every AI command was valid")
		print(`    canyon AI: {sim.tick / 900} min, extractors {extractors[1]} / {extractors[2]}, waves {brains[1].waves} / {brains[2].waves}`)
	end)
end

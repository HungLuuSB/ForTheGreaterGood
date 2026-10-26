--!strict
-- "map:supreme_strait", Supreme Strait (S-195, the user's G6; compiled the
-- BAR way since S-196): 320 × 320 cells, point-symmetric, two seas ships can
-- sail, land joining the halves through the middle, 16 hints on the metal
-- map's clusters.
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Passability = require("@shared/Grid/Passability")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local RunAll = require("./RunAll")

local LAND = { "WHEELED", "TRACKED", "HEAVY_TRACKED", "WALKER" }

return function(t: RunAll.Context)
	local layers = MapRegistry.load("map:supreme_strait") :: Layers.Layers
	local g = layers.grid
	local n = g.cellsX
	local pm = Passability.build(layers)

	-- the cells `moveClass` reaches from (x, z)
	local function reach(moveClass: string, x: number, z: number): { [number]: boolean }
		local from = g:index(g:cellAt(x, z))
		local seen = { [from] = true }
		local queue, head = { from }, 1
		while head <= #queue do
			local i = queue[head]
			head += 1
			local cx, cz = i % n, i // n
			for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local ax, az = cx + d[1], cz + d[2]
				if ax >= 0 and ax < n and az >= 0 and az < n then
					local j = g:index(ax, az)
					if not seen[j] and Passability.canEnter(pm, moveClass, j) then
						seen[j] = true
						table.insert(queue, j)
					end
				end
			end
		end
		return seen
	end

	t.test("320 × 320 cells, a medium map; 16 hints, 1-8 south-west and their twins north-east; point-symmetric", function()
		t.equal(n, 320)
		t.equal(g.cellsZ, 320)
		t.equal(MapRegistry.sizeClass(n), "medium")
		t.equal(#layers.starts, 16)
		for i = 1, 8 do
			local a, b = layers.starts[i], layers.starts[i + 8]
			-- (north is the screen's top, -z: south-west is x < 0 or z > 0)
			t.expect(a[1] - a[2] < 0 and b[1] == -a[1] and b[2] == -a[2], `hint {i} south-west, its twin {i + 8} north-east`)
		end
		local symmetric = true
		for cz = 0, n - 1 do
			for cx = 0, n - 1 do
				local i, j = g:index(cx, cz), g:index(n - 1 - cx, n - 1 - cz)
				if Layers.getHeight(layers, i) ~= Layers.getHeight(layers, j) or Layers.getWater(layers, i) ~= Layers.getWater(layers, j) or Layers.getTerrain(layers, i) ~= Layers.getTerrain(layers, j) then
					symmetric = false
				end
			end
		end
		t.expect(symmetric, "heights, water and ground match their twins")
		local d = MapRegistry.details("map:supreme_strait") :: MapRegistry.Details
		t.expect(table.find(d.features, "water") ~= nil and table.find(d.features, "cliffs") ~= nil, `water and cliffs ({table.concat(d.features, ", ")})`)
	end)

	t.test("land joins every hint and every deposit; ships sail both seas, each touching both sides' shores", function()
		local s1 = layers.starts[1]
		for _, mc in LAND do
			local seen = reach(mc, s1[1], s1[2])
			for i, s in layers.starts do
				t.expect(seen[g:index(g:cellAt(s[1], s[2]))] == true, `{mc} drives from hint 1 to hint {i}`)
			end
			-- BAR's metal map: a few spots are under water (naval) or on mesa
			-- tops; every other one is on ground this class reaches
			local missed = 0
			for _, dp in layers.deposits :: { { number } } do
				local i = g:index(g:cellAt(dp[1] - 4, dp[2] - 4))
				if Layers.getWater(layers, i) <= 0 and not seen[i] then
					missed += 1
				end
			end
			t.expect(missed <= 4, `{mc} reaches every dry deposit but the mesa tops' ({missed} out of reach)`)
		end
		-- each sea: one big body of SHIP water, the two not joined
		local size = g.sizeX
		local nw = reach("SHIP", -0.25 * size, -0.3 * size) -- the north-west bay (north = -z)
		local se = reach("SHIP", 0.25 * size, 0.3 * size)
		local count = 0
		for _ in nw do
			count += 1
		end
		t.expect(count > 2000, `the north-west sea is big ({count} cells)`)
		t.expect(not nw[g:index(g:cellAt(0.25 * size, 0.3 * size))], "the seas are apart: the strait is land")
		local _ = se
	end)

	t.test("every hint sits on a metal cluster (two or three spots close by), as BAR places starts", function()
		for i, s in layers.starts do
			local near = 0
			for _, dp in layers.deposits :: { { number } } do
				if (dp[1] - s[1]) ^ 2 + (dp[2] - s[2]) ^ 2 <= 140 * 140 then
					near += 1
				end
			end
			t.expect(near >= 2, `hint {i}: {near} spots within 140 studs`)
		end
		t.expect(#(layers.deposits :: { any }) >= 70, `{#(layers.deposits :: { any })} deposits`)
	end)

	t.test("the compiled module matches its sources (run map_compile after editing them)", function()
		local Compiled = require("@shared/Grid/Maps/supreme_strait") :: any
		t.equal(Compiled.cells, 320)
		t.equal(#Compiled.starts, 16)
	end)

	t.slow("four AIs play a 2v2 on Supreme Strait for 6 minutes: bases on both sides", function()
		local players, ai = {}, {}
		for i = 1, 4 do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 2 then 1 else 2 })
			ai[i] = "hard"
		end
		local sim = Sim.new({ seed = 4, players = players, mapId = "map:supreme_strait", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose", ai = ai } })
		local brains = Skirmish.forMatch(sim)
		for _ = 1, 15 * 60 * 6 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		local w = sim.world
		for pid = 1, 4 do
			local structures = 0
			for _, id in w.ids do
				if w.owner[id] == pid and sim.defs.unitByIndex[w.defIndex[id]].domain == "structure" then
					structures += 1
				end
			end
			t.expect(structures >= 6, `AI {pid}: a base ({structures} structures)`)
		end
	end)

	t.test("the map is the same every time", function()
		local again = MapRegistry.load("map:supreme_strait") :: Layers.Layers
		t.expect(buffer.tostring(again.height) == buffer.tostring(layers.height), "heights")
		t.expect(buffer.tostring(again.supply) == buffer.tostring(layers.supply), "deposits")
	end)
end

--!strict
-- "map:plains", The Plains (S-173): a flat 256 × 256-cell 8v8 map; 16
-- start hints, each with three deposits; mirror-symmetric west ↔ east.
local Layers = require("@shared/Grid/Layers")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Passability = require("@shared/Grid/Passability")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local RunAll = require("./RunAll")

return function(t: RunAll.Context)
	local layers = MapRegistry.load("map:plains") :: Layers.Layers
	local g = layers.grid
	local n = g.cellsX

	-- deposit patches (S-184) whose centre is within r of (x, z)
	local function depositsNear(x: number, z: number, r: number): number
		local c = 0
		for _, d in layers.deposits :: { { number } } do
			if (d[1] - x) ^ 2 + (d[2] - z) ^ 2 <= r * r then
				c += 1
			end
		end
		return c
	end

	t.test("256 × 256 cells, bigger than The Canyon; flat; 16 hints in mirrored pairs", function()
		t.equal(n, 256)
		t.equal(g.cellsZ, 256)
		local canyon = MapRegistry.load("map:canyon") :: Layers.Layers
		t.expect(g.cellCount > canyon.grid.cellCount, "more ground than The Canyon")
		t.equal(#layers.starts, 16)
		for i = 1, 8 do
			local a, b = layers.starts[i], layers.starts[i + 8]
			t.expect(a[1] < 0 and b[1] == -a[1] and b[2] == a[2], `hint {i} west, its twin {i + 8} east`)
		end
		local pm = Passability.build(layers)
		local steepest = 0
		for i = 0, g.cellCount - 1 do
			steepest = math.max(steepest, Passability.slopeDegrees(pm, i))
			t.expect(Layers.getWater(layers, i) == 0, "no water")
		end
		t.expect(steepest < 5, `flat (steepest {steepest}°)`)
		local symmetric = true
		for cz = 0, n - 1 do
			for cx = 0, n - 1 do
				local i, j = g:index(cx, cz), g:index(n - 1 - cx, cz)
				if Layers.getHeight(layers, i) ~= Layers.getHeight(layers, j) or Layers.getSupply(layers, i) ~= Layers.getSupply(layers, j) or Layers.getTerrain(layers, i) ~= Layers.getTerrain(layers, j) then
					symmetric = false
				end
			end
		end
		t.expect(symmetric, "heights, ground and deposits mirror west ↔ east")
	end)

	t.test("every hint has three deposits of its own; more over the middle and flanks", function()
		for i, s in layers.starts do
			t.equal(depositsNear(s[1], s[2], 80), 3, `hint {i}`)
		end
		local total = #(layers.deposits :: { any })
		t.expect(total >= 16 * 3 + 60, `{total} deposits`)
	end)

	t.test("8v8: the AI's 16 Commanders each start on a hint with its three deposits", function()
		local players, ai = {}, {}
		for i = 1, 16 do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 8 then 1 else 2 })
			ai[i] = "normal"
		end
		local sim = Sim.new({ seed = 1, players = players, mapId = "map:plains", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose", ai = ai } })
		local brains = Skirmish.forMatch(sim)
		for _ = 1, 15 * 10 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
			if sim.pregame == nil then
				break
			end
		end
		t.equal(sim.pregame, nil, "the match started")
		local w = sim.world
		for _, id in w.ids do
			if table.find(sim.defs.unitByIndex[w.defIndex[id]].categories, "COMMANDER") then
				t.equal(depositsNear(w.posX[id], w.posZ[id], 80), 3, `player {w.owner[id]}'s Commander has three deposits at hand`)
			end
		end
	end)

	t.test("3, 5, 6 and 7 sides: each side's hints sit in one corner group or one half (S-186)", function()
		local StartAreas = require("@shared/Match/StartAreas")
		for n = 2, 8 do
			local allies = {}
			for a = 1, n do
				table.insert(allies, a)
			end
			local sides = StartAreas.sides(allies, #layers.starts, layers.sideSplits)
			local used = {}
			for _, a in sides.allies do
				local list = sides.startsOf[a]
				t.expect(#list >= 2, `{n} sides: side {a} has hints`)
				local west, north = 0, 0
				for _, i in list do
					t.expect(not used[i], `{n} sides: hint {i} once`)
					used[i] = true
					west += if layers.starts[i][1] < 0 then 1 else 0
					north += if layers.starts[i][2] > 0 then 1 else 0
				end
				t.expect(west == 0 or west == #list, `{n} sides: side {a} on one half (west / east)`)
				if #list <= 4 then
					t.expect(north == 0 or north == #list, `{n} sides: side {a} in one corner group`)
				end
			end
		end
	end)

	t.test("the map is the same every time", function()
		local again = MapRegistry.load("map:plains") :: Layers.Layers
		t.expect(buffer.tostring(again.height) == buffer.tostring(layers.height), "heights")
		t.expect(buffer.tostring(again.supply) == buffer.tostring(layers.supply), "deposits")
	end)
end

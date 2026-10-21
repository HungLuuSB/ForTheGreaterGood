--!strict
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Prng = require("@shared/Util/Prng")
local Schema = require("@shared/Net/Schema")
local Nav = require("../Sim/Nav")
local Quadtree = require("../Sim/Path/Quadtree")
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local OVERLAP_TOLERANCE = 0.5 -- studs of allowed interpenetration at rest

local function encode(cmd: Schema.Command): buffer
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	return w:finish()
end

-- Open cell near the east edge's middle, in the component of the first unit,
-- with room around it (clearance >= 3).
local function eastTarget(sim: Sim.Sim): number
	local nav = sim.nav :: Nav.Nav
	local g = nav.grid
	local w = sim.world
	local tree = Nav.tree(nav, "TRACKED", 1)
	local ux, uz = g:cellAt(w.posX[w.ids[1]], w.posZ[w.ids[1]])
	local comp = Quadtree.component(tree, g:index(ux, uz))
	for cx = g.cellsX - 6, 0, -1 do
		for dz = 0, g.cellsZ // 2 - 1 do
			for _, cz in { g.cellsZ // 2 + dz, g.cellsZ // 2 - dz - 1 } do
				local c = g:index(cx, cz)
				if Quadtree.component(tree, c) == comp and Passability.clearance(nav.pm, "TRACKED", c) >= 3 then
					return c
				end
			end
		end
	end
	error("no target")
end

local function allIdle(w: World.World): boolean
	for _, id in w.ids do
		if w.orderId[id] ~= 0 then
			return false
		end
	end
	return true
end

-- 50 Lancers march west → east. Returns the sim, the tick all were idle (or
-- nil), and each unit's slot as assigned when the order was issued.
local function march(mapId: string, maxTicks: number): (Sim.Sim, number?, { [number]: { number } })
	local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = mapId })
	local target = eastTarget(sim)
	assert(Sim.submit(sim, 1, encode({ cmdType = CT.MOVE, flags = 0, unitIds = table.clone(sim.world.ids), cell = target, offX = 128, offZ = 128 })))
	Sim.step(sim)
	local slots = {}
	for _, id in sim.world.ids do
		slots[id] = { sim.world.goalX[id], sim.world.goalZ[id] }
	end
	for _ = 2, maxTicks do
		Sim.step(sim)
		if allIdle(sim.world) then
			return sim, sim.tick, slots
		end
	end
	return sim, nil, slots
end

local function closestPair(sim: Sim.Sim): (number, number, number)
	local w = sim.world
	local nav = sim.nav :: Nav.Nav
	local worst, a, b = math.huge, 0, 0
	for i, id in w.ids do
		local ri = nav.profiles[w.defIndex[id]].radius
		for j = i + 1, #w.ids do
			local other = w.ids[j]
			local rj = nav.profiles[w.defIndex[other]].radius
			local d = math.sqrt((w.posX[id] - w.posX[other]) ^ 2 + (w.posZ[id] - w.posZ[other]) ^ 2)
			local slack = d - (ri + rj) -- negative = overlap
			if slack < worst then
				worst, a, b = slack, id, other
			end
		end
	end
	return worst, a, b
end

-- Every unit finished its order on open ground within ARRIVAL_SPREAD studs of
-- the slot it was given (GIVE_UP_RANGE lets a unit stop short of a crowded
-- slot), and no two units overlap beyond the tolerance.
local ARRIVAL_SPREAD = 24
local function checkArrival(t: RunAll.Context, sim: Sim.Sim, slots: { [number]: { number } }, label: string)
	local w = sim.world
	local nav = sim.nav :: Nav.Nav
	local worst = 0
	for _, id in w.ids do
		t.equal(w.orderId[id], 0, `{label}: unit {id} never finished`)
		local slot = slots[id]
		local d = math.sqrt((slot[1] - w.posX[id]) ^ 2 + (slot[2] - w.posZ[id]) ^ 2)
		worst = math.max(worst, d)
		t.expect(d <= ARRIVAL_SPREAD, `{label}: unit {id} stopped {d} studs from its slot`)
		t.expect(Nav.fits(nav, nav.profiles[w.defIndex[id]], w.posX[id], w.posZ[id]), `{label}: unit {id} ended on blocked ground`)
	end
	local slack, a, b = closestPair(sim)
	t.expect(slack >= -OVERLAP_TOLERANCE, `{label}: units {a} and {b} overlap by {-slack} studs`)
	return worst
end

-- The original O(slots × units) greedy, as the reference for Nav.assignSlots.
local function bruteAssign(w: World.World, members: { number }, slots: { { number } }): { number }
	local taken: { [number]: boolean } = {}
	local pick = {}
	for i, slot in slots do
		local best, bestD = 0, math.huge
		for _, id in members do -- ascending IDs: strict < keeps the lower ID on ties
			if not taken[id] then
				local d = (w.posX[id] - slot[1]) ^ 2 + (w.posZ[id] - slot[2]) ^ 2
				if d < bestD then
					best, bestD = id, d
				end
			end
		end
		pick[i] = best
		if best ~= 0 then
			taken[best] = true
		end
	end
	return pick
end

return function(t: RunAll.Context)
	t.test("bucketed slot assignment matches the brute-force greedy exactly", function()
		local rng = Prng.new(31)
		for case = 1, 60 do
			local w = World.new()
			local members = {}
			local units = rng:nextInteger(1, 200)
			local spread = rng:nextNumber(5, 400)
			local cx, cz = rng:nextNumber(-500, 500), rng:nextNumber(-500, 500)
			for i = 1, units do
				local x, z
				if i > 1 and rng:chance(0.1) then
					-- exact duplicate positions: ties must go to the lower ID
					local other = members[rng:nextInteger(1, #members)]
					x, z = w.posX[other], w.posZ[other]
				else
					x, z = cx + rng:nextNumber(-spread, spread), cz + rng:nextNumber(-spread, spread)
				end
				table.insert(members, World.spawn(w, 0, { defIndex = 1, team = 1, owner = 1, x = x, z = z, health = 1 }))
			end
			table.sort(members)
			local slots = {}
			local nSlots = rng:nextInteger(1, units + 20) -- sometimes more slots than units
			local sx, sz = rng:nextNumber(-900, 900), rng:nextNumber(-900, 900)
			for _ = 1, nSlots do
				if rng:chance(0.1) then
					table.insert(slots, { w.posX[members[1]], w.posZ[members[1]] }) -- a slot on a unit
				else
					table.insert(slots, { sx + rng:nextNumber(-120, 120), sz + rng:nextNumber(-120, 120) })
				end
			end
			t.deepEqual((Nav.assignSlots(w, members, slots)), bruteAssign(w, members, slots), `case {case} ({units} units, {nSlots} slots)`)
		end
	end)

	t.test("50 units cross a lake map, all arrive, no overlaps", function()
		local sim, doneAt, slots = march("gen:7:96", 2000)
		t.expect(doneAt ~= nil, "units still moving after 2,000 ticks")
		t.equal(World.count(sim.world), 50)
		checkArrival(t, sim, slots, "gen:7:96")
	end)

	t.test("50 units detour through the gap in a wall", function()
		local sim, doneAt, slots = march("wall:96", 2000)
		t.expect(doneAt ~= nil, "units still moving after 2,000 ticks")
		checkArrival(t, sim, slots, "wall:96")
		-- Everyone ended east of the wall, so everyone went through the gap.
		local g = (sim.nav :: Nav.Nav).grid
		for _, id in sim.world.ids do
			local cx = g:cellAt(sim.world.posX[id], 0)
			t.expect(cx > g.cellsX // 2 + 1, `unit {id} is still west of the wall`)
		end
	end)

	t.test("one move order shares one field", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = "gen:7:96" })
		local target = eastTarget(sim)
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.MOVE, flags = 0, unitIds = table.clone(sim.world.ids), cell = target, offX = 0, offZ = 0 })))
		Sim.step(sim)
		local w = sim.world
		local orderId = w.orderId[w.ids[1]]
		for _, id in w.ids do
			t.equal(w.orderId[id], orderId, "all units in one order")
		end
		for _ = 1, 30 do
			Sim.step(sim)
		end
		local nav = sim.nav :: Nav.Nav
		t.equal(nav.stats.fieldsBuilt, 1, "one field for the whole group")
		-- Each unit still has its own distinct goal (formation slot).
		local seen = {}
		for _, id in w.ids do
			local key = `{w.goalX[id]},{w.goalZ[id]}`
			t.expect(not seen[key], "two units share a slot")
			seen[key] = true
		end
	end)

	t.test("same seed, same final positions and hash; replay reproduces it", function()
		local a = march("wall:64", 1500)
		local b = march("wall:64", 1500)
		t.equal(Sim.hash(a), Sim.hash(b))
		for _, id in a.world.ids do
			t.equal(a.world.posX[id], b.world.posX[id])
			t.equal(a.world.posZ[id], b.world.posZ[id])
		end
		local log = Replay.parse(Replay.serialize(a.replay))
		local replayed, mismatch = Sim.runReplay(log, a.tick)
		t.equal(mismatch, nil)
		t.equal(Sim.hash(replayed), Sim.hash(a))
	end)

	t.test("line move spreads goals evenly along the line", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = "flat:64" })
		local w = sim.world
		local g = (sim.nav :: Nav.Nav).grid
		local ten = table.move(w.ids, 1, 10, 1, {})
		local ax, az = g:cellCenter(40, 20)
		local bx, bz = g:cellCenter(40, 44)
		local cellA, offAx, offAz = g:encode(ax, az)
		local cellB, offBx, offBz = g:encode(bx, bz)
		assert(Sim.submit(sim, 1, encode({
			cmdType = CT.MOVE,
			flags = Schema.CmdFlag.LINE,
			unitIds = ten,
			cell = cellA,
			offX = offAx,
			offZ = offAz,
			cell2 = cellB,
			offX2 = offBx,
			offZ2 = offBz,
		})))
		Sim.step(sim)
		local goals = {}
		for _, id in ten do
			table.insert(goals, { w.goalX[id], w.goalZ[id] })
			t.expect(math.abs(w.goalX[id] - ax) < 1e-6, "goal on the line (x)")
		end
		table.sort(goals, function(p, q)
			return p[2] < q[2]
		end)
		t.expect(math.abs(goals[1][2] - az) < 1e-6 and math.abs(goals[10][2] - bz) < 1e-6, "goals span the whole line")
		local step = (bz - az) / 9
		for i = 2, 10 do
			t.expect(math.abs(goals[i][2] - goals[i - 1][2] - step) < 1e-6, "even spacing")
		end
		for _ = 1, 900 do
			Sim.step(sim)
		end
		for _, id in ten do
			t.equal(w.orderId[id], 0, `unit {id} still moving`)
			local d = math.sqrt((w.goalX[id] - w.posX[id]) ^ 2 + (w.goalZ[id] - w.posZ[id]) ^ 2)
			t.expect(d <= Nav.ARRIVE_RADIUS + 0.5, `unit {id} is {d} studs from its slot`)
		end
	end)

	t.test("a goal in water snaps to the nearest open ground", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = "wall:64" })
		local nav = sim.nav :: Nav.Nav
		local g = nav.grid
		local five = table.move(sim.world.ids, 1, 5, 1, {})
		local waterCell = g:index(32, 40) -- inside the wall
		assert(not Passability.canEnter(nav.pm, "TRACKED", waterCell))
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.MOVE, flags = 0, unitIds = five, cell = waterCell, offX = 0, offZ = 0 })))
		for _ = 1, 900 do
			Sim.step(sim)
		end
		for _, id in five do
			local p = nav.profiles[sim.world.defIndex[id]]
			t.expect(Nav.fits(nav, p, sim.world.goalX[id], sim.world.goalZ[id]), "goal on open ground")
			t.equal(sim.world.orderId[id], 0, "arrived")
		end
	end)

	t.test("STOP ends orders; out-of-map cells are ignored", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = "flat:32" })
		local w = sim.world
		local ids = table.clone(w.ids)
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.MOVE, flags = 0, unitIds = ids, cell = 32 * 32 - 1, offX = 0, offZ = 0 })))
		Sim.step(sim)
		t.expect(w.orderId[ids[1]] ~= 0, "moving")
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.STOP, flags = 0, unitIds = ids })))
		Sim.step(sim)
		t.expect(allIdle(w), "STOP clears every order")
		for _ = 1, 30 do
			Sim.step(sim)
		end
		for _, id in ids do
			t.equal(w.speed[id], 0, "stopped units brake to 0")
		end
		local before = Sim.hash(sim)
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.MOVE, flags = 0, unitIds = ids, cell = 60000, offX = 0, offZ = 0 })))
		Sim.step(sim)
		t.expect(allIdle(w), "a cell outside the map is ignored")
		t.notEqual(Sim.hash(sim), before, "(only the tick changed)")
	end)

	t.test("idle units cost nothing: no dirty bits and no packets without movement", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, scenario = "march_test", mapId = "flat:32" })
		local w = sim.world
		-- camera over the whole map: every unit enters the tactical tier on tick 1
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 31, maxZ = 31 })))
		Sim.step(sim)
		local outbox = sim.net.players[1].outbox
		t.equal(#outbox.Events, 1, "ENTER events on the first tick")
		-- tick 2 is the first sensor pass: the team's sight appears (S-26)
		Sim.step(sim)
		local sight = 0
		for _, msg in outbox.Events do
			for _, e in (Packer.readAll(msg, Schema.decodeEvent, Schema.decodeTickHeader)) do
				t.expect(e.kind == Schema.EventKind.SIGHT_CELLS or e.kind == Schema.EventKind.SIGHT_ROWS, `only sight on tick 2, got event kind {e.kind}`)
				sight += 1
			end
		end
		t.expect(sight > 0, "the first sensor pass sends the team's sight")
		local dirtySeen = false
		for _ = 1, 10 do
			-- dirty bits are cleared by NetOut at the end of each tick; any set
			-- during the tick would show up as tactical or state records
			Sim.step(sim)
			for _, ch in { "Tactical", "State", "Events" } do
				t.equal(#outbox[ch], 0, `idle units produced {ch} messages on tick {sim.tick}`)
			end
			for _, id in w.ids do
				dirtySeen = dirtySeen or w.dirty[id] ~= 0
			end
		end
		t.expect(not dirtySeen, "no dirty bits left after NetOut")
	end)

	-- client request 14: MOVING is set while a unit moves (aircraft: unless
	-- landed) and cleared when it stops; the client sees it in State records
	t.test("the MOVING state bit follows movement and reaches the client", function()
		local Client = require("./Support/Client")
		local Spawn = require("../Sim/Spawn")
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64" })
		local w = sim.world
		local MOVING = World.State.MOVING
		local tank = Spawn.unit(sim, "ord_lancer", 1, -100, 0, 0)
		local jet = Spawn.unit(sim, "ord_falcon", 1, 100, 0, 0)
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 63, maxZ = 63 })))
		local view = Client.new((sim.map :: any).grid)
		local function step(n: number)
			for _ = 1, n do
				Sim.step(sim)
				Client.receive(view, sim.net.players[1].outbox)
			end
		end
		step(3)
		t.equal(bit32.band(w.state[tank], MOVING), 0, "an idle tank isn't moving")
		t.expect(bit32.band(w.state[jet], MOVING) ~= 0, "a flying jet is (it loiters)")
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(-20, 0)
		assert(Sim.submit(sim, 1, encode({ cmdType = CT.MOVE, flags = 0, unitIds = { tank }, cell = cell, offX = ox, offZ = oz })))
		step(2)
		t.expect(bit32.band(w.state[tank], MOVING) ~= 0, "moving after a move order")
		t.expect(bit32.band(view.units[tank].state :: number, MOVING) ~= 0, "and the client knows")
		for _ = 1, 300 do
			step(1)
			if w.orderId[tank] == 0 and w.speed[tank] == 0 then
				break
			end
		end
		step(1)
		t.equal(bit32.band(w.state[tank], MOVING), 0, "cleared once it stopped")
		t.equal(bit32.band(view.units[tank].state :: number, MOVING), 0, "on the client too")
		World.setState(w, jet, bit32.bor(w.state[jet], World.State.LANDED))
		step(1)
		t.equal(bit32.band(w.state[jet], MOVING), 0, "a landed aircraft isn't moving")
	end)
end

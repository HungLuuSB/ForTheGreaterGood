--!strict
-- Big orders spread over ticks (S-100, next.md item 3): a player's commands
-- apply until Commands.UNITS_PER_TICK unit IDs per tick, the rest wait in
-- order. The difference is timing only.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Commands = require("../Sim/Systems/Commands")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

-- 600 Lancers for player 1 in a block, and a few for player 2.
local function army(seed: number): (Sim.Sim, { number }, { number })
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:128" })
	local mine, theirs = {}, {}
	for i = 0, 599 do
		table.insert(mine, Spawn.unit(sim, "ord_lancer", 1, -350 + (i % 30) * 14, -300 + (i // 30) * 14, 0))
	end
	for i = 0, 4 do
		table.insert(theirs, Spawn.unit(sim, "chs_ravager", 2, 350, -40 + i * 20, 0))
	end
	return sim, mine, theirs
end

-- The move commands for `ids` toward (x, z), in chunks of 200.
local function moves(sim: Sim.Sim, ids: { number }, x: number, z: number): { Schema.Command }
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local out = {}
	for i = 1, #ids, 200 do
		table.insert(out, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = table.move(ids, i, math.min(i + 199, #ids), 1, {}), cell = cell, offX = ox, offZ = oz })
	end
	return out
end

local function ordered(sim: Sim.Sim, ids: { number }): number
	local n = 0
	for _, id in ids do
		if sim.orders.queue[id] then
			n += 1
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("a 600-unit order starts over 3 ticks; another player's command doesn't wait", function()
		local sim, mine, theirs = army(1)
		for _, cmd in moves(sim, mine, 200, 200) do
			submit(sim, 1, cmd)
		end
		for _, cmd in moves(sim, theirs, 0, 0) do
			submit(sim, 2, cmd)
		end
		Sim.step(sim)
		t.equal(ordered(sim, mine), 200, "200 the first tick")
		t.equal(ordered(sim, theirs), 5, "player 2's order went at once")
		Sim.step(sim)
		t.equal(ordered(sim, mine), 400, "400 the second")
		Sim.step(sim)
		t.equal(ordered(sim, mine), 600, "all 600 the third")
		t.equal(#sim.queue, 0, "nothing left waiting")
	end)

	t.test("a later command waits behind the spread order: STOP still comes last", function()
		local sim, mine = army(2)
		for _, cmd in moves(sim, mine, 200, 200) do
			submit(sim, 1, cmd)
		end
		Sim.step(sim)
		submit(sim, 1, { cmdType = Schema.CmdType.STOP, flags = 0, unitIds = table.move(mine, 1, 200, 1, {}) })
		for _ = 1, 4 do
			Sim.step(sim)
		end
		t.equal(ordered(sim, table.move(mine, 1, 200, 1, {})), 0, "the first 200 stopped")
		t.equal(ordered(sim, table.move(mine, 401, 600, 1, {})), 200, "the last 200 still moving: the STOP came after their move")
	end)

	t.test("timing only: the spread order's state hash equals the chunks sent a tick apart", function()
		local a, mineA = army(3)
		for _, cmd in moves(a, mineA, 250, 150) do
			submit(a, 1, cmd)
		end
		local b, mineB = army(3)
		local saved = Commands.UNITS_PER_TICK
		Commands.UNITS_PER_TICK = math.huge
		local ok, err = pcall(function()
			local chunks = moves(b, mineB, 250, 150)
			for tick = 1, 120 do
				if chunks[tick] then
					submit(b, 1, chunks[tick])
				end
				Sim.step(b)
			end
		end)
		Commands.UNITS_PER_TICK = saved
		assert(ok, err)
		for _ = 1, 120 do
			Sim.step(a)
		end
		t.equal(Sim.hash(a), Sim.hash(b), "same state after 8 s")
		-- replays: each chunk is recorded on the tick it was applied, so a
		-- replay feeds them a tick apart and nothing waits there
		local ticks = {}
		for _, e in a.replay.entries do
			if e.player == 1 then
				table.insert(ticks, e.tick)
			end
		end
		t.deepEqual(ticks, { 1, 2, 3 }, "recorded on ticks 1, 2, 3")
	end)
end

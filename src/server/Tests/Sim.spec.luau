--!strict
local Packer = require("@shared/Net/Packer")
local Prng = require("@shared/Util/Prng")
local Profiler = require("@shared/Util/Profiler")
local Schema = require("@shared/Net/Schema")
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function encode(cmd: Schema.Command): buffer
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	return w:finish()
end

-- Feeds random commands from both players, mostly for their own units but
-- sometimes for the enemy's (which must be ignored). The driver has its own
-- PRNG and only reads sim state, so it is as deterministic as the sim.
local function drive(sim: Sim.Sim, driver: Prng.Prng)
	if not driver:chance(0.4) then
		return
	end
	local player = driver:nextInteger(1, 2)
	local ids = sim.world.ids
	local unitIds = {}
	for _ = 1, driver:nextInteger(1, 5) do
		table.insert(unitIds, ids[driver:nextInteger(1, #ids)])
	end
	local kind = driver:nextInteger(1, 4)
	local cmd: Schema.Command
	if kind == 1 then
		cmd = { cmdType = CT.SET_FIRE_STATE, flags = 0, unitIds = unitIds, value = driver:nextInteger(0, 2) }
	elseif kind == 2 then
		cmd = { cmdType = CT.SET_MOVE_STATE, flags = 0, unitIds = unitIds, value = driver:nextInteger(0, 2) }
	elseif kind == 3 then
		cmd = { cmdType = CT.TOGGLE, flags = 0, unitIds = unitIds, value = driver:nextInteger(0, 1) }
	else
		cmd = { cmdType = CT.MOVE, flags = 0, unitIds = unitIds, cell = driver:nextInteger(0, 65535), offX = 0, offZ = 0 }
	end
	local ok, err = Sim.submit(sim, player, encode(cmd))
	assert(ok, err)
end

local function run(seed: number, driverSeed: number, ticks: number): Sim.Sim
	local sim = Sim.new({ seed = seed, players = PLAYERS, scenario = "skirmish_test", mapId = "none" })
	local driver = Prng.new(driverSeed)
	for _ = 1, ticks do
		drive(sim, driver)
		Sim.step(sim)
	end
	return sim
end

return function(t: RunAll.Context)
	t.test("system order matches guide 3.3", function()
		t.deepEqual(Sim.SYSTEM_ORDER, {
			"Sim.Commands",
			"Sim.Economy",
			"Sim.Sensors",
			"Sim.Targeting",
			"Sim.Pathing",
			"Sim.Movement",
			"Sim.Weapons",
			"Sim.Projectiles",
			"Sim.Damage",
			"Sim.Construction",
			"Sim.NetOut",
		})
	end)

	t.test("1,000 ticks twice with the same seed give identical hashes", function()
		local started = Profiler.now()
		local a = run(12345, 99, 1000)
		local elapsed = Profiler.now() - started
		local b = run(12345, 99, 1000)
		t.equal(a.tick, 1000)
		t.equal(World.count(a.world), 20)
		t.expect(a.stats.commandsApplied > 300, `only {a.stats.commandsApplied} commands applied`)
		local cpA, cpB = Replay.checkpoints(a.replay), Replay.checkpoints(b.replay)
		t.equal(#cpA, 3, "checkpoints at 300, 600, 900")
		t.deepEqual(cpA, cpB)
		t.equal(Sim.hash(a), Sim.hash(b))
		t.notEqual(cpA[1][2], cpA[2][2], "commands change the world between checkpoints")
		t.expect(elapsed < 5, `1,000 headless ticks took {elapsed} s`)
	end)

	t.test("a different seed gives a different hash", function()
		t.notEqual(Sim.hash(run(12345, 99, 300)), Sim.hash(run(12346, 99, 300)))
	end)

	t.test("replay reproduces the run exactly", function()
		local original = run(777, 5, 1000)
		local log = Replay.parse(Replay.serialize(original.replay))
		local replayed, mismatch = Sim.runReplay(log, 1000)
		t.equal(mismatch, nil, "checkpoint mismatch")
		t.equal(replayed.tick, 1000)
		t.equal(Sim.hash(replayed), Sim.hash(original))
		t.equal(buffer.tostring(Replay.serialize(replayed.replay)), buffer.tostring(Replay.serialize(original.replay)), "replaying records the identical log")
	end)

	t.test("an extra command in the replay is caught at the next checkpoint", function()
		local original = run(777, 5, 700)
		-- Find a unit of player 1 and its fire state just before tick 600, then
		-- inject a command (applied on tick 600) that sets a different value.
		local before = run(777, 5, 599)
		local unit, current
		for _, id in before.world.ids do
			if before.world.owner[id] == 1 then
				unit, current = id, before.world.fireState[id]
				break
			end
		end
		local injected = encode({ cmdType = CT.SET_FIRE_STATE, flags = 0, unitIds = { unit }, value = (current + 1) % 3 })
		local log = Replay.parse(Replay.serialize(original.replay))
		local at = #log.entries + 1
		for i, e in log.entries do
			if e.tick >= 600 then
				at = i
				break
			end
		end
		table.insert(log.entries, at, { kind = Replay.Kind.COMMAND, tick = 600, player = 1, payload = injected })
		local _, mismatch = Sim.runReplay(log, 700)
		t.equal(mismatch, 600)
	end)

	t.test("a corrupted checkpoint hash is reported", function()
		local log = Replay.parse(Replay.serialize(run(777, 5, 700).replay))
		for _, e in log.entries do
			if e.kind == Replay.Kind.CHECKPOINT and e.tick == 300 then
				e.hash = ((e.hash :: number) + 1) % 2 ^ 32
			end
		end
		local _, mismatch = Sim.runReplay(log, 700)
		t.equal(mismatch, 300)
	end)

	t.test("replays from another protocol or def set are refused", function()
		local log = Replay.parse(Replay.serialize(run(1, 1, 1).replay))
		log.header.defsHash += 1
		t.throws(function()
			Sim.fromReplay(log)
		end, "defs hash")
		log.header.defsHash -= 1
		log.header.protocolVersion += 1
		t.throws(function()
			Sim.fromReplay(log)
		end, "protocol")
	end)

	t.test("submit drops malformed payloads and unknown players", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS })
		local ok, err = Sim.submit(sim, 9, encode({ cmdType = CT.STOP, flags = 0, unitIds = { 1 } }))
		t.expect(not ok and string.find(err :: string, "unknown player 9", 1, true) ~= nil, tostring(err))
		ok, err = Sim.submit(sim, 1, buffer.fromstring("\7\0"))
		t.expect(not ok and string.find(err :: string, "truncated", 1, true) ~= nil, tostring(err))
		ok, err = Sim.submit(sim, 1, buffer.fromstring("\7\0\1\0\1\0\0"))
		t.expect(not ok and string.find(err :: string, "trailing", 1, true) ~= nil, tostring(err))
		ok, err = Sim.submit(sim, 1, ("not a buffer" :: any) :: buffer)
		t.expect(not ok and string.find(err :: string, "expected a buffer", 1, true) ~= nil, tostring(err))
		t.equal(sim.stats.commandsRejected, 4)
		t.equal(#sim.queue, 0)
	end)

	t.test("commands affect only the sender's own units", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, scenario = "skirmish_test" })
		local w = sim.world
		local mine, theirs
		for _, id in w.ids do
			if w.owner[id] == 1 and not mine then
				mine = id
			elseif w.owner[id] == 2 and not theirs then
				theirs = id
			end
		end
		local cmd = { cmdType = CT.SET_FIRE_STATE, flags = 0, unitIds = { mine, theirs, 60000 }, value = 0 }
		assert(Sim.submit(sim, 1, encode(cmd)))
		Sim.step(sim)
		t.equal(w.fireState[mine], World.FireState.HOLD_FIRE)
		t.equal(w.fireState[theirs], World.FireState.FIRE_AT_WILL, "enemy unit untouched")
		t.equal(#sim.replay.entries, 1, "the command is recorded once")
		t.equal(sim.replay.entries[1].tick, 1)
	end)

	t.test("config is validated", function()
		t.throws(function()
			Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 1, team = 2 } } })
		end, "unique")
		t.throws(function()
			Sim.new({ seed = 1, players = { { id = 1, team = 9 } } })
		end, "team must be")
		t.throws(function()
			Sim.new({ seed = 1, players = PLAYERS, scenario = "nope" })
		end, "unknown scenario")
	end)
end

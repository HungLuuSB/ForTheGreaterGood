--!strict
-- The pre-game (S-169, the user): startMode "choose": players pick their
-- starts in their side's area, queue builds for their Commander, ready up;
-- a 5..1 countdown, then the match. Up to 16 players on any map.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local StartAreas = require("@shared/Match/StartAreas")
local Layers = require("@shared/Grid/Layers")
local NetOut = require("../Sim/NetOut")
local Pregame = require("../Sim/Pregame")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function pick(sim: Sim.Sim, player: number, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	submit(sim, player, { cmdType = CT.START_POS, flags = 0, unitIds = {}, cell = cell, offX = ox, offZ = oz })
end

local function ready(sim: Sim.Sim, player: number, on: boolean)
	submit(sim, player, { cmdType = CT.READY, flags = 0, unitIds = {}, value = if on then 1 else 0 })
end

-- `n` players on two sides (odd IDs west on Ridgeline, even ones east)
local function newMatch(n: number, mapId: string?, ai: { [number]: string }?): Sim.Sim
	local players = {}
	for i = 1, n do
		table.insert(players, { id = i, team = i, allyTeam = if i <= n // 2 then 1 else 2 })
	end
	return Sim.new({ seed = 3, players = players, mapId = mapId or "map:ridgeline", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose", ai = ai } })
end

local function commanderOf(sim: Sim.Sim, player: number): number
	local w = sim.world
	for _, id in w.ids do
		if w.owner[id] == player and table.find(sim.defs.unitByIndex[w.defIndex[id]].categories, "COMMANDER") then
			return id
		end
	end
	return 0
end

return function(t: RunAll.Context)
	t.test("start areas: sides share the map's starts in blocks; a point belongs to the nearest start's side", function()
		local sides = StartAreas.sides({ 2, 1 }, 4)
		t.deepEqual(sides.allies, { 1, 2 })
		t.deepEqual(sides.startsOf[1], { 1, 2 })
		t.deepEqual(sides.startsOf[2], { 3, 4 })
		t.deepEqual(StartAreas.sides({ 1, 2, 3, 4 }, 4).startsOf[3], { 3 })
		t.throws(function()
			StartAreas.sides({ 1, 2, 3 }, 2)
		end, "3 sides for 2 starts")
		local starts = { { -500, 0 }, { 500, 0 } }
		local two = StartAreas.sides({ 1, 2 }, 2)
		t.equal(StartAreas.sideAt(two, starts, -10, 300), 1, "west of the middle: side 1")
		t.equal(StartAreas.sideAt(two, starts, 10, -300), 2, "east: side 2")
		local s = StartAreas.suggestions(two, starts, 1, 1, 1)
		t.deepEqual(s[1], { -500, 0 }, "the start first")
		t.equal(#s, 7, "then a ring of 6")
	end)

	t.test("the pre-game: no units, only commands; picks in your own area, spaced, on standable ground", function()
		local sim = newMatch(2)
		t.expect(sim.pregame ~= nil, "a pre-game")
		t.equal(#sim.world.ids, 0, "no units yet")
		local starts = (sim.map :: any).layers.starts
		local west, east = starts[1], starts[2]
		pick(sim, 1, west[1], west[2])
		pick(sim, 2, west[1] + 100, west[2]) -- in the other side's area
		Sim.step(sim)
		t.deepEqual(sim.pregame.picks[1], { west[1], west[2] }, "player 1 picked its start")
		t.equal(sim.pregame.picks[2], nil, "player 2 can't pick in side 1's area")
		pick(sim, 2, east[1], east[2])
		Sim.step(sim)
		t.expect(sim.pregame.picks[2] ~= nil, "in its own area it can")
		t.equal(#sim.world.ids, 0, "still no units")
		local before = sim.tick
		for _ = 1, 30 do
			Sim.step(sim)
		end
		t.equal(sim.tick, before + 30, "ticks advance")
		t.equal(sim.match.eliminated[1], nil, "nobody is eliminated for lack of a Commander")
		-- spacing: a 3-player side can't stack picks
		local three = newMatch(6, "map:twin_lakes")
		local s1 = (three.map :: any).layers.starts[1]
		pick(three, 1, s1[1], s1[2])
		pick(three, 2, s1[1] + 20, s1[2])
		Sim.step(three)
		t.expect(three.pregame.picks[1] ~= nil and three.pregame.picks[2] == nil, "the second pick within 48 studs is refused")
		t.expect(Pregame.validPick(three, 2, s1[1] + 60, s1[2]), "60 studs away is fine")
	end)

	t.test("all ready: a 5 s countdown, then the Commanders stand on their picks and take their queues", function()
		local sim = newMatch(2)
		local g = (sim.map :: any).grid
		local starts = (sim.map :: any).layers.starts
		local p1 = { starts[1][1] + 30, starts[1][2] + 40 }
		pick(sim, 1, p1[1], p1[2])
		-- player 1 queues two generators for its Commander
		local gen = sim.defs.units.ord_generator.index
		for k, off in { 60, 90 } do
			local cell, ox, oz = g:encode(p1[1] + off, p1[2])
			submit(sim, 1, { cmdType = CT.BUILD, flags = if k > 1 then Schema.CmdFlag.QUEUE else 0, unitIds = {}, defIndex = gen, cell = cell, offX = ox, offZ = oz, facing = 0 })
		end
		ready(sim, 1, true)
		Sim.step(sim)
		t.equal(#sim.pregame.builds[1], 2, "two builds queued")
		t.equal(sim.pregame.phase, "pick", "player 2 isn't ready")
		ready(sim, 2, true)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "countdown", "everyone ready: the countdown")
		local readyTick = sim.tick
		while sim.pregame do
			Sim.step(sim)
		end
		t.equal(sim.tick - readyTick, Pregame.COUNTDOWN, "5 s later the match starts")
		t.equal(sim.match.startTick, sim.tick)
		local c1, c2 = commanderOf(sim, 1), commanderOf(sim, 2)
		t.expect(c1 ~= 0 and c2 ~= 0, "both Commanders")
		t.expect(math.abs(sim.world.posX[c1] - p1[1]) < 1 and math.abs(sim.world.posZ[c1] - p1[2]) < 1, "player 1's on its pick")
		local q = sim.orders.queue[c1]
		t.expect(q ~= nil and #q == 2 and q[1].kind == "build" and q[2].kind == "build", "its queue: the two generators")
		t.expect((sim.world.posX[c2] - starts[2][1]) ^ 2 + (sim.world.posZ[c2] - starts[2][2]) ^ 2 < 1, "player 2 never picked: its side's start")
		for _ = 1, 15 * 20 do
			Sim.step(sim)
		end
		t.expect(sim.build.target[c1] ~= nil and sim.build.target[c1] ~= 0 or #(sim.orders.queue[c1] or {}) < 2, "the Commander is on its queue")
	end)

	t.test("un-readying cancels the countdown; the timeout starts the match anyway", function()
		local sim = newMatch(2)
		ready(sim, 1, true)
		ready(sim, 2, true)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "countdown")
		ready(sim, 2, false)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "pick", "cancelled")
		local deadline = sim.pregame.deadline
		while sim.pregame and sim.tick < deadline + Pregame.COUNTDOWN + 2 do
			Sim.step(sim)
		end
		t.equal(sim.pregame, nil, "the timeout readied everyone")
		t.equal(sim.match.startTick, deadline + Pregame.COUNTDOWN)
	end)

	t.test("16 players on a two-start map: 8v8, every Commander spaced and in its side's area", function()
		local ai = {}
		for i = 1, 16 do
			ai[i] = "normal"
		end
		local sim = newMatch(16, "map:ridgeline", ai)
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
		t.equal(sim.pregame, nil, "the AI picked and readied: the match started")
		local w = sim.world
		local pos = {}
		for pid = 1, 16 do
			local c = commanderOf(sim, pid)
			t.expect(c ~= 0, `player {pid} has a Commander`)
			pos[pid] = { w.posX[c], w.posZ[c] }
		end
		local starts = (sim.map :: any).layers.starts
		local sides = StartAreas.sides({ 1, 2 }, #starts)
		for a = 1, 16 do
			t.equal(StartAreas.sideAt(sides, starts, pos[a][1], pos[a][2]), sim.players[a].allyTeam, `player {a} in its side's area`)
			for b = a + 1, 16 do
				local d = math.sqrt((pos[a][1] - pos[b][1]) ^ 2 + (pos[a][2] - pos[b][2]) ^ 2)
				t.expect(d >= StartAreas.SPACING - 1e-6, `players {a} and {b} {d} studs apart`)
			end
		end
		for _ = 1, 15 * 30 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		t.expect(#w.ids > 16, `the AIs build ({#w.ids} units)`)
		t.equal(sim.match.unitCap, 0, "no unit cap (S-170)")
	end)

	t.test("the wire: everyone sees every pick; queues go to allies only; COUNTDOWN 5..1, then 0 with the ENTERs", function()
		local sim = newMatch(4, "map:twin_lakes")
		local g = (sim.map :: any).grid
		local views = {}
		for pid = 1, 4 do
			views[pid] = Client.new(g)
			NetOut.join(sim, pid)
			NetOut.setCamera(sim, pid, 0, 0, g.cellsX - 1, g.cellsZ - 1)
		end
		local function step()
			Sim.step(sim)
			for pid = 1, 4 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
		end
		local starts = (sim.map :: any).layers.starts
		pick(sim, 1, starts[1][1], starts[1][2])
		local cell, ox, oz = g:encode(starts[1][1] + 60, starts[1][2])
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = {}, defIndex = sim.defs.units.ord_generator.index, cell = cell, offX = ox, offZ = oz, facing = 1 })
		step()
		t.expect(views[3].pregame[1] ~= nil and bit32.band(views[3].pregame[1].flags, Schema.PregameFlag.PICKED) ~= 0, "an enemy sees player 1's pick")
		t.expect(math.abs((views[3].pregame[1].x :: number) - starts[1][1]) < 0.1, "where it is")
		t.equal(#(views[2].prebuilds[1] or {}), 1, "an ally sees its queue")
		t.equal(views[3].prebuilds[1], nil, "an enemy doesn't")
		for pid = 1, 4 do
			ready(sim, pid, true)
		end
		local enterTick, zeroTick = nil, nil
		for _ = 1, Pregame.COUNTDOWN + 3 do
			step()
			local v = views[1]
			if v.countdown[#v.countdown] == 0 and zeroTick == nil then
				zeroTick = sim.tick
			end
			for _, u in v.units do
				if u.tier == "tactical" and enterTick == nil then
					enterTick = sim.tick
				end
			end
		end
		t.deepEqual(views[1].countdown, { 5, 4, 3, 2, 1, 0 }, "5..1, then 0")
		t.expect(zeroTick ~= nil and zeroTick == enterTick, `COUNTDOWN 0 and the Commanders' ENTERs on one tick ({zeroTick}, {enterTick})`)
	end)

	t.test("a chosen-starts match replays exactly", function()
		local sim = newMatch(2)
		local starts = (sim.map :: any).layers.starts
		pick(sim, 1, starts[1][1] + 30, starts[1][2])
		ready(sim, 1, true)
		ready(sim, 2, true)
		for _ = 1, 200 do
			Sim.step(sim)
		end
		local replayed, bad = Sim.runReplay(sim.replay, sim.tick)
		t.equal(bad, nil, "every checkpoint matches")
		t.equal(Sim.hash(replayed), Sim.hash(sim), "same state")
		t.equal(replayed.match.startTick, sim.match.startTick)
	end)

	t.test("fixed starts stay as they were: no pre-game", function()
		local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "map:ridgeline", scenario = "standard_start", match = { mode = "FFA", win = "COMMAND_ENDS" } })
		t.equal(sim.pregame, nil)
		t.equal(#sim.world.ids, 2, "the Commanders from the start")
		local _ = Layers
	end)
end

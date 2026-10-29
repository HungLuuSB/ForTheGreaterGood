--!strict
-- The pre-game (S-169, S-174, the user): startMode "choose": players pick
-- their starts in their side's box, may switch faction, queue builds for
-- their Commander, ready up; the host starts (or forces) a 3..1 countdown;
-- the Commanders land, then the match. Up to 16 players on any map.
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

local function startCmd(sim: Sim.Sim, player: number, force: boolean)
	submit(sim, player, { cmdType = CT.START, flags = 0, unitIds = {}, value = if force then 1 else 0 })
end

local function faction(sim: Sim.Sim, player: number, chaos: boolean)
	submit(sim, player, { cmdType = CT.FACTION, flags = 0, unitIds = {}, value = if chaos then 1 else 0 })
end

-- `n` players on two sides (the first half side 1); `extra`: more match options
local function newMatch(n: number, mapId: string?, ai: { [number]: string }?, extra: { [string]: any }?): Sim.Sim
	local players = {}
	for i = 1, n do
		table.insert(players, { id = i, team = i, allyTeam = if i <= n // 2 then 1 else 2 })
	end
	local match: any = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose", ai = ai }
	for k, v in extra or {} do
		match[k] = v
	end
	return Sim.new({ seed = 3, players = players, mapId = mapId or "map:ridgeline", scenario = "standard_start", match = match })
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
	t.test("spawn boxes: sides share the map's starts (hints) in blocks; boxes around them, split where they'd overlap (S-171)", function()
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
		local bounds = { -1024, -1024, 1024, 1024 }
		local half = StartAreas.boxHalf(2048, 2048)
		t.equal(half, 256, "a sixth of the map, at most 256")
		local boxes = StartAreas.boxes(two, starts, bounds)
		t.deepEqual(boxes[1], { -500 - half, -half, -500 + half, half }, "side 1's box around its start")
		t.expect(StartAreas.inBox(boxes[1], -500, 0) and not StartAreas.inBox(boxes[1], 0, 0), "the middle is no one's")
		-- close starts: the boxes are split at the midpoint, GAP apart
		local near = StartAreas.boxes(two, { { -100, 0 }, { 100, 0 } }, bounds)
		t.equal(near[1][3], -StartAreas.GAP / 2, "west box ends before the middle")
		t.equal(near[2][1], StartAreas.GAP / 2, "east box starts after it")
		-- a map's own boxes win, and the edge is kept
		local own = StartAreas.boxes(two, starts, bounds, { { -1100, -50, -400, 50 }, { 400, -50, 600, 50 } })
		t.deepEqual(own[1], { -1024 + StartAreas.EDGE, -50, -400, 50 })
	end)

	t.test("the pre-game: no units, only commands; picks in your own box, spaced, on standable ground", function()
		local sim = newMatch(2)
		t.expect(sim.pregame ~= nil, "a pre-game")
		t.equal(#sim.world.ids, 0, "no units yet")
		local starts = (sim.map :: any).layers.starts
		local west, east = starts[1], starts[2]
		pick(sim, 1, west[1], west[2])
		pick(sim, 2, west[1] + 100, west[2]) -- in the other side's area
		Sim.step(sim)
		t.deepEqual(sim.pregame.picks[1], { west[1], west[2] }, "player 1 picked its start")
		t.equal(sim.pregame.picks[2], nil, "player 2 can't pick in side 1's box")
		pick(sim, 2, east[1], east[2])
		Sim.step(sim)
		t.expect(sim.pregame.picks[2] ~= nil, "in its own box it can")
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

	t.test("all ready (no host): a 3 s countdown, the Commanders land on their picks, then take their queues", function()
		local sim = newMatch(2)
		local g = (sim.map :: any).grid
		local starts = (sim.map :: any).layers.starts
		local p1 = { starts[1][1] + 30, starts[1][2] + 40 }
		pick(sim, 1, p1[1], p1[2])
		-- player 1 queues two generators for its Commander
		local gen = sim.defs.units.ord_solar.index
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
		t.equal(sim.tick - readyTick, Pregame.COUNTDOWN, "3 s later the match starts")
		t.equal(sim.match.startTick, sim.tick)
		local c1, c2 = commanderOf(sim, 1), commanderOf(sim, 2)
		t.expect(c1 ~= 0 and c2 ~= 0, "both Commanders")
		t.expect(math.abs(sim.world.posX[c1] - p1[1]) < 1 and math.abs(sim.world.posZ[c1] - p1[2]) < 1, "player 1's on its pick")
		-- the landing: orders wait, the queue comes first
		local cell, ox, oz = g:encode(p1[1] - 80, p1[2])
		submit(sim, 1, { cmdType = CT.MOVE, flags = Schema.CmdFlag.QUEUE, unitIds = { c1 }, cell = cell, offX = ox, offZ = oz })
		for _ = 1, Schema.LANDING_TICKS - 1 do
			Sim.step(sim)
		end
		t.equal(#(sim.orders.queue[c1] or {}), 0, "landing: no orders yet")
		t.equal(sim.world.posX[c1], p1[1], "landing: it stays put")
		Sim.step(sim)
		local q = sim.orders.queue[c1]
		t.expect(q ~= nil and #q == 3 and q[1].kind == "build" and q[2].kind == "build" and q[3].kind == "move", "its queue: the two generators, then the held move")
		t.expect((sim.world.posX[c2] - starts[2][1]) ^ 2 + (sim.world.posZ[c2] - starts[2][2]) ^ 2 < 1, "player 2 never picked: its side's start")
		for _ = 1, 15 * 20 do
			Sim.step(sim)
		end
		t.expect(sim.build.target[c1] ~= nil and sim.build.target[c1] ~= 0 or #(sim.orders.queue[c1] or {}) < 2, "the Commander is on its queue")
	end)

	t.test("un-readying cancels the countdown; the pick time gives the unpicked a spot; MAX_WAIT starts the match anyway", function()
		local sim = newMatch(2)
		ready(sim, 1, true)
		ready(sim, 2, true)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "countdown")
		ready(sim, 2, false)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "pick", "cancelled")
		local deadline = sim.pregame.deadline
		while sim.tick < deadline do
			Sim.step(sim)
		end
		t.expect(sim.pregame.picks[1] ~= nil and sim.pregame.picks[2] ~= nil, "pick time over: both have a spot")
		t.equal(sim.pregame.phase, "pick", "player 2 still isn't ready")
		local maxWait = sim.pregame.maxWait
		while sim.pregame and sim.tick < maxWait + Pregame.COUNTDOWN + 2 do
			Sim.step(sim)
		end
		t.equal(sim.pregame, nil, "the wait limit started the match")
		t.equal(sim.match.startTick, maxWait + Pregame.COUNTDOWN)
	end)

	t.test("with a host: everyone ready isn't enough; the host starts, or forces a start nobody can cancel", function()
		local sim = newMatch(2, nil, nil, { host = 2 })
		ready(sim, 1, true)
		ready(sim, 2, true)
		Sim.step(sim)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "pick", "all ready: waiting for the host")
		startCmd(sim, 1, false)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "pick", "only the host starts")
		startCmd(sim, 2, false)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "countdown", "the host started it")
		ready(sim, 1, false)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "pick", "an un-ready cancels a normal start")
		startCmd(sim, 2, false)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "pick", "a normal start needs everyone ready")
		startCmd(sim, 2, true)
		Sim.step(sim)
		t.equal(sim.pregame.phase, "countdown", "/forcestart")
		ready(sim, 2, false)
		local started = sim.tick
		while sim.pregame do
			Sim.step(sim)
		end
		t.equal(sim.tick - started, Pregame.COUNTDOWN, "a forced countdown isn't cancelled")
		t.throws(function()
			newMatch(2, nil, nil, { host = 5 })
		end, "host must be a player")
	end)

	t.test("faction: switched while not ready, it changes the Commander and clears the queue (S-174)", function()
		local sim = newMatch(2)
		t.equal(sim.players[1].faction, "order", "the default: by team parity")
		local g = (sim.map :: any).grid
		local starts = (sim.map :: any).layers.starts
		pick(sim, 1, starts[1][1], starts[1][2])
		local cell, ox, oz = g:encode(starts[1][1] + 60, starts[1][2])
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = {}, defIndex = sim.defs.units.ord_solar.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
		faction(sim, 1, true)
		Sim.step(sim)
		t.equal(sim.players[1].faction, "chaos")
		t.equal(sim.pregame.builds[1], nil, "the Order queue is gone")
		t.expect(sim.pregame.picks[1] ~= nil, "the pick stays")
		ready(sim, 1, true)
		Sim.step(sim)
		faction(sim, 1, false)
		Sim.step(sim)
		t.equal(sim.players[1].faction, "chaos", "a ready player can't switch")
		ready(sim, 2, true)
		while sim.pregame do
			Sim.step(sim)
		end
		local c1 = commanderOf(sim, 1)
		t.equal(sim.defs.unitByIndex[sim.world.defIndex[c1]].id, "chs_warlord", "a Chaos Commander")
		t.equal(Sim.runReplay(sim.replay, sim.tick).players[1].faction, "chaos", "the replay switches too")
	end)

	t.test("F31: 16 players with 9 Chaos: teams are player IDs, factions per player", function()
		local players = {}
		for i = 1, 16 do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 8 then 1 else 2, faction = if i <= 9 then "chaos" else "order" })
		end
		local sim = Sim.new({ seed = 3, players = players, mapId = "map:plains", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose" } })
		for pid = 1, 16 do
			ready(sim, pid, true)
		end
		while sim.pregame do
			Sim.step(sim)
		end
		local chaos = 0
		for pid = 1, 16 do
			if sim.defs.unitByIndex[sim.world.defIndex[commanderOf(sim, pid)]].id == "chs_warlord" then
				chaos += 1
			end
		end
		t.equal(chaos, 9)
		t.throws(function()
			Sim.new({ seed = 3, players = { { id = 1, team = 1, faction = "legion" :: any } }, mapId = "map:plains" })
		end, "faction must be")
	end)

	t.test("the lobby's spawn boxes replace the map's; picks must be inside them", function()
		local sim = newMatch(2, "map:plains", nil, { startBoxes = { [1] = { 0, 0, 0.25, 1 }, [2] = { 0.75, 0, 1, 1 } } })
		local b1 = sim.pregame.boxes[1]
		local half = (sim.map :: any).grid.cellsX * 4
		t.expect(math.abs(b1[1] + half) < 1 and math.abs(b1[3] + half / 2) < 1, `box 1 is the west quarter ({b1[1]}..{b1[3]})`)
		pick(sim, 1, -half / 2 + 40, 0)
		Sim.step(sim)
		t.expect(sim.pregame.picks[1] == nil, "outside the drawn box: refused")
		pick(sim, 1, -half / 2 - 200, 0)
		Sim.step(sim)
		t.expect(sim.pregame.picks[1] ~= nil, "inside it")
		t.throws(function()
			newMatch(2, "map:plains", nil, { startBoxes = { [1] = { 0.5, 0, 0.25, 1 } } })
		end, "is empty")
		t.throws(function()
			newMatch(2, "map:plains", nil, { startBoxes = { [3] = { 0, 0, 0.25, 1 } } })
		end, "not in the match")
		local again = Sim.runReplay(sim.replay, sim.tick)
		t.deepEqual(again.pregame.boxes[1], sim.pregame.boxes[1], "the replay has the same boxes")
	end)

	t.test("the clocks wait for every human to load (a first command), or LOAD_WAIT (client-B's Studio run)", function()
		local sim = newMatch(3, nil, { [3] = "normal" })
		for _ = 1, 100 do
			Sim.step(sim)
		end
		local pg = sim.pregame
		t.expect(not pg.begun and pg.deadline == math.huge, "nobody has loaded: the clocks wait")
		local seconds, flags = Pregame.clock(sim)
		t.equal(seconds, Pregame.PICK_TIME // 15)
		t.expect(bit32.band(flags, Schema.PickClockFlag.LOADING) ~= 0, "PICK_CLOCK says loading")
		submit(sim, 1, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 10, maxZ = 10 })
		Sim.step(sim)
		t.expect(not pg.begun, "one human of two")
		submit(sim, 2, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 10, maxZ = 10 })
		Sim.step(sim)
		t.expect(pg.begun and pg.deadline == sim.tick + Pregame.PICK_TIME, "both loaded (the AI needn't): 150 s from now")
		local late = newMatch(2)
		for _ = 1, Pregame.LOAD_WAIT + 1 do
			Sim.step(late)
		end
		t.expect(late.pregame.begun, "LOAD_WAIT: the clocks start anyway")
	end)

	t.test("the AI waits for the first human pick, then takes the spots left", function()
		local sim = newMatch(4, "map:plains", { [2] = "normal", [3] = "normal", [4] = "normal" })
		local brains = Skirmish.forMatch(sim)
		for _ = 1, 30 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		t.equal(sim.pregame.picks[2], nil, "no human pick yet: the AI waits")
		local starts = (sim.map :: any).layers.starts
		pick(sim, 1, starts[2][1], starts[2][2]) -- the human takes side 1's second hint
		for _ = 1, 3 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		local p2 = sim.pregame.picks[2]
		t.expect(p2 ~= nil, "the ally AI picked")
		t.expect((p2[1] - starts[2][1]) ^ 2 + (p2[2] - starts[2][2]) ^ 2 > 1, "not the human's spot")
		t.expect(sim.pregame.ready[2] and sim.pregame.ready[3] and sim.pregame.ready[4], "the AI is ready")
	end)

	t.test("8v8 on Supreme Strait: a human takes another's start; the AIs fill every start left (S-207, H14)", function()
		local ai = {}
		for pid = 2, 16 do
			ai[pid] = "normal"
		end
		local sim = newMatch(16, "map:supreme_strait", ai)
		local brains = Skirmish.forMatch(sim)
		local pg = sim.pregame
		local starts = (sim.map :: any).layers.starts
		local hints = pg.sides.startsOf[1]
		t.equal(#hints, 8, "side 1 has 8 starts")
		local h = hints[4]
		pick(sim, 1, starts[h][1], starts[h][2]) -- player 1 takes the 4th start, an AI's
		for _ = 1, 3 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		for _, hint in hints do
			local on = false
			for pid = 1, 8 do
				local p = pg.picks[pid]
				if p and (p[1] - starts[hint][1]) ^ 2 + (p[2] - starts[hint][2]) ^ 2 < 1 then
					on = true
				end
			end
			t.expect(on, `start {hint} taken`)
		end
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
		local layers = (sim.map :: any).layers
		local boxes = StartAreas.boxes(StartAreas.sides({ 1, 2 }, #layers.starts), layers.starts, StartAreas.bounds((sim.map :: any).grid), layers.startBoxes)
		for a = 1, 16 do
			t.expect(StartAreas.inBox(sim.match and boxes[sim.players[a].allyTeam], pos[a][1], pos[a][2]), `player {a} in its side's box`)
			for b = a + 1, 16 do
				local d = math.sqrt((pos[a][1] - pos[b][1]) ^ 2 + (pos[a][2] - pos[b][2]) ^ 2)
				t.expect(d >= StartAreas.SPACING - 1e-6, `players {a} and {b} {d} studs apart`)
			end
		end
		-- each side's first player on its hint; the rest on scored spots near deposits
		t.expect(math.abs(pos[1][1] - layers.starts[1][1]) < 1 and math.abs(pos[1][2] - layers.starts[1][2]) < 1, "player 1 on side 1's hint")
		t.expect(math.abs(pos[9][1] - layers.starts[2][1]) < 1 and math.abs(pos[9][2] - layers.starts[2][2]) < 1, "player 9 on side 2's hint")
		local withDeposits = 0
		for pid = 2, 8 do
			for i = 0, (sim.map :: any).grid.cellCount - 1 do
				if Layers.getSupply(layers, i) > 0 then
					local dx, dz = (sim.map :: any).grid:cellCenter((sim.map :: any).grid:coords(i))
					if (dx - pos[pid][1]) ^ 2 + (dz - pos[pid][2]) ^ 2 <= Pregame.DEPOSIT_RADIUS ^ 2 then
						withDeposits += 1
						break
					end
				end
			end
		end
		print(`    8v8 Ridgeline: {withDeposits} of side 1's other 7 players start within {Pregame.DEPOSIT_RADIUS} studs of a deposit`)
		t.expect(withDeposits >= 4, "most of them near deposits")
		for _ = 1, 15 * 30 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		t.expect(#w.ids > 16, `the AIs build ({#w.ids} units)`)
		t.equal(sim.match.unitCap, 0, "no unit cap (S-170)")
	end)

	t.test("the wire: everyone sees every pick, faction and host; boxes and the clock; queues go to allies only; COUNTDOWN 3..1, then 0 with the ENTERs", function()
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
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = {}, defIndex = sim.defs.units.ord_solar.index, cell = cell, offX = ox, offZ = oz, facing = 1 })
		step()
		t.expect(views[3].pregame[1] ~= nil and bit32.band(views[3].pregame[1].flags, Schema.PregameFlag.PICKED) ~= 0, "an enemy sees player 1's pick")
		t.expect(math.abs((views[3].pregame[1].x :: number) - starts[1][1]) < 0.1, "where it is")
		t.equal(#(views[2].prebuilds[1] or {}), 1, "an ally sees its queue")
		t.equal(views[3].prebuilds[1], nil, "an enemy doesn't")
		t.expect(bit32.band(views[1].pregame[4].flags, Schema.PregameFlag.CHAOS) ~= 0 and bit32.band(views[1].pregame[1].flags, Schema.PregameFlag.CHAOS) == 0, "factions")
		local vb = (views[2].startBoxes :: any)[1]
		local sb = sim.pregame.boxes[1]
		t.expect(vb ~= nil and math.abs(vb[1] - sb[1]) <= 1 and math.abs(vb[4] - sb[4]) <= 1, "the spawn boxes")
		t.equal((views[2].pickClock :: any).seconds, 150, "150 s to pick")
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
		t.deepEqual(views[1].countdown, { 3, 2, 1, 0 }, "3..1, then 0")
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

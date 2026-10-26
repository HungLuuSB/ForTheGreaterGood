--!strict
-- Spawn boxes in the room (F26, L-20): boxes from the host cleaned and
-- snapped, the defaults are the match's own (StartAreas) on the real maps,
-- only the host edits them in Teams, and the match config carries every
-- side's box only once one was edited.

local MapRegistry = require("@shared/Grid/MapRegistry")
local MatchConfig = require("../shared/MatchConfig")
local Rooms = require("../shared/Rooms")
local SpawnBoxes = require("../shared/SpawnBoxes")
local StartAreas = require("@shared/Match/StartAreas")
local RunAll = require("../../server/Tests/RunAll")

local LOBBY = { placeId = 1, jobId = "job" }

local function geoOf(mapId: string): SpawnBoxes.Geometry
	local layers = assert(MapRegistry.load(mapId))
	return { bounds = StartAreas.bounds(layers.grid), starts = layers.starts, startBoxes = layers.startBoxes, splits = SpawnBoxes.splitList(layers.sideSplits) }
end

local PLAINS = geoOf("map:plains")
local MAPS: { Rooms.MapInfo } = { { id = "map:plains", name = "The Plains", starts = #PLAINS.starts, geo = PLAINS }, { id = "map:quad", name = "Quad", starts = 4 } }
local HOST, B = 10, 20

local function teamRoom(): Rooms.Room
	local r = assert(Rooms.new("r1", { name = "Boxes", privacy = "public", maxPlayers = 16 }, HOST, "Host", MAPS))
	Rooms.join(r, MAPS, B, "Bee", nil)
	Rooms.apply(r, MAPS, HOST, { op = "set", key = "mode", value = "TEAM" })
	Rooms.apply(r, MAPS, HOST, { op = "mine", team = 2 })
	Rooms.apply(r, MAPS, B, { op = "mine", team = 5 })
	Rooms.apply(r, MAPS, HOST, { op = "addAi", team = 7 })
	return r
end

return function(t: RunAll.Context)
	t.test("a box from the host is cleaned: inside the map, snapped to its edges, not too small", function()
		t.deepEqual(SpawnBoxes.clean({ 0.02, 0.5, 0.4, 0.99 }), { 0, 0.5, 0.4, 1 }, "within 3% of an edge snaps")
		t.deepEqual(SpawnBoxes.clean({ -0.2, 0.1, 0.3, 0.6 }), { 0, 0.1, 0.3, 0.6 }, "clamped")
		t.deepEqual(SpawnBoxes.clean({ 0.12345, 0.2, 0.5, 0.6 }), { 0.123, 0.2, 0.5, 0.6 }, "thousandths")
		t.equal(select(2, SpawnBoxes.clean({ 0.5, 0.5, 0.52, 0.9 })), "That box is too small")
		t.equal(select(2, SpawnBoxes.clean({ 0.6, 0.5, 0.4, 0.9 })), "That box is too small", "inside out")
		for _, bad in { "box", { 0, 0, 1 }, { 0, 0, 1, "1" }, { 0, 0, 1, 0 / 0 }, { 0, 0, 1, 99 } } :: { any } do
			t.equal(SpawnBoxes.clean(bad), nil)
		end
	end)

	t.test("the defaults are the match's boxes as fractions, for every side count on The Plains", function()
		local b = PLAINS.bounds
		for count = 2, 8 do
			local boxes = SpawnBoxes.defaults(PLAINS, count)
			local studs = StartAreas.boxes(StartAreas.sides((function()
				local list = {}
				for a = 1, count do
					table.insert(list, a)
				end
				return list
			end)(), #PLAINS.starts, assert(MapRegistry.load("map:plains")).sideSplits), PLAINS.starts, b, PLAINS.startBoxes)
			for a = 1, count do
				local f, s = boxes[a], studs[a]
				t.expect(f ~= nil, `{count} sides: side {a}`)
				t.expect(f[1] >= 0 and f[3] <= 1 and f[2] >= 0 and f[4] <= 1 and f[1] < f[3] and f[2] < f[4], `{count} sides: side {a} inside`)
				t.expect(math.abs(f[1] - (s[1] - b[1]) / (b[3] - b[1])) <= 0.001, `{count} sides: side {a} x0`)
				t.expect(math.abs(f[4] - (s[4] - b[2]) / (b[4] - b[2])) <= 0.001, `{count} sides: side {a} z1`)
			end
		end
		t.deepEqual(SpawnBoxes.defaults(PLAINS, 17), {}, "more sides than starts")
	end)

	t.test("The Plains' own side splits (S-186): three sides don't put one in two corners", function()
		t.expect(PLAINS.splits ~= nil and #(PLAINS.splits :: any) > 0, "the map's splits travel as a list")
		local boxes = SpawnBoxes.defaults(PLAINS, 3)
		-- west half, then north-east and south-east: no box spans the map
		t.expect(boxes[1][3] <= 0.5 + 0.001, `side 1 stays west: {boxes[1][3]}`)
		for a = 2, 3 do
			t.expect(boxes[a][1] >= 0.5 - 0.001, `side {a} stays east: {boxes[a][1]}`)
		end
		t.expect(boxes[2][4] <= boxes[3][2] + 0.001 or boxes[3][4] <= boxes[2][2] + 0.001, "north-east and south-east apart")
	end)

	t.test("only the host edits boxes, in Teams, for a seated team; map and mode changes reset them", function()
		local r = teamRoom()
		t.equal(Rooms.apply(r, MAPS, B, { op = "box", team = 5, box = { 0, 0, 0.3, 0.3 } }), "Only the host can do that")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "box", team = 3, box = { 0, 0, 0.3, 0.3 } }), "No one plays on that team")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "box", team = 5, box = { 0, 0, 0.01, 0.3 } }), "That box is too small")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "box", team = 5, box = { 0.01, 0.6, 0.3, 0.98 } }), nil)
		t.deepEqual((r.settings.boxes :: any)["5"], { 0, 0.6, 0.3, 1 })
		Rooms.apply(r, MAPS, HOST, { op = "resetBoxes" })
		t.equal(r.settings.boxes, nil)
		Rooms.apply(r, MAPS, HOST, { op = "box", team = 5, box = { 0, 0.6, 0.3, 1 } })
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "nowhere" }), "Unknown map")
		t.expect(r.settings.boxes ~= nil, "a refused change keeps them")
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:quad" })
		t.equal(r.settings.boxes, nil, "a new map resets them")
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:plains" })
		Rooms.apply(r, MAPS, HOST, { op = "box", team = 5, box = { 0, 0.6, 0.3, 1 } })
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mode", value = "FFA" })
		t.equal(r.settings.boxes, nil, "so does the mode")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "box", team = 1, box = { 0, 0, 0.3, 0.3 } }), "Spawn boxes are per team: switch to Teams")
	end)

	t.test("the config carries every side's box by ally team once one was edited, else none", function()
		local r = teamRoom()
		t.equal(MatchConfig.build(r, "m1", 1, 0, LOBBY, MAPS[1]).startBoxes, nil, "untouched: the match uses its own")
		Rooms.apply(r, MAPS, HOST, { op = "box", team = 5, box = { 0.4, 0.4, 0.6, 0.6 } })
		local c = MatchConfig.build(r, "m1", 1, 0, LOBBY, MAPS[1])
		t.equal(MatchConfig.validate(c), nil)
		local boxes = c.startBoxes :: any
		local defaults = SpawnBoxes.defaults(PLAINS, 3)
		-- teams 2, 5, 7 are ally teams 1, 2, 3
		t.deepEqual(boxes, { defaults[1], { 0.4, 0.4, 0.6, 0.6 }, defaults[3] })
		for _, p in c.players do
			t.expect(boxes[p.allyTeam] ~= nil, `player {p.id} has a box`)
		end
		-- the edit stays with its team when another team empties
		Rooms.apply(r, MAPS, HOST, { op = "removeAi", index = 3 })
		local c2 = MatchConfig.build(r, "m2", 1, 0, LOBBY, MAPS[1])
		t.deepEqual(c2.startBoxes :: any, { SpawnBoxes.defaults(PLAINS, 2)[1], { 0.4, 0.4, 0.6, 0.6 } })
		-- without the map's shape, no side lacks a box: none are sent
		t.equal(MatchConfig.build(r, "m3", 1, 0, LOBBY, nil).startBoxes, nil)
	end)
end

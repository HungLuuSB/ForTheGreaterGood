--!strict
-- The match config and results record (L-4, docs/contracts/match.md):
-- built from a room, players ordered by start and ally team, validated, and
-- tampered or malformed records refused; seat colours as the match shows
-- them (S-172).

local MatchConfig = require("../shared/MatchConfig")
local Rooms = require("../shared/Rooms")
local TeamColors = require("@shared/Match/TeamColors")
local RunAll = require("../../server/Tests/RunAll")

local MAPS: { Rooms.MapInfo } = { { id = "map:quad", name = "Quad", starts = 4 } }
local LOBBY = { placeId = 1, jobId = "job" }

local function teamRoom(): Rooms.Room
	local r = assert(Rooms.new("r1", { name = "Teams room", privacy = "public" }, 10, "Host", MAPS))
	Rooms.join(r, MAPS, 20, "Bee", nil)
	Rooms.apply(r, MAPS, 10, { op = "set", key = "mode", value = "TEAM" })
	Rooms.apply(r, MAPS, 10, { op = "addAi", level = "hard" })
	Rooms.apply(r, MAPS, 10, { op = "addAi", level = "easy" })
	-- slots: host team 3, Bee team 1, AI hard team 3, AI easy team 1
	Rooms.apply(r, MAPS, 10, { op = "mine", team = 3 })
	Rooms.apply(r, MAPS, 20, { op = "mine", team = 1 })
	Rooms.apply(r, MAPS, 10, { op = "ai", index = 3, team = 3 })
	Rooms.apply(r, MAPS, 10, { op = "ai", index = 4, team = 1 })
	return r
end

return function(t: RunAll.Context)
	t.test("Teams: ally teams sit together, renumbered from 1; AI numbered in that order; starts picked in game (0)", function()
		local c = MatchConfig.build(teamRoom(), "m1", 42, 1000, LOBBY)
		t.equal(MatchConfig.validate(c), nil)
		local got = {}
		for _, p in c.players do
			table.insert(got, { p.id, p.start, p.allyTeam, p.name, p.user or 0 })
		end
		t.deepEqual(got, {
			{ 1, 0, 1, "Bee", 20 },
			{ 2, 0, 1, "AI 1 (easy)", 0 },
			{ 3, 0, 2, "Host", 10 },
			{ 4, 0, 2, "AI 2 (hard)", 0 },
		})
		t.equal(c.players[2].ai, "easy")
		t.equal(c.host, 10, "the room host (F32)")
		t.equal(c.lobby.roomId, "r1")
		t.equal(c.version, MatchConfig.CONFIG_VERSION)
	end)

	t.test("FFA: slot order, each player their own ally team; spectators listed", function()
		local r = assert(Rooms.new("r2", { name = "FFA room", privacy = "public" }, 10, "Host", { { id = "map:duel", name = "Duel", starts = 2 } }))
		local maps = { { id = "map:duel", name = "Duel", starts = 2 } }
		Rooms.join(r, maps, 20, "Bee", nil)
		Rooms.join(r, maps, 30, "Cee", nil)
		local c = MatchConfig.build(r, "m2", 1, 0, LOBBY)
		t.equal(MatchConfig.validate(c), nil)
		t.equal(c.players[1].allyTeam, 1)
		t.equal(c.players[2].allyTeam, 2)
		t.deepEqual(c.spectators, { { user = 30, name = "Cee" } })
		t.deepEqual(MatchConfig.users(c), { 10, 20, 30 })
	end)

	t.test("seat colours: forViewer on the config's player IDs, from each viewer's seat", function()
		local r = teamRoom()
		local function names(viewer: number?): { string }
			local out = {}
			for i, c in MatchConfig.colors(r, viewer) do
				out[i] = c.name
			end
			return out
		end
		-- by slot: Host (team 3), Bee (team 1), AI hard (team 3), AI easy (team 1)
		t.deepEqual(names(10), { "Blue", "Red", "Cyan", "Orange" })
		t.deepEqual(names(20), { "Red", "Blue", "Orange", "Cyan" })
		t.deepEqual(names(nil), { "Red", "Blue", "Orange", "Cyan" }, "a spectator: the lowest ally team is cold")
		t.deepEqual(names(30), names(nil), "a member without a seat watches")
		-- the same colours the match computes from the config it's sent
		local c = MatchConfig.build(r, "m1", 1, 0, LOBBY)
		local byId = TeamColors.forViewer(3, c.players :: any)
		local mine = MatchConfig.colors(r, 10)
		for _, seat in MatchConfig.seats(r) do
			t.equal(mine[seat.slot], byId[seat.id])
			t.equal(c.players[seat.id].allyTeam, seat.allyTeam)
		end
	end)

	t.test("16 seats in any faction mix start and pass the shared check (F31)", function()
		local maps = { { id = "map:plains", name = "The Plains", starts = 16 } }
		for _, mode in { "TEAM", "FFA" } do
			local r = assert(Rooms.new("r3", { name = "Full", privacy = "public", maxPlayers = 16 }, 10, "Host", maps))
			Rooms.apply(r, maps, 10, { op = "set", key = "mode", value = mode })
			Rooms.apply(r, maps, 10, { op = "mine", faction = "order", team = 1 })
			for i = 2, 16 do
				-- 9 Chaos and 7 Order, 8 against 8 in Teams
				t.equal(Rooms.apply(r, maps, 10, { op = "addAi", faction = if i <= 10 then "chaos" else "order", team = if i <= 8 then 1 else 2 }), nil)
			end
			t.equal(#r.slots, 16)
			t.equal(Rooms.checkStart(r, maps, 10, true), nil, mode)
			local c = MatchConfig.build(r, "m3", 1, 0, LOBBY)
			t.equal(MatchConfig.validate(c), nil, mode)
			local chaos = 0
			for _, p in c.players do
				chaos += if p.faction == "chaos" then 1 else 0
			end
			t.equal(chaos, 9)
		end
	end)

	t.test("back from a match as host: host rights, setup, Start works (rebuilt elsewhere or not)", function()
		local r = teamRoom()
		local c = MatchConfig.build(r, "m1", 42, 1000, LOBBY)
		-- another lobby server: Bee is back first, the room is still the host's
		local again = Rooms.fromMatch("NEW01", c, nil, 20)
		t.equal(again.host, 10)
		t.equal(again.phase, "match")
		Rooms.welcomeBack(again, 20, "Bee", c.host)
		t.equal(again.host, 10)
		Rooms.welcomeBack(again, 10, "Host", c.host)
		Rooms.setPhase(again, "setup", nil) -- the result was read
		t.equal(Rooms.apply(again, MAPS, 10, { op = "set", key = "win", value = "ANNIHILATION" }), nil)
		t.equal(Rooms.apply(again, MAPS, 20, { op = "set", key = "win", value = "COMMAND_ENDS" }), "Only the host can do that")
		Rooms.apply(again, MAPS, 20, { op = "ready", value = true })
		t.equal(Rooms.checkStart(again, MAPS, 10, false), nil, "Start works again")
		-- a config from before v2 has no host: the first one back hosts
		local old = table.clone(c) :: any
		old.host = nil
		t.equal(Rooms.fromMatch("NEW02", old, nil, 20).host, 20)
		-- the same server: the host, removed after the grace, comes back in and hosts again
		Rooms.setPhase(r, "setup", nil)
		Rooms.leave(r, 10)
		t.equal(r.host, 20)
		t.equal(Rooms.member(r, 10), nil)
		Rooms.welcomeBack(r, 10, "Host", c.host)
		t.equal(r.host, 10)
		t.expect(Rooms.member(r, 10) ~= nil, "a member again")
		t.equal(Rooms.apply(r, MAPS, 10, { op = "play", team = 2 }), nil, "and takes a seat")
		t.equal(Rooms.apply(r, MAPS, 10, { op = "set", key = "win", value = "ANNIHILATION" }), nil)
	end)

	t.test("validate refuses tampered configs", function()
		local function broken(edit: (any) -> (), pattern: string)
			local c: any = MatchConfig.build(teamRoom(), "m1", 42, 1000, LOBBY)
			edit(c)
			local err = MatchConfig.validate(c)
			t.expect(err and string.find(err, pattern, 1, true), `expected "{pattern}", got {err}`)
		end
		broken(function(c)
			c.host = 999 -- nobody in the match (v2: a player or a spectator)
		end, "host")
		broken(function(c)
			c.startBoxes = { [9] = { 0, 0, 0.5, 0.5 } }
		end, "startBoxes")
		broken(function(c)
			c.version = MatchConfig.CONFIG_VERSION + 1
		end, "version")
		broken(function(c)
			c.players[1].id = 7
		end, "player 1: id")
		broken(function(c)
			c.players[2].color = c.players[1].color
		end, "player 2: color")
		broken(function(c)
			c.players[3].user = 20
		end, "player 3: user")
		broken(function(c)
			c.players[2].ai = "godlike"
		end, "player 2: AI")
		broken(function(c)
			c.mode = "FFA"
		end, "FFA ally team")
		broken(function(c)
			c.spectators = { { user = 10, name = "Host" } }
		end, "spectator")
		broken(function(c)
			c.players = { c.players[2], c.players[4] }
			c.players[1].id, c.players[1].start, c.players[2].id, c.players[2].start = 1, 0, 2, 0
		end, "no human")
		broken(function(c)
			c.cheats = "yes"
		end, "options")
		broken(function(c)
			c.lobby = nil
		end, "lobby")
	end)

	t.test("results records are checked against their config", function()
		local c = MatchConfig.build(teamRoom(), "m1", 42, 1000, LOBBY)
		local r: any = {
			version = MatchConfig.CONFIG_VERSION,
			matchId = "m1",
			outcome = "finished",
			winner = 2,
			seconds = 600,
			endedAt = 1600,
			cheatsUsed = false,
			players = {
				{ id = 1, won = false, outAt = 500, stats = { unitsBuilt = 10 } },
				{ id = 2, won = false },
				{ id = 3, won = true },
				{ id = 4, won = true },
			},
		}
		t.equal(MatchConfig.validateResult(r, c), nil)
		local s = MatchConfig.summary(c, r, "Quad")
		t.equal(s.players[3].name, "Host")
		t.equal(s.players[3].won, true)
		t.equal(s.players[1].outAt, 500)
		r.matchId = "m9"
		t.equal(MatchConfig.validateResult(r, c), "version or matchId")
		r.matchId = "m1"
		r.winner = 9
		t.equal(MatchConfig.validateResult(r, c), "winner")
		r.winner = nil -- every human out while AI fight on: finished, nobody's winner
		t.equal(MatchConfig.validateResult(r, c), nil)
		r.outcome = "draw"
		r.winner = 2
		t.equal(MatchConfig.validateResult(r, c), "winner")
		r.outcome = "finished"
		r.players[1].stats = { unitsBuilt = "lots" }
		t.equal(MatchConfig.validateResult(r, c), "player 1: stats")
		r.players[1].stats = nil
		table.remove(r.players)
		t.equal(MatchConfig.validateResult(r, c), "players")
	end)
end

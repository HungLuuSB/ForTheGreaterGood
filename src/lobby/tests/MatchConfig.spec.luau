--!strict
-- The match config and results record (L-4, docs/contracts/match.md):
-- built from a room, players ordered by start and ally team, validated, and
-- tampered or malformed records refused.

local MatchConfig = require("../shared/MatchConfig")
local Rooms = require("../shared/Rooms")
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
		t.equal(c.lobby.roomId, "r1")
		t.equal(c.version, 1)
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

	t.test("validate refuses tampered configs", function()
		local function broken(edit: (any) -> (), pattern: string)
			local c: any = MatchConfig.build(teamRoom(), "m1", 42, 1000, LOBBY)
			edit(c)
			local err = MatchConfig.validate(c)
			t.expect(err and string.find(err, pattern, 1, true), `expected "{pattern}", got {err}`)
		end
		broken(function(c)
			c.version = 2
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
			version = 1,
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

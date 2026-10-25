--!strict
-- The lobby ↔ match contract's records (S-145, docs/contracts/match.md):
-- tampered or malformed configs and results are refused. Moved from the
-- lobby stream's spec with the validator; the lobby keeps its build tests.
local MatchConfig = require("@shared/Match/MatchConfig")
local RunAll = require("./RunAll")

-- What the lobby builds for a Teams room: Bee (20) and an easy AI on ally
-- team 1, the host (10) and a hard AI on ally team 2.
local function teamConfig(): any
	return {
		version = 2,
		matchId = "m1",
		createdAt = 1000,
		seed = 42,
		mapId = "map:quad",
		mode = "TEAM",
		win = "COMMAND_ENDS",
		friendlyFire = true,
		cheats = false,
		players = {
			{ id = 1, start = 1, faction = "order", allyTeam = 1, color = 1, user = 20, name = "Bee" },
			{ id = 2, start = 2, faction = "chaos", allyTeam = 1, color = 2, name = "AI 1 (easy)", ai = "easy" },
			{ id = 3, start = 3, faction = "order", allyTeam = 2, color = 3, user = 10, name = "Host" },
			{ id = 4, start = 4, faction = "chaos", allyTeam = 2, color = 4, name = "AI 2 (hard)", ai = "hard" },
		},
		spectators = {},
		lobby = { placeId = 1, jobId = "job", roomId = "r1", roomName = "Teams room" },
		host = 10,
	}
end

return function(t: RunAll.Context)
	t.test("a well-formed config passes; users lists players and spectators", function()
		local c = teamConfig()
		t.equal(MatchConfig.validate(c), nil)
		c.spectators = { { user = 30, name = "Cee" } }
		t.equal(MatchConfig.validate(c), nil)
		c.host = 30
		c.startBoxes = { [1] = { 0, 0, 0.3, 1 }, [2] = { 0.7, 0, 1, 1 } }
		t.equal(MatchConfig.validate(c), nil, "a spectating host; drawn boxes (S-174)")
		t.deepEqual(MatchConfig.users(c), { 20, 10, 30 })
		t.equal(#MatchConfig.COLORS, 16) -- 16 players (S-169)
	end)

	t.test("validate refuses tampered configs", function()
		local function broken(edit: (any) -> (), pattern: string)
			local c = teamConfig()
			edit(c)
			local err = MatchConfig.validate(c)
			t.expect(err ~= nil and string.find(err, pattern, 1, true) ~= nil, `expected "{pattern}", got {err}`)
		end
		broken(function(c)
			c.version = 1
		end, "version")
		broken(function(c)
			c.host = 99
		end, "host")
		broken(function(c)
			c.startBoxes = { [3] = { 0, 0, 0.5, 1 } }
		end, "startBoxes[3]")
		broken(function(c)
			c.startBoxes = { [1] = { 0.5, 0, 0.5, 1 } }
		end, "empty")
		broken(function(c)
			c.startBoxes = { [1] = { 0, 0, 1.5, 1 } }
		end, "startBoxes[1]")
		broken(function(c)
			c.players[1].id = 7
		end, "player 1: id")
		broken(function(c)
			c.players[2].start = 3
		end, "player 2: id")
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
			c.players[1].id, c.players[1].start, c.players[2].id, c.players[2].start = 1, 1, 2, 2
		end, "no human")
		broken(function(c)
			c.cheats = "yes"
		end, "options")
		broken(function(c)
			c.lobby = nil
		end, "lobby")
		broken(function(c)
			c.seed = -1
		end, "seed")
	end)

	t.test("results records are checked against their config", function()
		local c = teamConfig()
		local r: any = {
			version = 2,
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

--!strict
-- The match server's side of the lobby contract (C-173, docs/contracts/
-- match.md v1): a config the lobby writes passes the check and runs as a
-- real match (opening with the pre-game, C-218); bad configs are refused;
-- seats and spectators come from it; the results record the match writes
-- passes the lobby's check.

local MatchContract = require("../../src/roblox/MatchContract")
local Lobby = require("../../src/roblox/Lobby")
local Combat = require("../../src/server/Sim/Combat/Combat")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local Stats = require("../../src/server/Sim/Stats")
local Pregame = require("../../src/client/Core/Pregame")
local Schema = require("@shared/Net/Schema")

-- Through the pre-game (every lobby match has one): the humans say READY,
-- the host forces the start, the AI picks and readies on its own; steps
-- until the match starts and the Commanders have landed.
local function start(sim: any, brains: { any }, humans: { number })
	assert(sim.pregame ~= nil, "a lobby match opens with the pre-game")
	for _, id in humans do
		assert(Sim.submit(sim, id, Pregame.ready(true)))
	end
	if sim.pregame.host then
		assert(Sim.submit(sim, sim.pregame.host, Pregame.start(true))) -- the host forces the start (S-174)
	end
	for _ = 1, 10 * 15 do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if sim.pregame == nil then
			for _ = 1, Schema.LANDING_TICKS do
				Sim.step(sim)
			end
			return
		end
	end
	error("the pre-game didn't end")
end

-- What the lobby's MatchConfig.build writes for a room.
local function config(mode: string): any
	local players = if mode == "TEAM"
		then {
			{ id = 1, start = 1, faction = "order", allyTeam = 1, color = 1, user = 11, name = "Ann" },
			{ id = 2, start = 2, faction = "chaos", allyTeam = 1, color = 3, name = "AI 1 (easy)", ai = "easy" },
			{ id = 3, start = 3, faction = "chaos", allyTeam = 2, color = 2, user = 22, name = "Bo" },
			{ id = 4, start = 4, faction = "order", allyTeam = 2, color = 4, name = "AI 2 (hard)", ai = "hard" },
		}
		else {
			{ id = 1, start = 1, faction = "order", allyTeam = 1, color = 1, user = 11, name = "Ann" },
			{ id = 2, start = 2, faction = "chaos", allyTeam = 2, color = 2, name = "AI 1 (normal)", ai = "normal" },
		}
	return {
		version = 2,
		matchId = "0f2c-match",
		createdAt = 1700000000,
		seed = 42,
		mapId = if mode == "TEAM" then "map:crossroads" else "map:ridgeline",
		mode = mode,
		win = "COMMAND_ENDS",
		friendlyFire = true,
		cheats = false,
		players = players,
		spectators = { { user = 33, name = "Cy" } },
		lobby = { placeId = 123, jobId = "job-1", roomId = "room-1", roomName = "Ann's room" },
		host = 11,
	}
end

return function(t: any)
	t.test("a lobby config passes the check; bad ones are refused", function()
		t.equal(MatchContract.validate(config("FFA")), nil)
		t.equal(MatchContract.validate(config("TEAM")), nil)
		local function broken(edit: (any) -> ()): string?
			local c = config("FFA")
			edit(c)
			return MatchContract.validate(c)
		end
		t.expect(broken(function(c) c.version = 1 end) ~= nil, "another version")
		t.expect(broken(function(c) c.players[2].color = 1 end) ~= nil, "a shared colour")
		t.expect(broken(function(c) c.players[1].start = 2 end) ~= nil, "start must equal id in v1")
		t.expect(broken(function(c) c.players[1].user = nil; c.players[1].ai = nil end) ~= nil, "a human without a user")
		t.expect(broken(function(c) c.players[1].user = nil; c.players[1].ai = "hard" end) ~= nil, "no human left")
		t.expect(broken(function(c) c.spectators[1].user = 11 end) ~= nil, "a player can't also spectate")
		t.expect(broken(function(c) c.lobby = nil end) ~= nil, "no lobby to return to")
	end)

	t.test("seats and spectators from the config", function()
		local c = config("TEAM")
		t.equal(MatchContract.seatOf(c, 11), 1)
		t.equal(MatchContract.seatOf(c, 22), 3)
		t.equal(MatchContract.seatOf(c, 33), "spectator")
		t.equal(MatchContract.seatOf(c, 99), nil, "not listed: kicked")
		local sc = MatchContract.toSim(c)
		t.deepEqual({ sc.players[3].team, sc.players[3].faction }, { 3, "chaos" }, "team = seat, the faction in the entry (S-174)")
		t.equal(sc.match.host, 1, "Ann hosts")
	end)

	t.test("a Teams config runs as a match and its results record passes the lobby's check", function()
		local c = config("TEAM")
		local sim = Sim.new(MatchContract.toSim(c))
		t.equal(sim.players[1].allyTeam, 1)
		t.equal(sim.players[3].allyTeam, 2)
		local brains = Skirmish.forMatch(sim)
		t.equal(#brains, 2, "two AI")
		local lobby = MatchContract.toLobby(c)
		t.deepEqual(Lobby.humans(lobby), { 1, 3 })
		start(sim, brains, Lobby.humans(lobby))
		for _ = 1, 300 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		-- ally team 2 loses everything
		for _, id in sim.world.ids do
			if sim.players[sim.world.owner[id]].allyTeam == 2 then
				Combat.queueDamage(sim.combat, id, 1e7, 0)
			end
		end
		for _ = 1, 60 do
			Sim.step(sim)
		end
		t.expect(sim.match.over and sim.match.winner == 1, "ally team 1 won")
		t.expect(Lobby.done(lobby, sim))
		local outcome, winner = MatchContract.outcomeOf(sim, 2)
		t.equal(outcome, "finished")
		t.equal(winner, 1)
		local r = MatchContract.result(c, outcome, sim, Stats.report(sim), 0, 1700000500, nil, winner)
		t.equal(MatchContract.validateResult(r, c), nil)
		t.equal(r.winner, 1)
		t.expect(r.players[1].won and r.players[2].won and not r.players[3].won, "ally team 1's players won")
		t.expect(r.players[3].outAt ~= nil, "Bo's time out")
		t.expect(r.players[2].stats and (r.players[2].stats :: any).unitsBuilt ~= nil, "flat stats with the report's names")
		t.equal((r.players[2].stats :: any).series, nil, "no time series in the record")
	end)

	t.test("ended before the sim's own end: winner from who stands, else a draw", function()
		local c = config("FFA")
		local sim = Sim.new(MatchContract.toSim(c))
		start(sim, Skirmish.forMatch(sim), Lobby.humans(MatchContract.toLobby(c)))
		for _ = 1, 30 do
			Sim.step(sim)
		end
		local outcome, winner, reason = MatchContract.outcomeOf(sim, 1)
		t.equal(outcome, "finished", "several still stand: finished, no winner (the humans lost)")
		t.equal(winner, nil)
		t.expect(reason ~= nil)
		local r0 = MatchContract.result(c, outcome, sim, Stats.report(sim), 0, 1, reason, winner)
		t.equal(MatchContract.validateResult(r0, c), nil)
		t.equal(r0.winner, nil)
		t.expect(not r0.players[1].won and not r0.players[2].won, "nobody won")
		t.equal((MatchContract.outcomeOf(sim, 0)), "abandoned", "nobody left on the server")
		sim.match.eliminated[1] = sim.tick -- the human is out; the AI stands alone
		local o2, w2 = MatchContract.outcomeOf(sim, 1)
		t.equal(o2, "finished")
		t.equal(w2, 2)
		local r = MatchContract.result(c, o2, sim, Stats.report(sim), 0, 1, nil, w2)
		t.equal(MatchContract.validateResult(r, c), nil)
		t.expect(r.players[2].won and not r.players[1].won)
	end)

	t.test("failures carry an error code for the lobby (match.md section 11, F38)", function()
		local E = MatchContract.ERROR
		t.equal(MatchContract.refusal(nil, "no match config for this server").code, E.NO_SETUP)
		local old = config("FFA")
		old.version = 1
		t.equal(MatchContract.refusal(old, "version or matchId").code, E.VERSION)
		local bad = MatchContract.refusal(config("FFA"), "players")
		t.deepEqual({ bad.code, bad.detail }, { E.BAD_SETUP, "players" }, "the validator's reason as the detail")
		t.equal(#(MatchContract.error(E.SERVER_ERROR, string.rep("x", 500)).detail :: string), MatchContract.DETAIL_MAX, "details cut to 200")
		t.equal(MatchContract.error(E.OVER).detail, nil)
		local c = config("TEAM")
		local r = MatchContract.result(c, "abandoned", nil, nil, 0, 1700000100, "every player left", nil, MatchContract.error(E.EVERYONE_LEFT))
		t.equal(r.error.code, 209)
		t.equal(MatchContract.validateResult(r, c), nil, "the record with an error still passes the lobby's check")
	end)

	t.test("refused or deserted: an abandoned record still passes the check", function()
		local c = config("FFA")
		local r = MatchContract.result(c, "abandoned", nil, nil, 0, 1700000100, "config refused: version 1")
		t.equal(MatchContract.validateResult(r, c), nil)
		t.equal(r.reason, "config refused: version 1")
		t.equal(r.seconds, 0)
	end)
end

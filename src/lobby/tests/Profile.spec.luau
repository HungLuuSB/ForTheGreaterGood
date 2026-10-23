--!strict
-- Profiles (L-8): history entries from a config and result, idempotent
-- adds, the history cap, totals that skip cheats and spectating, and
-- migration of damaged records.

local Config = require("../shared/Config")
local Profile = require("../shared/Profile")
local RunAll = require("../../server/Tests/RunAll")

local CONFIG: any = {
	matchId = "m1",
	mapId = "map:quad",
	mode = "FFA",
	cheats = false,
	players = {
		{ id = 1, user = 10, faction = "order" },
		{ id = 2, user = 20, faction = "chaos" },
		{ id = 3, ai = "hard", faction = "chaos" },
	},
	spectators = { { user = 30, name = "Cee" } },
}
local RESULT: any = {
	outcome = "finished",
	winner = 2,
	seconds = 300,
	endedAt = 5000,
	cheatsUsed = false,
	players = { { id = 1, won = false }, { id = 2, won = true }, { id = 3, won = false } },
}

return function(t: RunAll.Context)
	t.test("entries say won, lost, spectated or abandoned", function()
		t.equal(Profile.entryFor(CONFIG, RESULT, 20, "Quad", 0).result, "won")
		t.equal(Profile.entryFor(CONFIG, RESULT, 10, "Quad", 0).result, "lost")
		t.equal(Profile.entryFor(CONFIG, RESULT, 30, "Quad", 0).result, "spectated")
		local dead = Profile.entryFor(CONFIG, nil, 10, "Quad", 777)
		t.equal(dead.result, "abandoned")
		t.equal(dead.at, 777)
		local e = Profile.entryFor(CONFIG, RESULT, 10, "Quad", 0)
		t.equal(e.faction, "order")
		t.equal(e.players, 3)
		t.equal(e.ai, 1)
		t.equal(e.at, 5000)
	end)

	t.test("every human out while AI fight on: finished with no winner, a loss", function()
		local r = table.clone(RESULT)
		r.winner = nil
		r.players = { { id = 1, won = false }, { id = 2, won = false }, { id = 3, won = false } }
		t.equal(Profile.entryFor(CONFIG, r, 10, "Quad", 0).result, "lost")
		t.equal(Profile.entryFor(CONFIG, r, 20, "Quad", 0).result, "lost")
	end)

	t.test("adding a match twice counts it once", function()
		local p = Profile.new(1)
		t.equal(Profile.addMatch(p, Profile.entryFor(CONFIG, RESULT, 20, "Quad", 0)), true)
		t.equal(Profile.addMatch(p, Profile.entryFor(CONFIG, RESULT, 20, "Quad", 0)), false)
		t.equal(p.played, 1)
		t.equal(p.wins, 1)
		t.equal(p.factions.chaos, 1)
		t.equal(#p.history, 1)
	end)

	t.test("cheat and spectated matches are listed, not counted", function()
		local p = Profile.new(1)
		local cheat = table.clone(CONFIG)
		cheat.matchId, cheat.cheats = "m2", true
		Profile.addMatch(p, Profile.entryFor(cheat, RESULT, 20, "Quad", 0))
		Profile.addMatch(p, Profile.entryFor(CONFIG, RESULT, 30, "Quad", 0))
		t.equal(#p.history, 2)
		t.equal(p.played, 0)
		t.equal(p.wins, 0)
	end)

	t.test("history keeps the newest entries up to the cap", function()
		local p = Profile.new(1)
		for i = 1, Config.HISTORY_MAX + 5 do
			local c = table.clone(CONFIG)
			c.matchId = `m{i}`
			Profile.addMatch(p, Profile.entryFor(c, RESULT, 10, "Quad", 0))
		end
		t.equal(#p.history, Config.HISTORY_MAX)
		t.equal(p.history[1].matchId, `m{Config.HISTORY_MAX + 5}`)
		t.equal(p.losses, Config.HISTORY_MAX + 5)
	end)

	t.test("damaged records migrate to defaults", function()
		local p = Profile.migrate({ played = -3, wins = "x", factions = { order = 2, evil = 9 }, history = { 1, { matchId = "a", result = "won" } } }, 99)
		t.equal(p.played, 0)
		t.equal(p.wins, 0)
		t.equal(p.factions.order, 2)
		t.equal(p.factions.evil, nil)
		t.equal(#p.history, 1)
		t.equal(Profile.migrate(nil, 5).created, 5)
	end)

	t.test("summary: win rate over decided matches, favourite faction", function()
		local p = Profile.new(1)
		p.wins, p.losses, p.draws, p.factions = 3, 1, 4, { order = 1, chaos = 7 }
		local s = Profile.summary(p)
		t.equal(s.winRate, 0.75)
		t.equal(s.favourite, "chaos")
		t.equal(Profile.summary(Profile.new(1)).winRate, nil)
	end)
end

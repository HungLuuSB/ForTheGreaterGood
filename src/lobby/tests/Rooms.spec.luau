--!strict
-- Battle rooms (L-3): creating, joining, seats and spectators, host
-- migration, kicks, the host's settings and AI, players' own choices,
-- readiness and every start rule; requests from the wrong member refused.

local Config = require("../shared/Config")
local Rooms = require("../shared/Rooms")
local RunAll = require("../../server/Tests/RunAll")

local MAPS: { Rooms.MapInfo } = {
	{ id = "map:duel", name = "Duel", starts = 2 },
	{ id = "map:quad", name = "Quad", starts = 4 },
	{ id = "map:big", name = "Big", starts = 16 },
}

local HOST, B, C, D = 1, 2, 3, 4

local function room(opts: any?): Rooms.Room
	local r, err = Rooms.new("r1", opts or { name = "Test room", privacy = "public", maxPlayers = 8 }, HOST, "Host", MAPS)
	assert(r, err)
	return r
end

return function(t: RunAll.Context)
	t.test("a new room seats its host, on the first map", function()
		local r = room()
		t.equal(r.host, HOST)
		t.equal(#r.members, 1)
		t.equal(#r.slots, 1)
		t.equal(r.slots[1].user, HOST)
		t.equal(r.settings.mapId, "map:duel")
		t.equal(r.phase, "setup")
	end)

	t.test("bad room options are refused", function()
		local function bad(opts: any, pattern: string)
			local r, err = Rooms.new("x", opts, HOST, "Host", MAPS)
			t.equal(r, nil)
			t.expect(err and string.find(err, pattern), `expected "{pattern}", got {err}`)
		end
		bad({ name = "ab", privacy = "public" }, "3 to 32")
		bad({ name = string.rep("x", 33), privacy = "public" }, "3 to 32")
		bad({ name = 5, privacy = "public" }, "Name")
		bad({ name = "Fine", privacy = "everyone" }, "who can join")
		bad({ name = "Fine", privacy = "public", maxPlayers = 1 }, "2 to 16")
		bad({ name = "Fine", privacy = "public", maxPlayers = 2.5 }, "2 to 16")
		bad({ name = "Fine", privacy = "public", password = string.rep("p", 33) }, "Passwords")
	end)

	t.test("names are trimmed and lose control characters", function()
		local r = room({ name = "  My\nroom\t ", privacy = "public" })
		t.equal(r.name, "Myroom")
	end)

	t.test("joining seats players while the map has starts, then spectators", function()
		local r = room()
		t.equal(Rooms.join(r, MAPS, B, "B", nil), nil)
		t.equal(Rooms.join(r, MAPS, C, "C", nil), nil)
		t.equal(#r.slots, 2) -- Duel has two starts
		t.equal(Rooms.slotOf(r, C), nil)
		t.equal(#r.members, 3)
		t.notEqual(r.slots[1].color, r.slots[2].color)
	end)

	t.test("full rooms, passwords and running matches refuse joins", function()
		local r = room({ name = "Locked", privacy = "public", password = "pw", maxPlayers = 2 })
		t.equal(Rooms.join(r, MAPS, B, "B", "nope"), "Wrong password")
		t.equal(Rooms.join(r, MAPS, B, "B", nil), "Wrong password")
		t.equal(Rooms.join(r, MAPS, B, "B", "pw"), nil)
		t.equal(Rooms.join(r, MAPS, C, "C", "pw"), "This room is full")
		local r2 = room()
		Rooms.setPhase(r2, "match", "m1")
		t.equal(Rooms.join(r2, MAPS, B, "B", nil), "This room is in a match")
	end)

	t.test("a leaving host passes the room to the next member here", function()
		local r = room()
		Rooms.join(r, MAPS, B, "B", nil)
		Rooms.join(r, MAPS, C, "C", nil)
		Rooms.setAway(r, B, true)
		t.equal(Rooms.leave(r, HOST), false)
		t.equal(r.host, C) -- B is away
		t.equal(Rooms.slotOf(r, HOST), nil)
		t.equal(Rooms.leave(r, C), false)
		t.equal(r.host, B) -- only away members left
		t.equal(Rooms.leave(r, B), true) -- empty: close
	end)

	t.test("only the host kicks, and not themselves", function()
		local r = room()
		Rooms.join(r, MAPS, B, "B", nil)
		Rooms.join(r, MAPS, C, "C", nil)
		t.equal(Rooms.apply(r, MAPS, B, { op = "kick", user = C }), "Only the host can do that")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "kick", user = HOST }), "Not a member")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "kick", user = B }), nil)
		t.equal(Rooms.member(r, B), nil)
		t.equal(Rooms.slotOf(r, B), nil)
	end)

	t.test("the host's settings are checked and unready everyone", function()
		local r = room()
		Rooms.join(r, MAPS, B, "B", nil)
		t.equal(Rooms.apply(r, MAPS, B, { op = "ready", value = true }), nil)
		t.equal(Rooms.apply(r, MAPS, B, { op = "set", key = "mode", value = "TEAM" }), "Only the host can do that")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "mode", value = "TEAMS" }), "Bad setting")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "friendlyFire", value = "no" }), "Bad setting")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:nowhere" }), "Unknown map")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "password", value = "x" }), "Bad setting")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:quad" }), nil)
		t.equal((Rooms.member(r, B) :: any).ready, false)
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "set", key = "win", value = "ANNIHILATION" }), nil)
		t.equal(r.settings.win, "ANNIHILATION")
	end)

	t.test("in free for all, a map with fewer starts than seats is refused", function()
		local r = room()
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:quad" })
		Rooms.apply(r, MAPS, HOST, { op = "addAi" })
		Rooms.apply(r, MAPS, HOST, { op = "addAi" })
		local err = Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:duel" })
		t.equal(err, "Duel seats 2 here: remove AI or players first")
		t.equal(r.settings.mapId, "map:quad")
	end)

	t.test("AI slots: added up to the map's starts, edited and removed by the host", function()
		local r = room()
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "addAi", level = "hard", faction = "order" }), nil)
		t.equal(r.slots[2].kind, "ai")
		t.equal(r.slots[2].level, "hard")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "addAi" }), "No free seat on this map")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "ai", index = 2, level = "insane" }), "Bad level")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "ai", index = 1, level = "easy" }), "Not an AI slot")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "ai", index = 2, level = "easy", faction = "chaos", team = 2 }), nil)
		t.equal(r.slots[2].level, "easy")
		t.equal(r.slots[2].faction, "chaos")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "ai", index = 2, color = r.slots[1].color }), "That color is taken")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "removeAi", index = 1 }), "Not an AI slot")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "removeAi", index = 2 }), nil)
		t.equal(#r.slots, 1)
	end)

	t.test("players set their own faction, team and color; nobody else's", function()
		local r = room()
		Rooms.join(r, MAPS, B, "B", nil)
		t.equal(Rooms.apply(r, MAPS, B, { op = "mine", faction = "chaos", team = 2, color = 5 }), nil)
		local i = Rooms.slotOf(r, B) :: number
		t.equal(r.slots[i].faction, "chaos")
		t.equal(r.slots[i].team, 2)
		t.equal(r.slots[i].color, 5)
		t.equal(Rooms.apply(r, MAPS, B, { op = "mine", faction = "neutral" }), "Bad faction")
		t.equal(Rooms.apply(r, MAPS, B, { op = "mine", team = 9 }), "Bad team")
		t.equal(Rooms.apply(r, MAPS, B, { op = "mine", color = #Config.COLORS + 1 }), "Bad color")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "mine", color = 5 }), "That color is taken")
		t.equal(Rooms.apply(r, MAPS, B, { op = "ai", index = 1, faction = "chaos" }), "Only the host can do that")
	end)

	t.test("spectating frees the seat; playing takes one if a start is free", function()
		local r = room()
		Rooms.join(r, MAPS, B, "B", nil)
		Rooms.join(r, MAPS, C, "C", nil)
		t.equal(Rooms.apply(r, MAPS, C, { op = "play" }), "No free seat on this map")
		t.equal(Rooms.apply(r, MAPS, C, { op = "ready", value = true }), "Spectators don't ready up")
		t.equal(Rooms.apply(r, MAPS, B, { op = "spectate" }), nil)
		t.equal(Rooms.apply(r, MAPS, C, { op = "play" }), nil)
		t.notEqual(Rooms.slotOf(r, C), nil)
	end)

	t.test("strangers and non-table requests are refused", function()
		local r = room()
		t.equal(Rooms.apply(r, MAPS, D, { op = "ready", value = true }), "You're not in this room")
		t.equal(Rooms.apply(r, MAPS, HOST, "start" :: any), "Bad request")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "explode" }), "Unknown request")
	end)

	t.test("starting needs two players, a human, the starts and everyone ready", function()
		local r = room()
		t.expect(string.find(Rooms.checkStart(r, MAPS, HOST, false) or "", "Two players"))
		Rooms.join(r, MAPS, B, "B", nil)
		t.equal(Rooms.checkStart(r, MAPS, B, false), "Only the host can start")
		t.equal(Rooms.checkStart(r, MAPS, HOST, false), "Waiting for B to ready up")
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), nil) -- force skips only the ready check
		Rooms.apply(r, MAPS, B, { op = "ready", value = true })
		t.equal(Rooms.checkStart(r, MAPS, HOST, false), nil)
	end)

	t.test("Teams: 2 sides up to the map's starts (at most 8), any size, 16 in all (S-169, S-171)", function()
		local r = room()
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mode", value = "TEAM" })
		Rooms.apply(r, MAPS, HOST, { op = "mine", team = 1 })
		Rooms.apply(r, MAPS, HOST, { op = "addAi" })
		Rooms.apply(r, MAPS, HOST, { op = "ai", index = 2, team = 1 })
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), "Teams needs two teams or more")
		-- a two-start map seats more than two: sides are what the starts cap
		for _ = 1, 6 do
			t.equal(Rooms.apply(r, MAPS, HOST, { op = "addAi" }), nil)
			Rooms.apply(r, MAPS, HOST, { op = "ai", index = #r.slots, team = 2 })
		end
		t.equal(#r.slots, 8)
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), nil, "4 against 4 on a duel map")
		Rooms.apply(r, MAPS, HOST, { op = "ai", index = #r.slots, team = 3 })
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), "Duel has 2 starts: up to 2 teams")
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:quad" })
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), nil, "three sides on a four-start map")
		for _ = 1, 20 do
			Rooms.apply(r, MAPS, HOST, { op = "addAi" })
		end
		t.equal(#r.slots, Config.MAX_SEATS)
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "addAi" }), "No free seat on this map")
		-- back to free for all: one per start
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mode", value = "FFA" })
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), "Free for all on Quad is up to 4 players")
	end)

	t.test("free for all seats one player per start, up to 16", function()
		local r = room()
		Rooms.apply(r, MAPS, HOST, { op = "set", key = "mapId", value = "map:big" })
		for _ = 1, 20 do
			Rooms.apply(r, MAPS, HOST, { op = "addAi" })
		end
		t.equal(#r.slots, math.min(16, 16))
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), nil)
		local q = room()
		Rooms.apply(q, MAPS, HOST, { op = "set", key = "mapId", value = "map:quad" })
		for _ = 1, 6 do
			Rooms.apply(q, MAPS, HOST, { op = "addAi" })
		end
		t.equal(#q.slots, 4)
		t.equal(Rooms.apply(q, MAPS, HOST, { op = "set", key = "mapId", value = "map:duel" }), "Duel seats 2 here: remove AI or players first")
	end)

	t.test("nothing changes while starting or in a match; away members keep seats", function()
		local r = room()
		Rooms.join(r, MAPS, B, "B", nil)
		Rooms.setPhase(r, "starting", "m1")
		t.equal(Rooms.apply(r, MAPS, HOST, { op = "addAi" }), "The match is on")
		t.equal(Rooms.checkStart(r, MAPS, HOST, true), "Already starting")
		Rooms.setPhase(r, "match", "m1")
		t.equal((Rooms.member(r, B) :: any).away, true)
		t.notEqual(Rooms.slotOf(r, B), nil)
		Rooms.setPhase(r, "setup", nil)
		t.equal((Rooms.member(r, B) :: any).away, false)
	end)

	t.test("the browser sees public rooms, friends rooms only as a friend, private ones only inside", function()
		local r = room()
		local function never(_: number, _: number): boolean
			return false
		end
		local function always(_: number, _: number): boolean
			return true
		end
		t.equal(Rooms.visibleTo(r, D, never), true)
		r.privacy = "friends"
		t.equal(Rooms.visibleTo(r, D, never), false)
		t.equal(Rooms.visibleTo(r, D, always), true)
		r.privacy = "private"
		t.equal(Rooms.visibleTo(r, D, always), false)
		t.equal(Rooms.visibleTo(r, HOST, never), true)
	end)

	t.test("views never carry the password", function()
		local r = room({ name = "Secret", privacy = "public", password = "hunter2" })
		local v = Rooms.view(r)
		t.equal(v.password, nil)
		t.equal(v.locked, true)
		local s = Rooms.summary(r, MAPS)
		t.equal(s.password, nil)
		t.equal(s.locked, true)
		for _, value in v do
			t.notEqual(value, "hunter2")
		end
	end)
end

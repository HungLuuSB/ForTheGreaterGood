--!strict
-- Rooms across lobby servers (L-15): a server's entry, the other servers'
-- live entries, what the browser may show, the checks before a hop, and
-- invite launch data (L-17).

local Config = require("../shared/Config")
local Listing = require("../shared/Listing")
local Rooms = require("../shared/Rooms")
local RunAll = require("../../server/Tests/RunAll")

local MAPS: { Rooms.MapInfo } = {
	{ id = "map:duel", name = "Duel", starts = 2 },
	{ id = "map:quad", name = "Quad", starts = 4 },
}

local HOST, FRIEND, STRANGER = 1, 2, 3

local function isFriend(a: number, b: number): boolean
	local lo, hi = math.min(a, b), math.max(a, b)
	return a == b or (lo == HOST and hi == FRIEND)
end

local function room(id: string, privacy: string, password: string?): Rooms.Room
	local r, err = Rooms.new(id, { name = `Room {id}`, privacy = privacy, password = password, maxPlayers = 4 }, HOST, "Host", MAPS)
	assert(r, err)
	return r
end

local function entryOf(job: string, at: number, rooms: { Rooms.Room }): Listing.Entry
	local summaries = {}
	for i, r in rooms do
		summaries[i] = Rooms.summary(r, MAPS)
	end
	return Listing.entry(job, 77, at, 5, rooms, summaries)
end

return function(t: RunAll.Context)
	t.test("an entry lists every room with its privacy, password and host", function()
		local e = entryOf("job-a", 100, { room("AAAAA", "public"), room("BBBBB", "private", "pw") })
		t.equal(e.version, Listing.VERSION)
		t.equal(e.jobId, "job-a")
		t.equal(e.placeId, 77)
		t.equal(#e.rooms, 2)
		t.equal(e.rooms[2].privacy, "private")
		t.equal(e.rooms[2].password, "pw")
		t.equal(e.rooms[1].hostUser, HOST)
		t.equal(e.rooms[1].mapName, "Duel")
		t.equal(e.rooms[1].members, 1)
	end)

	t.test("others drops our own, stale and damaged entries", function()
		local now = 1000
		local list: { any } = {
			entryOf("self", now, { room("AAAAA", "public") }),
			entryOf("live", now - 5, { room("BBBBB", "public") }),
			entryOf("stale", now - Config.LIST_TTL - 1, { room("CCCCC", "public") }),
			{ version = 99, jobId = "future", at = now, rooms = {} },
			"junk",
			{ jobId = "norooms", version = Listing.VERSION, at = now },
		}
		local others = Listing.others(list, "self", now)
		t.equal(#others, 1)
		t.equal(others[1].jobId, "live")
		t.equal(Listing.online(others, 3), 8)
	end)

	t.test("the browser shows public rooms, friends-only ones to friends, private ones never", function()
		local e = entryOf("job", 0, { room("AAAAA", "public"), room("BBBBB", "friends"), room("CCCCC", "private") })
		t.expect(Listing.visible(e.rooms[1], STRANGER, isFriend))
		t.expect(Listing.visible(e.rooms[2], FRIEND, isFriend))
		t.expect(not Listing.visible(e.rooms[2], STRANGER, isFriend))
		t.expect(not Listing.visible(e.rooms[3], FRIEND, isFriend))
		local line = Listing.line(e.rooms[1])
		t.equal(line.remote, true)
		t.equal(line.password, nil)
		t.equal(line.hostUser, nil)
		t.equal(Listing.line(room("DDDDD", "public", "x") :: any).locked, true)
	end)

	t.test("codes are found on any other server, in any case", function()
		local others = { entryOf("a", 0, { room("AAAAA", "public") }), entryOf("b", 0, { room("PRIV2", "private") }) }
		local r, e = Listing.find(others, "priv2")
		t.expect(r ~= nil and e ~= nil)
		t.equal((e :: any).jobId, "b")
		t.equal((Listing.find(others, "ZZZZZ")), nil)
	end)

	t.test("a hop is refused for a full, running, friends-only or locked room", function()
		local open = room("AAAAA", "public")
		local friends = room("BBBBB", "friends")
		local locked = room("CCCCC", "public", "secret")
		local running = room("DDDDD", "public")
		Rooms.setPhase(running, "match", "m1", 50)
		local full = room("EEEEE", "public")
		for u = 10, 12 do
			t.equal(Rooms.join(full, MAPS, u, `P{u}`, nil), nil)
		end
		local e = entryOf("job", 0, { open, friends, locked, running, full })
		t.equal(Listing.checkHop(e.rooms[1], STRANGER, nil, isFriend), nil)
		t.equal(Listing.checkHop(e.rooms[2], FRIEND, nil, isFriend), nil)
		t.equal(Listing.checkHop(e.rooms[2], STRANGER, nil, isFriend), "Only the host's friends can join")
		t.equal(Listing.checkHop(e.rooms[3], STRANGER, nil, isFriend), "That room has a password")
		t.equal(Listing.checkHop(e.rooms[3], STRANGER, "nope", isFriend), "Wrong password")
		t.equal(Listing.checkHop(e.rooms[3], STRANGER, "secret", isFriend), nil)
		t.equal(Listing.checkHop(e.rooms[4], STRANGER, nil, isFriend), "That room is in a match")
		t.equal(e.rooms[4].startedAt, 50)
		t.equal(Listing.checkHop(e.rooms[5], STRANGER, nil, isFriend), "That room is full")
	end)

	t.test("invite launch data carries a room code and nothing else", function()
		t.equal(Listing.launchData("AB2CD"), "room=AB2CD")
		t.equal(Listing.launchCode("room=ab2cd"), "AB2CD")
		t.equal(Listing.launchCode(Listing.launchData("XY9ZW")), "XY9ZW")
		t.equal(Listing.launchCode("room=TOOLONG"), nil)
		t.equal(Listing.launchCode("room=AB CD"), nil)
		t.equal(Listing.launchCode("match=ABCDE"), nil)
		t.equal(Listing.launchCode(nil), nil)
		t.equal(Listing.launchCode({ room = "ABCDE" }), nil)
		t.equal(Listing.launchCode(string.rep("x", 100)), nil)
	end)

	t.test("a room's match start time comes and goes with the phase", function()
		local r = room("AAAAA", "public")
		Rooms.setPhase(r, "match", "m1", 1234)
		t.equal(Rooms.view(r).startedAt, 1234)
		t.equal(Rooms.summary(r, MAPS).startedAt, 1234)
		Rooms.setPhase(r, "setup", nil)
		t.equal(r.startedAt, nil)
	end)
end

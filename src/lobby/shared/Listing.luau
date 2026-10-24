--!strict
-- Rooms across lobby servers (L-15), the pure part: what a lobby server
-- writes about its rooms to the shared list, what it makes of the other
-- servers' entries, and the checks before a player moves to a room on
-- another server. The server side (server/Lobbies.luau) does the reads,
-- writes and teleports.
--
-- One entry per lobby server, keyed by its JobId:
--   { version, jobId, placeId, at, players, rooms = { Listed } }
-- Private rooms are listed too, so their code works from any server, but
-- no browser shows them. Passwords are listed for the origin server's
-- check: the list is MemoryStore, which only servers can read.

local Config = require("./Config")

local Listing = {}

Listing.VERSION = 1

export type Listed = {
	id: string,
	name: string,
	privacy: string,
	password: string?,
	hostUser: number,
	host: string,
	members: number,
	maxPlayers: number,
	ai: number,
	mapId: string,
	mapName: string,
	starts: number,
	mode: string,
	phase: string,
	startedAt: number?,
}

export type Entry = {
	version: number,
	jobId: string,
	placeId: number,
	at: number,
	players: number,
	rooms: { Listed },
}

-- This server's entry. `summaries` are Rooms.summary lines, `rooms` the
-- rooms they came from (for privacy, password and host), in the same order.
function Listing.entry(jobId: string, placeId: number, now: number, players: number, rooms: { any }, summaries: { any }): Entry
	local out = {}
	for i, r in rooms do
		local s = summaries[i]
		table.insert(out, {
			id = r.id,
			name = r.name,
			privacy = r.privacy,
			password = r.password,
			hostUser = r.host,
			host = s.host,
			members = s.members,
			maxPlayers = s.maxPlayers,
			ai = s.ai,
			mapId = s.mapId,
			mapName = s.mapName,
			starts = s.starts,
			mode = s.mode,
			phase = s.phase,
			startedAt = s.startedAt,
		})
	end
	return { version = Listing.VERSION, jobId = jobId, placeId = placeId, at = now, players = players, rooms = out }
end

local function fresh(e: any, self: string, now: number): boolean
	return type(e) == "table"
		and e.version == Listing.VERSION
		and type(e.jobId) == "string"
		and e.jobId ~= self
		and type(e.at) == "number"
		and now - e.at <= Config.LIST_TTL
		and type(e.rooms) == "table"
end

-- The other servers' live entries (stale, damaged and our own dropped).
function Listing.others(entries: { any }, self: string, now: number): { Entry }
	local out = {}
	for _, e in entries do
		if fresh(e, self, now) then
			table.insert(out, e)
		end
	end
	return out
end

-- Players on every lobby server: ours (counted live) plus the others'.
function Listing.online(others: { Entry }, here: number): number
	local n = here
	for _, e in others do
		n += if type(e.players) == "number" then e.players else 0
	end
	return n
end

-- May `user` see a listed room in the browser? Private ones never show.
function Listing.visible(r: Listed, user: number, isFriend: (number, number) -> boolean): boolean
	if r.privacy == "public" then
		return true
	end
	if r.privacy == "friends" then
		return isFriend(user, r.hostUser)
	end
	return false
end

-- A browser line for a room on another server (no password, no host ID).
function Listing.line(r: Listed): any
	return {
		id = r.id,
		name = r.name,
		privacy = r.privacy,
		locked = r.password ~= nil,
		host = r.host,
		members = r.members,
		maxPlayers = r.maxPlayers,
		ai = r.ai,
		mapId = r.mapId,
		mapName = r.mapName,
		starts = r.starts,
		mode = r.mode,
		phase = r.phase,
		startedAt = r.startedAt,
		remote = true,
	}
end

-- The room with code `id` on another server, and that server's entry.
function Listing.find(others: { Entry }, id: string): (Listed?, Entry?)
	local code = string.upper(id)
	for _, e in others do
		for _, r in e.rooms do
			if r.id == code then
				return r, e
			end
		end
	end
	return nil, nil
end

-- May `user` move to a listed room? nil, or why not. The room's own server
-- checks again when they arrive (Rooms.join); this saves a pointless trip.
function Listing.checkHop(r: Listed, user: number, password: any, isFriend: (number, number) -> boolean): string?
	if r.phase ~= "setup" then
		return "That room is in a match"
	end
	if r.members >= r.maxPlayers then
		return "That room is full"
	end
	if r.privacy == "friends" and not isFriend(user, r.hostUser) then
		return "Only the host's friends can join"
	end
	if r.password ~= nil and password ~= r.password then
		return if password == nil or password == "" then "That room has a password" else "Wrong password"
	end
	return nil
end

-- A room code from an invite's launch data ("room=ABCDE"), or nil.
function Listing.launchCode(data: any): string?
	if type(data) ~= "string" or #data > 64 then
		return nil
	end
	local code = string.match(data, "^room=(%w+)$")
	if code == nil or #code ~= 5 then
		return nil
	end
	return string.upper(code)
end

-- The launch data an invite to room `id` carries.
function Listing.launchData(id: string): string
	return `room={id}`
end

return Listing

--!strict
-- The rooms on this lobby server (L-3): create, find, join, leave, close,
-- with each member's chat channel kept in step. One room per player.

local Chat = require("./Chat")
local Config = require("../shared/Config")
local Rooms = require("../shared/Rooms")

local Directory = {}

local rooms: { [string]: Rooms.Room } = {}
local roomOf: { [number]: string } = {}
local rng = Random.new()

Directory.rooms = rooms

-- Is a code in use on another lobby server? (Lobbies sets it, L-15.)
Directory.taken = function(_id: string): boolean
	return false
end

-- A short code players can share for private rooms: no 0/O, 1/I. Unique
-- across the lobby servers, as far as the shared room list knows.
local CODE = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local function newId(): string
	while true do
		local s = ""
		for _ = 1, 5 do
			local i = rng:NextInteger(1, #CODE)
			s ..= string.sub(CODE, i, i)
		end
		if rooms[s] == nil and not Directory.taken(s) then
			return s
		end
	end
end
Directory.newId = newId

function Directory.get(id: any): Rooms.Room?
	return if type(id) == "string" then rooms[string.upper(id)] else nil
end

function Directory.roomOf(user: number): Rooms.Room?
	local id = roomOf[user]
	return if id then rooms[id] else nil
end

function Directory.byMatch(matchId: string): Rooms.Room?
	for _, r in rooms do
		if r.matchId == matchId then
			return r
		end
	end
	return nil
end

local function attach(room: Rooms.Room, user: number)
	roomOf[user] = room.id
	Chat.add(room.id, user)
end

function Directory.close(room: Rooms.Room)
	for _, m in room.members do
		if roomOf[m.user] == room.id then
			roomOf[m.user] = nil
		end
	end
	rooms[room.id] = nil
	Chat.close(room.id)
end

-- Leaves (or is removed from) their room; closes it when empty.
function Directory.leave(user: number)
	local room = Directory.roomOf(user)
	roomOf[user] = nil
	if room == nil then
		return
	end
	Chat.remove(room.id, user)
	if Rooms.leave(room, user) then
		Directory.close(room)
	end
end

function Directory.create(opts: Rooms.NewRoom, user: number, name: string, maps: { Rooms.MapInfo }): (Rooms.Room?, string?)
	local count = 0
	for _ in rooms do
		count += 1
	end
	if count >= Config.MAX_ROOMS then
		return nil, "This lobby server is full of rooms: join one"
	end
	local room, err = Rooms.new(newId(), opts, user, name, maps)
	if room == nil then
		return nil, err
	end
	Directory.leave(user)
	rooms[room.id] = room
	attach(room, user)
	return room, nil
end

function Directory.join(room: Rooms.Room, user: number, name: string, password: any, maps: { Rooms.MapInfo }): string?
	if roomOf[user] == room.id then
		return nil
	end
	local err = Rooms.join(room, maps, user, name, password)
	if err then
		return err
	end
	local old = Directory.roomOf(user)
	if old then
		-- out of the old room only once the new one took them
		roomOf[user] = nil
		Chat.remove(old.id, user)
		if Rooms.leave(old, user) then
			Directory.close(old)
		end
	end
	attach(room, user)
	return nil
end

-- A room rebuilt from a match record, when players come back to a lobby
-- server that isn't the one they left from (contract section 6). Its seats
-- are the match's; `user` is the first one back and hosts. `saved` is the
-- lobby's own record of the room (privacy, password, size), if it survived.
function Directory.recreate(config: any, saved: any, user: number): Rooms.Room
	local privacy = if type(saved) == "table" and table.find(Config.PRIVACY, saved.privacy) then saved.privacy else "private"
	local password = if type(saved) == "table" and type(saved.password) == "string" then saved.password else nil
	local maxPlayers = if type(saved) == "table" and type(saved.maxPlayers) == "number" then saved.maxPlayers else Config.DEFAULT_PLAYERS
	local room: Rooms.Room = {
		id = newId(),
		name = config.lobby.roomName,
		privacy = privacy,
		password = password,
		maxPlayers = math.max(maxPlayers, #config.players + #config.spectators),
		host = user,
		members = {},
		slots = {},
		settings = { mapId = config.mapId, mode = config.mode, win = config.win, friendlyFire = config.friendlyFire, cheats = config.cheats },
		phase = "match",
		matchId = config.matchId,
		startedAt = config.createdAt,
		notice = nil,
		results = nil,
		version = 1,
	}
	for _, p in config.players do
		table.insert(room.slots, {
			kind = if p.ai then "ai" else "human",
			user = p.user,
			faction = p.faction,
			team = p.allyTeam,
			color = p.color,
			level = p.ai or "normal",
		})
		if p.user then
			table.insert(room.members, { user = p.user, name = p.name, ready = false, away = true })
		end
	end
	for _, s in config.spectators do
		table.insert(room.members, { user = s.user, name = s.name, ready = false, away = true })
	end
	rooms[room.id] = room
	return room
end

-- A room made elsewhere joins this server's (the Studio stand-in peer's
-- rooms, when a player "moves" to them).
function Directory.adopt(room: Rooms.Room)
	rooms[room.id] = room
end

-- A member of a room on this server (back from the match) takes their place.
function Directory.attach(room: Rooms.Room, user: number)
	local old = Directory.roomOf(user)
	if old and old ~= room then
		Directory.leave(user)
	end
	attach(room, user)
end

return Directory

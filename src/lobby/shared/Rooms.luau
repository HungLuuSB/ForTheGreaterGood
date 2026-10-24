--!strict
-- One battle room (L-3), BAR style: pure Luau, no Instances, so the server
-- runs it and the Lune specs test it. The server owns every room; clients
-- only send requests, and every request is checked here before it changes
-- anything (guide 19).
--
-- A room has members (the humans in it, in join order) and slots (who plays:
-- the humans who sit and the AI). A member without a slot spectates. The
-- host (a member) changes the settings, the AI and starts; each player picks
-- their own faction, team and color and readies up. Phases:
--   setup     the room is open; settings and seats change
--   starting  the server is reserving and teleporting (nothing changes)
--   match     the match runs; members are away (they keep their seats)
-- and back to setup with the results.

local Config = require("./Config")

local Rooms = {}

export type MapInfo = { id: string, name: string, starts: number }

export type Member = {
	user: number,
	name: string,
	ready: boolean,
	away: boolean, -- in the match (or teleporting there)
}

export type Slot = {
	kind: string, -- "human" | "ai"
	user: number?, -- a human's UserId
	faction: string,
	team: number, -- ally team 1..MAX_ALLY_TEAMS (Teams mode; FFA ignores it)
	color: number, -- index into Config.COLORS
	level: string, -- an AI's difficulty
}

export type Settings = {
	mapId: string,
	mode: string,
	win: string,
	friendlyFire: boolean,
	cheats: boolean,
}

export type Room = {
	id: string,
	name: string,
	privacy: string,
	password: string?, -- never leaves the server (Rooms.view drops it)
	maxPlayers: number,
	host: number,
	members: { Member },
	slots: { Slot },
	settings: Settings,
	phase: string,
	matchId: string?,
	startedAt: number?, -- os.time() when the running match started (the header's "running for")
	notice: string?, -- the last start failure or match news, shown in the room
	results: any?, -- the last match's summary
	version: number, -- bumped on every change
}

local function find(list: { string }, v: any): boolean
	return type(v) == "string" and table.find(list, v) ~= nil
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function mapOf(maps: { MapInfo }, id: string): MapInfo?
	for _, m in maps do
		if m.id == id then
			return m
		end
	end
	return nil
end
Rooms.mapOf = mapOf

local function changed(room: Room)
	room.version += 1
end

-- A room name or password from a client: a string, trimmed, no control
-- characters, within the limits. Returns the clean text or nil and why.
function Rooms.cleanName(v: any): (string?, string?)
	if type(v) ~= "string" or #v > Config.NAME_MAX * 4 then
		return nil, "Name it"
	end
	local s = string.gsub(string.gsub(v, "%c", ""), "^%s*(.-)%s*$", "%1")
	local n = utf8.len(s)
	if n == nil then
		return nil, "That name isn't valid text"
	end
	if n < Config.NAME_MIN or n > Config.NAME_MAX then
		return nil, `Names are {Config.NAME_MIN} to {Config.NAME_MAX} characters`
	end
	return s, nil
end

function Rooms.cleanPassword(v: any): (string?, string?)
	if v == nil or v == "" then
		return nil, nil
	end
	if type(v) ~= "string" or #v > Config.PASSWORD_MAX or string.find(v, "%c") or utf8.len(v) == nil then
		return nil, `Passwords are up to {Config.PASSWORD_MAX} characters`
	end
	return v, nil
end

function Rooms.member(room: Room, user: number): Member?
	for _, m in room.members do
		if m.user == user then
			return m
		end
	end
	return nil
end

function Rooms.slotOf(room: Room, user: number): number?
	for i, s in room.slots do
		if s.kind == "human" and s.user == user then
			return i
		end
	end
	return nil
end

local function freeColor(room: Room): number
	for c = 1, #Config.COLORS do
		local used = false
		for _, s in room.slots do
			if s.color == c then
				used = true
				break
			end
		end
		if not used then
			return c
		end
	end
	return 1
end

-- The ally team with the fewest players among the first two (new seats in
-- Teams balance the sides).
local function lightTeam(room: Room): number
	local count = { 0, 0 }
	for _, s in room.slots do
		if s.team <= 2 then
			count[s.team] += 1
		end
	end
	return if count[2] < count[1] then 2 else 1
end

local function humanCount(room: Room): number
	local n = 0
	for _, s in room.slots do
		if s.kind == "human" then
			n += 1
		end
	end
	return n
end

-- How many play on a map (S-169, S-171: starts are picked in the match's
-- pre-game, so the map's starts only cap the sides): free for all, one per
-- start up to MAX_FFA; Teams, any number per side up to MAX_SEATS.
local function capacity(room: Room, map: MapInfo): number
	if room.settings.mode == "FFA" then
		return math.min(Config.MAX_FFA, map.starts)
	end
	return Config.MAX_SEATS
end
Rooms.capacity = capacity

-- How many sides Teams may have on a map: 2 up to its starts (at most
-- MAX_ALLY_TEAMS).
local function maxSides(map: MapInfo): number
	return math.min(Config.MAX_ALLY_TEAMS, map.starts)
end
Rooms.maxSides = maxSides

-- Seats a member if the map has room; returns whether they sit.
local function seat(room: Room, maps: { MapInfo }, user: number, faction: string?): boolean
	local map = mapOf(maps, room.settings.mapId)
	if map == nil or #room.slots >= capacity(room, map) then
		return false
	end
	table.insert(room.slots, {
		kind = "human",
		user = user,
		faction = faction or "order",
		team = lightTeam(room),
		color = freeColor(room),
		level = "normal",
	})
	return true
end

export type NewRoom = { name: any, privacy: any, password: any, maxPlayers: any }

-- A new room hosted by `user`, who sits in it. Returns the room, or nil and
-- why (bad options).
function Rooms.new(id: string, opts: NewRoom, user: number, userName: string, maps: { MapInfo }): (Room?, string?)
	local name, nameErr = Rooms.cleanName(opts.name)
	if name == nil then
		return nil, nameErr
	end
	if not find(Config.PRIVACY, opts.privacy) then
		return nil, "Pick who can join"
	end
	local password, pwErr = Rooms.cleanPassword(opts.password)
	if pwErr then
		return nil, pwErr
	end
	local maxPlayers = if opts.maxPlayers == nil then Config.DEFAULT_PLAYERS else opts.maxPlayers
	if not isInt(maxPlayers, Config.MIN_PLAYERS, Config.MAX_PLAYERS) then
		return nil, `Rooms hold {Config.MIN_PLAYERS} to {Config.MAX_PLAYERS} players`
	end
	if #maps == 0 then
		return nil, "No maps"
	end
	local room: Room = {
		id = id,
		name = name,
		privacy = opts.privacy :: string,
		password = password,
		maxPlayers = maxPlayers,
		host = user,
		members = { { user = user, name = userName, ready = false, away = false } },
		slots = {},
		settings = { mapId = maps[1].id, mode = "FFA", win = "COMMAND_ENDS", friendlyFire = true, cheats = false },
		phase = "setup",
		matchId = nil,
		notice = nil,
		results = nil,
		version = 1,
	}
	seat(room, maps, user)
	return room, nil
end

-- A member joins. Returns nil, or why not. They sit if the map has a free
-- start, else spectate.
function Rooms.join(room: Room, maps: { MapInfo }, user: number, userName: string, password: any): string?
	if Rooms.member(room, user) then
		return nil
	end
	if room.phase ~= "setup" then
		return "This room is in a match"
	end
	if #room.members >= room.maxPlayers then
		return "This room is full"
	end
	if room.password and password ~= room.password then
		return "Wrong password"
	end
	table.insert(room.members, { user = user, name = userName, ready = false, away = false })
	seat(room, maps, user)
	changed(room)
	return nil
end

-- The next host after `user`: the first member in join order who is here,
-- else the first who is away.
local function nextHost(room: Room, without: number): number?
	for pass = 1, 2 do
		for _, m in room.members do
			if m.user ~= without and (pass == 2 or not m.away) then
				return m.user
			end
		end
	end
	return nil
end

-- A member leaves (or is kicked): their seat goes; a leaving host passes the
-- room on. Returns true when the room is empty and should close.
function Rooms.leave(room: Room, user: number): boolean
	local i = Rooms.slotOf(room, user)
	if i then
		table.remove(room.slots, i)
	end
	for j, m in room.members do
		if m.user == user then
			table.remove(room.members, j)
			break
		end
	end
	if room.host == user then
		local h = nextHost(room, user)
		if h then
			room.host = h
		end
	end
	changed(room)
	return #room.members == 0
end

-- Unready every player (the host changed what they agreed to).
local function unready(room: Room)
	for _, m in room.members do
		m.ready = false
	end
end

-- Applies member `from`'s request. Returns nil, or why it was refused.
--   { op = "set", key = "mapId" | "mode" | "win" | "friendlyFire" | "cheats", value }   host
--   { op = "addAi", faction?, level? }                                         host
--   { op = "ai", index, faction?, level?, team?, color? }                      host, an AI slot
--   { op = "removeAi", index }                                                 host
--   { op = "mine", faction?, team?, color? }                                   a seated member
--   { op = "spectate" } | { op = "play" }                                      a member
--   { op = "ready", value }                                                    a seated member
--   { op = "kick", user }                                                      host
function Rooms.apply(room: Room, maps: { MapInfo }, from: number, msg: any): string?
	if type(msg) ~= "table" then
		return "Bad request"
	end
	local me = Rooms.member(room, from)
	if me == nil then
		return "You're not in this room"
	end
	if room.phase ~= "setup" then
		return "The match is on"
	end
	local host = room.host == from
	local op = msg.op
	if op == "spectate" then
		local i = Rooms.slotOf(room, from)
		if i then
			table.remove(room.slots, i)
			me.ready = false
			changed(room)
		end
		return nil
	elseif op == "play" then
		if Rooms.slotOf(room, from) then
			return nil
		end
		if not seat(room, maps, from) then
			return "No free seat on this map"
		end
		changed(room)
		return nil
	elseif op == "ready" then
		if type(msg.value) ~= "boolean" then
			return "Bad request"
		end
		if Rooms.slotOf(room, from) == nil then
			return "Spectators don't ready up"
		end
		me.ready = msg.value
		changed(room)
		return nil
	elseif op == "mine" then
		local i = Rooms.slotOf(room, from)
		if i == nil then
			return "Take a seat first"
		end
		return Rooms.editSlot(room, i, msg)
	end
	if not host then
		return "Only the host can do that"
	end
	if op == "set" then
		local v = msg.value
		local key = msg.key
		if key == "mapId" then
			local map = if type(v) == "string" then mapOf(maps, v) else nil
			if map == nil then
				return "Unknown map"
			end
			local cap = capacity(room, map)
			if #room.slots > cap then
				return `{map.name} seats {cap} here: remove AI or players first`
			end
			room.settings.mapId = map.id
		elseif key == "mode" and find(Config.MODES, v) then
			room.settings.mode = v
		elseif key == "win" and find(Config.WINS, v) then
			room.settings.win = v
		elseif key == "friendlyFire" and type(v) == "boolean" then
			room.settings.friendlyFire = v
		elseif key == "cheats" and type(v) == "boolean" then
			room.settings.cheats = v
		else
			return "Bad setting"
		end
		unready(room)
		changed(room)
		return nil
	elseif op == "addAi" then
		local map = mapOf(maps, room.settings.mapId)
		if map == nil or #room.slots >= capacity(room, map) then
			return "No free seat on this map"
		end
		if msg.faction ~= nil and not find(Config.FACTIONS, msg.faction) then
			return "Bad faction"
		end
		if msg.level ~= nil and not find(Config.LEVELS, msg.level) then
			return "Bad level"
		end
		table.insert(room.slots, {
			kind = "ai",
			user = nil,
			faction = msg.faction or "chaos",
			team = lightTeam(room),
			color = freeColor(room),
			level = msg.level or "normal",
		})
		changed(room)
		return nil
	elseif op == "ai" then
		if not isInt(msg.index, 1, #room.slots) or room.slots[msg.index].kind ~= "ai" then
			return "Not an AI slot"
		end
		if msg.level ~= nil then
			if not find(Config.LEVELS, msg.level) then
				return "Bad level"
			end
			room.slots[msg.index].level = msg.level
		end
		return Rooms.editSlot(room, msg.index, msg)
	elseif op == "removeAi" then
		if not isInt(msg.index, 1, #room.slots) or room.slots[msg.index].kind ~= "ai" then
			return "Not an AI slot"
		end
		table.remove(room.slots, msg.index)
		changed(room)
		return nil
	elseif op == "kick" then
		if type(msg.user) ~= "number" or msg.user == from or Rooms.member(room, msg.user) == nil then
			return "Not a member"
		end
		Rooms.leave(room, msg.user)
		return nil
	end
	return "Unknown request"
end

-- Faction, team and color of slot `i` (each optional). Colors are unique.
function Rooms.editSlot(room: Room, i: number, msg: any): string?
	local s = room.slots[i]
	if msg.faction ~= nil and not find(Config.FACTIONS, msg.faction) then
		return "Bad faction"
	end
	if msg.team ~= nil and not isInt(msg.team, 1, Config.MAX_ALLY_TEAMS) then
		return "Bad team"
	end
	if msg.color ~= nil then
		if not isInt(msg.color, 1, #Config.COLORS) then
			return "Bad color"
		end
		for j, other in room.slots do
			if j ~= i and other.color == msg.color then
				return "That color is taken"
			end
		end
	end
	s.faction = msg.faction or s.faction
	s.team = msg.team or s.team
	s.color = msg.color or s.color
	changed(room)
	return nil
end

-- Who still has to ready up (names), for the host's start button.
function Rooms.notReady(room: Room): { string }
	local out = {}
	for _, s in room.slots do
		if s.kind == "human" and s.user ~= room.host then
			local m = Rooms.member(room, s.user :: number)
			if m and not m.ready then
				table.insert(out, m.name)
			end
		end
	end
	return out
end

-- Can the host start? nil, or why not. `force` skips the ready check only:
-- every other rule holds for a forced start too.
function Rooms.checkStart(room: Room, maps: { MapInfo }, from: number, force: boolean): string?
	if room.host ~= from then
		return "Only the host can start"
	end
	if room.phase ~= "setup" then
		return "Already starting"
	end
	local map = mapOf(maps, room.settings.mapId)
	if map == nil then
		return "Unknown map"
	end
	if #room.slots < 2 then
		return "Two players or more: add an AI or wait for a player"
	end
	if #room.slots > capacity(room, map) then
		return if room.settings.mode == "FFA" then `Free for all on {map.name} is up to {capacity(room, map)} players` else `Up to {Config.MAX_SEATS} players`
	end
	if humanCount(room) == 0 then
		return "Someone has to play"
	end
	if room.settings.mode ~= "FFA" then
		local count: { [number]: number } = {}
		local teams = 0
		for _, s in room.slots do
			if count[s.team] == nil then
				teams += 1
			end
			count[s.team] = (count[s.team] or 0) + 1
		end
		if teams < 2 then
			return "Teams needs two teams or more"
		end
		if teams > maxSides(map) then
			return `{map.name} has {map.starts} starts: up to {maxSides(map)} teams`
		end
	end
	local colors: { [number]: boolean } = {}
	for _, s in room.slots do
		if colors[s.color] then
			return "Two players share a color"
		end
		colors[s.color] = true
	end
	if not force then
		local waiting = Rooms.notReady(room)
		if #waiting > 0 then
			return `Waiting for {table.concat(waiting, ", ")} to ready up`
		end
	end
	return nil
end

-- Members leave for the match: away, keeping their seats.
-- `now` (os.time()) dates a match's start, for "running for N min".
function Rooms.setPhase(room: Room, phase: string, matchId: string?, now: number?)
	room.phase = phase
	room.matchId = matchId
	room.startedAt = if phase == "match" then now else nil
	for _, m in room.members do
		m.ready = false
		m.away = phase == "match"
	end
	changed(room)
end

function Rooms.setAway(room: Room, user: number, away: boolean)
	local m = Rooms.member(room, user)
	if m and m.away ~= away then
		m.away = away
		changed(room)
	end
end

function Rooms.setNotice(room: Room, notice: string?)
	room.notice = notice
	changed(room)
end

-- Who may see the room in the browser: public rooms to all; friends rooms to
-- the host's friends (`isFriend` asks); private rooms only to their members
-- (others join with the room code).
function Rooms.visibleTo(room: Room, user: number, isFriend: (number, number) -> boolean): boolean
	if Rooms.member(room, user) or room.privacy == "public" then
		return true
	end
	if room.privacy == "friends" then
		return isFriend(user, room.host)
	end
	return false
end

-- The browser's line for a room.
function Rooms.summary(room: Room, maps: { MapInfo }): any
	local map = mapOf(maps, room.settings.mapId)
	local ai = 0
	for _, s in room.slots do
		if s.kind == "ai" then
			ai += 1
		end
	end
	local hostName = ""
	local m = Rooms.member(room, room.host)
	if m then
		hostName = m.name
	end
	return {
		id = room.id,
		name = room.name,
		privacy = room.privacy,
		locked = room.password ~= nil,
		host = hostName,
		members = #room.members,
		maxPlayers = room.maxPlayers,
		ai = ai,
		mapId = room.settings.mapId,
		mapName = if map then map.name else room.settings.mapId,
		starts = if map then map.starts else 0,
		mode = room.settings.mode,
		phase = room.phase,
		startedAt = room.startedAt,
	}
end

-- Everything a member sees of their room (no password).
function Rooms.view(room: Room): any
	local members = {}
	for i, m in room.members do
		members[i] = { user = m.user, name = m.name, ready = m.ready, away = m.away }
	end
	local slots = {}
	for i, s in room.slots do
		slots[i] = { kind = s.kind, user = s.user, faction = s.faction, team = s.team, color = s.color, level = s.level }
	end
	return {
		id = room.id,
		name = room.name,
		privacy = room.privacy,
		locked = room.password ~= nil,
		maxPlayers = room.maxPlayers,
		host = room.host,
		members = members,
		slots = slots,
		settings = table.clone(room.settings),
		phase = room.phase,
		startedAt = room.startedAt,
		notice = room.notice,
		results = room.results,
		version = room.version,
	}
end

return Rooms

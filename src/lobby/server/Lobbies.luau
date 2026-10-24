--!strict
-- Rooms across lobby servers (L-15), the server side. Each lobby server
-- writes its rooms to the shared list (Ctx.index) when they change (at most
-- every LIST_MIN_GAP seconds) and at least every LIST_EVERY, and reads the
-- other servers' entries every LIST_READ_EVERY. The browser shows both.
--
-- Joining a room on another server is a hop: this server checks what it
-- can (Listing.checkHop), writes `hop/<userId>` (the room, the password) to
-- the match store, and teleports the player to that server's JobId. That
-- server reads the key when they arrive and joins them through the usual
-- Rooms.join checks. A failed teleport brings a toast and nothing else.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require("../shared/Config")
local Ctx = require("./Ctx")
local Directory = require("./Directory")
local Listing = require("../shared/Listing")
local Rooms = require("../shared/Rooms")

local Lobbies = {}

local self = if game.JobId ~= "" then game.JobId else "studio-lobby"
Lobbies.self = self

local others: { Listing.Entry } = {}
local hopping: { [number]: string } = {} -- user -> the room's name, while teleporting

local function hopState(user: number, roomName: string?)
	Ctx.send(user, { kind = "hop", active = roomName ~= nil, roomName = roomName })
end

local function sortedRooms(): { Rooms.Room }
	local list = {}
	for _, r in Directory.rooms do
		table.insert(list, r)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

local lastWrite = -math.huge
local lastSig = ""

local function write(force: boolean)
	local rooms = sortedRooms()
	local summaries = {}
	for i, r in rooms do
		summaries[i] = Rooms.summary(r, Ctx.maps)
	end
	local entry = Listing.entry(self, game.PlaceId, 0, #Players:GetPlayers(), rooms, summaries)
	local sig = HttpService:JSONEncode(entry)
	local now = os.clock()
	if not force and (sig == lastSig and now - lastWrite < Config.LIST_EVERY) then
		return
	end
	if now - lastWrite < Config.LIST_MIN_GAP then
		return
	end
	entry.at = os.time()
	if Ctx.index.put(self, entry, Config.LIST_TTL) then
		lastSig = sig
		lastWrite = now
	end
end

local readSig = ""

local function read()
	local ok, values = Ctx.index.list()
	if not ok then
		return
	end
	others = Listing.others(values, self, os.time())
	local parts = {}
	for _, e in others do
		local rooms = table.clone(e.rooms)
		for i, r in rooms do
			-- what the browser shows of it
			rooms[i] = Listing.line(r)
		end
		table.insert(parts, { e.jobId, e.players, rooms })
	end
	local sig = HttpService:JSONEncode(parts)
	if sig ~= readSig then
		readSig = sig
		Ctx.publish()
	end
end

function Lobbies.start()
	Directory.taken = function(id: string): boolean
		return (Listing.find(others, id)) ~= nil
	end
	task.spawn(function()
		while true do
			local ok, err = pcall(write, false)
			if not ok then
				warn(`[Lobby] room list write: {err}`)
			end
			task.wait(1)
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(read)
			if not ok then
				warn(`[Lobby] room list read: {err}`)
			end
			task.wait(if Ctx.studio then 3 else Config.LIST_READ_EVERY)
		end
	end)
	game:BindToClose(function()
		Ctx.index.remove(self)
	end)
	Ctx.teleport.onFailed(function(player: Player, message: string)
		local user = player.UserId
		local name = hopping[user]
		if name == nil then
			return
		end
		hopping[user] = nil
		Ctx.store.remove(`hop/{user}`)
		hopState(user, nil)
		warn(`[Lobby] move of {player.Name} to room "{name}" failed ({message})`)
		Ctx.toast(user, `Couldn't move you to {name}'s lobby server ({message})`, "error")
	end)
	print(`[Lobby] room list: {Ctx.index.kind}, this server {self}`)
end

-- Browser lines for the rooms on other servers that `user` may see.
function Lobbies.lines(user: number, isFriend: (number, number) -> boolean): { any }
	local out = {}
	for _, e in others do
		for _, r in e.rooms do
			if Directory.get(r.id) == nil and Listing.visible(r, user, isFriend) then
				table.insert(out, Listing.line(r))
			end
		end
	end
	return out
end

-- Players on every lobby server.
function Lobbies.online(): number
	return Listing.online(others, #Players:GetPlayers())
end

-- Lobby servers known (this one included).
function Lobbies.servers(): number
	return #others + 1
end

-- The listed room on another server with this code, if any.
function Lobbies.find(code: string): Listing.Listed?
	return (Listing.find(others, code))
end

-- Moves `player` to the room with code `code` on another lobby server.
-- nil once the teleport is on its way, or why not.
function Lobbies.hop(player: Player, code: string, password: any): string?
	local user = player.UserId
	local r, e = Listing.find(others, code)
	if r == nil or e == nil then
		return "No room with that code"
	end
	local err = Listing.checkHop(r, user, password, Ctx.social.isFriend)
	if err then
		return err
	end
	if hopping[user] then
		return "You're already on your way"
	end
	local ok, serr = Ctx.store.set(`hop/{user}`, { roomId = r.id, password = if type(password) == "string" then password else nil, from = self }, Config.HOP_TTL)
	if not ok then
		return `The match store didn't answer ({serr})`
	end
	hopping[user] = r.name
	hopState(user, r.name)
	local sent, terr = Ctx.teleport.toServer({ player }, e.placeId, e.jobId, { hop = r.id })
	if not sent then
		hopping[user] = nil
		Ctx.store.remove(`hop/{user}`)
		hopState(user, nil)
		return `Couldn't move you to that room's server ({terr})`
	end
	print(`[Lobby] {player.Name} moving to room {r.id} on {e.jobId}`)
	return nil
end

-- A player arrived: if they came to join a room here (`hop/<userId>`), join
-- them. Returns whether they had a hop waiting.
function Lobbies.arrive(player: Player): boolean
	local user = player.UserId
	hopping[user] = nil
	local ok, h = Ctx.store.get(`hop/{user}`)
	if not ok or type(h) ~= "table" or type(h.roomId) ~= "string" then
		return false
	end
	Ctx.store.remove(`hop/{user}`)
	hopState(user, nil)
	local room = Directory.get(h.roomId)
	if room == nil then
		Ctx.toast(user, "That room has closed", "error")
		return true
	end
	local current = Directory.roomOf(user)
	if current == room then
		return true
	end
	if current and current.phase ~= "setup" then
		return true -- back from a match into their own room: that wins
	end
	local err: string? = nil
	if room.privacy == "friends" and not Rooms.visibleTo(room, user, Ctx.social.isFriend) then
		err = "Only the host's friends can join"
	else
		err = Directory.join(room, user, player.DisplayName, h.password, Ctx.maps)
	end
	if err then
		Ctx.toast(user, `Couldn't join {room.name}: {err}`, "error")
	else
		print(`[Lobby] {player.Name} joined room {room.id} from server {h.from}`)
	end
	Ctx.publish()
	return true
end

return Lobbies

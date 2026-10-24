--!strict
-- The lobby server (L-3). Clients send requests on LobbyRemotes.Request;
-- every one is rate limited and checked (Rooms, Launcher) before anything
-- changes. Each player gets their own view on LobbyRemotes.Push: the rooms
-- they may see, their room (no passwords), their profile. Map list and
-- previews come from LobbyRemotes.GetMaps.
--
-- In Studio the services are stand-ins (L-6): MemoryStore and DataStore in
-- memory, TeleportService replaced by the in-process stand-in match.
--   client -> server (Request):
--     { op = "create", name, privacy, password?, maxPlayers }
--     { op = "join", roomId, password? }      { op = "leave" }   (a room on another lobby server: a hop, L-15)
--     { op = "start", force? }                { op = "rejoin" }
--     { op = "quick", mapId, faction, level, enemy? }  a skirmish against one AI, started at once
--     { op = "kick", user }                   host
--     { op = "settings", values }             the lobby settings, saved on the profile (L-16)
--     any Rooms.apply request (set, addAi, ai, removeAi, mine, spectate, play, ready)
--     { op = "standIn", action }              Studio only (StandInMatch)
--   server -> client (Push):
--     { kind = "view", view }   { kind = "toast", text, style }   { kind = "standIn", ... }
--     { kind = "hop", active, roomName? }      moving to a room on another lobby server
--     { kind = "askPassword", roomId, name }   an invite to a room with a password
--
-- Invites (L-17): a game invite carries "room=<code>" as launch data; a
-- player who joins with it goes to that room (here or on its server). In
-- Studio, the attribute `StandInLaunch` on ServerScriptService.Lobby stands
-- in for the launch data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Chat = require("./Chat")
local Config = require("../shared/Config")
local Ctx = require("./Ctx")
local Directory = require("./Directory")
local Launcher = require("./Launcher")
local Listing = require("../shared/Listing")
local Lobbies = require("./Lobbies")
local MapPreview = require("../shared/MapPreview")
local MapRegistry = require("@shared/Grid/MapRegistry")
local MatchStore = require("./Services/MatchStore")
local Places = require("./Places")
local Profile = require("../shared/Profile")
local ProfileStore = require("./Services/ProfileStore")
local Profiles = require("./Profiles")
local Returns = require("./Returns")
local RoomIndex = require("./Services/RoomIndex")
local Rooms = require("../shared/Rooms")
local Social = require("./Services/Social")
local StandInMatch = require("./StandInMatch")
local StandInPeer = require("./StandInPeer")
local Teleport = require("./Services/Teleport")

local studio = RunService:IsStudio()
local flags = script.Parent -- ServerScriptService.Lobby: Studio's StandInFail attribute

-- remotes ---------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "LobbyRemotes"
local request = Instance.new("RemoteEvent")
request.Name = "Request"
request.Parent = remotes
local push = Instance.new("RemoteEvent")
push.Name = "Push"
push.Parent = remotes
local getMaps = Instance.new("RemoteFunction")
getMaps.Name = "GetMaps"
getMaps.Parent = remotes

-- context ---------------------------------------------------------------------

local dirty: { [number]: boolean } = {}
local publishing = false
local sendViews: () -> ()

Ctx.studio = studio
Ctx.store = if studio then MatchStore.standIn() else MatchStore.real()
Ctx.teleport = if studio then Teleport.standIn(StandInMatch.start, flags, StandInPeer.hop) else Teleport.real()
Ctx.index = if studio then RoomIndex.standIn() else RoomIndex.real()
Ctx.profiles = if studio then ProfileStore.standIn() else ProfileStore.real()
Ctx.social = if studio then Social.standIn() else Social.real()
Ctx.maps = {}
Ctx.publish = function(user: number?)
	if user then
		dirty[user] = true
	else
		for _, p in Players:GetPlayers() do
			dirty[p.UserId] = true
		end
	end
	if not publishing then
		publishing = true
		-- a closure: the room list's reader can publish before sendViews is defined
		task.defer(function()
			sendViews()
		end)
	end
end
Ctx.toast = function(user: number, text: string, style: string?)
	local p = Players:GetPlayerByUserId(user)
	if p then
		push:FireClient(p, { kind = "toast", text = text, style = style or "info" })
	end
end
Ctx.send = function(user: number, msg: any)
	local p = Players:GetPlayerByUserId(user)
	if p then
		push:FireClient(p, msg)
	end
end
if studio then
	Returns.inStandIn = StandInMatch.has
end
Profiles.init(Ctx.profiles, function(user: number)
	Ctx.publish(user)
end)
Ctx.teleport.onFailed(Launcher.teleportFailed)
print(`[Lobby] services: store {Ctx.store.kind}, teleport {Ctx.teleport.kind}, profiles {Ctx.profiles.kind}, text {Ctx.social.kind}, room list {Ctx.index.kind}`)
task.spawn(Places.init, studio)
Lobbies.start()

-- maps ------------------------------------------------------------------------

local previews: { [string]: MapPreview.Preview } = {}
local mapsReady = false

task.spawn(function()
	local names = {}
	for name in MapRegistry.NAMED do
		table.insert(names, name)
	end
	table.sort(names)
	local handmade = {}
	for name in MapRegistry.HANDMADE do
		table.insert(handmade, name)
	end
	table.sort(handmade)
	table.move(handmade, 1, #handmade, #names + 1, names)
	local list = {}
	for _, name in names do
		local id = "map:" .. name
		local ok, layers = pcall(MapRegistry.load, id)
		if ok and layers then
			local entry = MapRegistry.NAMED[name] or MapRegistry.HANDMADE[name]
			table.insert(list, { id = id, name = entry.name, starts = #layers.starts })
			previews[id] = MapPreview.build(layers, 128)
		else
			warn(`[Lobby] map {id}: {layers}`)
		end
		task.wait()
	end
	Ctx.maps = list
	mapsReady = true
	print(`[Lobby] {#list} maps ready`)
	if studio then
		StandInPeer.start(Lobbies.arrive)
	end
	Ctx.publish()
end)

getMaps.OnServerInvoke = function(_player: Player): any
	if not mapsReady then
		return { ready = false }
	end
	local out = {}
	for _, m in Ctx.maps do
		local p = previews[m.id]
		table.insert(out, { id = m.id, name = m.name, starts = m.starts, preview = p })
	end
	return { ready = true, maps = out }
end

-- views -----------------------------------------------------------------------

local function viewFor(player: Player): any
	local user = player.UserId
	local list = {}
	for _, r in Directory.rooms do
		if Rooms.visibleTo(r, user, Ctx.social.isFriend) then
			table.insert(list, Rooms.summary(r, Ctx.maps))
		end
	end
	-- rooms on the other lobby servers (L-15)
	for _, line in Lobbies.lines(user, Ctx.social.isFriend) do
		table.insert(list, line)
	end
	table.sort(list, function(a, b)
		if (a.phase == "setup") ~= (b.phase == "setup") then
			return a.phase == "setup"
		end
		return a.name < b.name
	end)
	local room = Directory.roomOf(user)
	local roomView = nil
	if room then
		roomView = Rooms.view(room)
		local m = Rooms.mapOf(Ctx.maps, room.settings.mapId)
		roomView.mapName = if m then m.name else room.settings.mapId
		roomView.starts = if m then m.starts else 0
		roomView.notReady = Rooms.notReady(room)
	end
	local rec = Profiles.get(user)
	local online = Lobbies.online()
	return {
		me = { user = user, name = player.DisplayName },
		studio = studio,
		services = { store = Ctx.store.kind, teleport = Ctx.teleport.kind, profiles = Ctx.profiles.kind },
		online = online,
		servers = Lobbies.servers(),
		mapsReady = mapsReady,
		rooms = list,
		room = roomView,
		profile = if rec then { summary = Profile.summary(rec), history = rec.history, settings = rec.settings } else nil,
	}
end

function sendViews()
	publishing = false
	local users = dirty
	dirty = {}
	for user in users do
		local p = Players:GetPlayerByUserId(user)
		if p then
			local ok, view = pcall(viewFor, p)
			if ok then
				push:FireClient(p, { kind = "view", view = view })
			else
				warn(`[Lobby] view for {p.Name}: {view}`)
			end
		end
	end
end

-- requests --------------------------------------------------------------------

local tokens: { [number]: number } = {}
local BURST, REFILL = 10, 5 -- requests, per second

task.spawn(function()
	while true do
		task.wait(0.2)
		for user, n in tokens do
			tokens[user] = math.min(BURST, n + REFILL * 0.2)
		end
	end
end)

-- Joins `player` to the room with this code: one here, or a hop to the
-- lobby server that has it (L-15). nil, or why not. `invited`: from an
-- invite's launch data, so a password room asks for its password.
local function joinByCode(player: Player, code: any, password: any, invited: boolean?): string?
	local user = player.UserId
	if type(code) ~= "string" or #code > 16 then
		return "No room with that code"
	end
	local room = Directory.get(code)
	local current = Directory.roomOf(user)
	if current and current ~= room and current.phase ~= "setup" then
		return "Your room is in a match"
	end
	if room then
		if room.privacy == "friends" and not Rooms.visibleTo(room, user, Ctx.social.isFriend) then
			return "Only the host's friends can join"
		end
		if invited and room.password and Rooms.member(room, user) == nil then
			Ctx.send(user, { kind = "askPassword", roomId = room.id, name = room.name })
			return nil
		end
		return Directory.join(room, user, player.DisplayName, password, Ctx.maps)
	end
	local listed = Lobbies.find(code)
	if listed and invited and listed.password ~= nil then
		Ctx.send(user, { kind = "askPassword", roomId = listed.id, name = listed.name })
		return nil
	end
	return Lobbies.hop(player, code, password)
end

local function handle(player: Player, msg: any): string?
	local user = player.UserId
	local op = msg.op
	if not mapsReady then
		return "The lobby is still loading maps"
	end
	if op == "create" then
		local name, err = Rooms.cleanName(msg.name)
		if name == nil then
			return err
		end
		local filtered, ferr = Ctx.social.filterName(name, user)
		if filtered == nil then
			return ferr
		end
		local current = Directory.roomOf(user)
		if current and current.phase ~= "setup" then
			return "Your room is in a match"
		end
		local room, cerr = Directory.create({ name = filtered, privacy = msg.privacy, password = msg.password, maxPlayers = msg.maxPlayers }, user, player.DisplayName, Ctx.maps)
		if room == nil then
			return cerr
		end
		print(`[Lobby] {player.Name} created room {room.id} "{room.name}" ({room.privacy})`)
		return nil
	elseif op == "join" then
		return joinByCode(player, msg.roomId, msg.password)
	elseif op == "settings" then
		local rec = Profiles.get(user)
		if rec == nil then
			return "Your profile is still loading"
		end
		local clean, refused = Profile.cleanSettings(msg.values, rec.settings)
		if refused then
			return "Those settings aren't valid"
		end
		Profiles.setSettings(user, clean)
		return nil
	elseif op == "leave" then
		local room = Directory.roomOf(user)
		if room and room.phase == "starting" then
			return "The match is starting"
		end
		Directory.leave(user)
		return nil
	elseif op == "kick" then
		local room = Directory.roomOf(user)
		if room == nil or room.host ~= user then
			return "Only the host can do that"
		end
		if room.phase ~= "setup" then
			return "The match is on"
		end
		if type(msg.user) ~= "number" or msg.user == user or Rooms.member(room, msg.user) == nil then
			return "Not a member"
		end
		Directory.leave(msg.user)
		Ctx.toast(msg.user, `You were removed from {room.name}`, "error")
		return nil
	elseif op == "start" then
		local room = Directory.roomOf(user)
		if room == nil then
			return "You're not in a room"
		end
		return Launcher.start(room, user, msg.force == true)
	elseif op == "rejoin" then
		return Launcher.rejoin(player)
	elseif op == "quick" then
		local map = if type(msg.mapId) == "string" then Rooms.mapOf(Ctx.maps, msg.mapId) else Ctx.maps[1]
		if map == nil then
			return "Unknown map"
		end
		local current = Directory.roomOf(user)
		if current and current.phase ~= "setup" then
			return "Your room is in a match"
		end
		local room, err = Directory.create({ name = "Skirmish", privacy = "private", maxPlayers = 2 }, user, player.DisplayName, Ctx.maps)
		if room == nil then
			return err
		end
		local steps = {
			{ op = "set", key = "mapId", value = map.id },
			{ op = "mine", faction = msg.faction },
			{ op = "addAi", level = msg.level, faction = if msg.enemy ~= nil then msg.enemy elseif msg.faction == "order" then "chaos" else "order" },
		}
		for _, step in steps do
			local serr = Rooms.apply(room, Ctx.maps, user, step)
			if serr then
				Directory.leave(user)
				return serr
			end
		end
		return Launcher.start(room, user, true)
	elseif op == "standIn" then
		if studio then
			StandInMatch.control(player, msg.action)
		end
		return nil
	end
	local room = Directory.roomOf(user)
	if room == nil then
		return "You're not in a room"
	end
	return Rooms.apply(room, Ctx.maps, user, msg)
end

request.OnServerEvent:Connect(function(player: Player, msg: any)
	local user = player.UserId
	local t = tokens[user] or BURST
	if t < 1 then
		return -- rate limited: dropped
	end
	tokens[user] = t - 1
	if type(msg) ~= "table" or type(msg.op) ~= "string" then
		return
	end
	local ok, err = pcall(handle, player, msg)
	if not ok then
		warn(`[Lobby] {player.Name} {msg.op}: {err}`)
		err = "Something went wrong"
	end
	if err then
		Ctx.toast(user, err, "error")
	end
	Ctx.publish()
end)

-- players ---------------------------------------------------------------------

local function added(player: Player)
	tokens[player.UserId] = BURST
	task.spawn(Profiles.load, player.UserId)
	local data = player:GetJoinData()
	local hint = type(data) == "table" and type(data.TeleportData) == "table" and data.TeleportData.matchId or nil
	local launch = if type(data) == "table" then data.LaunchData else nil
	if studio and launch == nil then
		launch = flags:GetAttribute("StandInLaunch")
	end
	task.spawn(function()
		-- back from a match, then a move from another lobby server, then an invite
		Returns.arrive(player, hint)
		if Lobbies.arrive(player) then
			return
		end
		local code = Listing.launchCode(launch)
		if code and Directory.roomOf(player.UserId) == nil then
			while not mapsReady do
				task.wait(0.5)
			end
			print(`[Lobby] {player.Name} came from an invite to room {code}`)
			local err = joinByCode(player, code, nil, true)
			if err then
				Ctx.toast(player.UserId, `Couldn't join the room you were invited to: {err}`, "error")
			end
			Ctx.publish()
		end
	end)
	Ctx.publish()
end

Players.PlayerAdded:Connect(added)
for _, p in Players:GetPlayers() do
	task.spawn(added, p)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local user = player.UserId
	tokens[user] = nil
	dirty[user] = nil
	local room = Directory.roomOf(user)
	if room and room.phase ~= "setup" then
		-- in (or on the way to) the match: the seat stays theirs
		Rooms.setAway(room, user, true)
		Chat.remove(room.id, user)
	else
		Directory.leave(user)
	end
	Profiles.unload(user)
	Ctx.publish()
end)

remotes.Parent = ReplicatedStorage
print(`[Lobby] server ready (match place setting {Config.MATCH_PLACE_ID}{if Config.MATCH_PLACE_ID == 0 then ", found at start" else ""}{if studio then ", Studio stand-ins" else ""})`)

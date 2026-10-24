--!strict
-- A stand-in for another lobby server, in Studio only (L-6, L-15): Studio
-- runs one server, so the shared room list (the in-memory RoomIndex) gets
-- a fake second server's entry with four rooms, with fixed codes so a test
-- can name them before a playtest starts (StandInLaunch = "room=PEERP"):
-- PEERT Teams on a 2v2 map with an AI, PEERL a password room (password
-- "peer"), PEERP a private room and PEERM one in a match. Joining one runs
-- the real hop: the checks, the `hop/<userId>` key, the teleport (the
-- stand-in's `toServer`). Then, instead of a new server, the peer's room
-- moves into this server's Directory and the player "arrives" through
-- Lobbies.arrive, as they would on the real one. The peer's hosts are
-- made-up users, so nobody can start those rooms.

local Players = game:GetService("Players")

local Ctx = require("./Ctx")
local Directory = require("./Directory")
local Listing = require("../shared/Listing")
local Rooms = require("../shared/Rooms")

local StandInPeer = {}

StandInPeer.JOB_ID = "studio-peer"

local rooms: { Rooms.Room } = {}
local arrive: (Player) -> boolean = function(_player: Player)
	return false
end

local function mapId(prefer: string): string
	for _, m in Ctx.maps do
		if m.id == prefer then
			return m.id
		end
	end
	return Ctx.maps[1].id
end

local function make(id: string, name: string, privacy: string, password: string?, host: number, hostName: string): Rooms.Room?
	local room = Rooms.new(id, { name = name, privacy = privacy, password = password, maxPlayers = 8 }, host, hostName, Ctx.maps)
	if room then
		table.insert(rooms, room)
	end
	return room
end

local function publish()
	local summaries = {}
	for i, r in rooms do
		summaries[i] = Rooms.summary(r, Ctx.maps)
	end
	local entry = Listing.entry(StandInPeer.JOB_ID, game.PlaceId, os.time(), 3, rooms, summaries)
	Ctx.index.put(StandInPeer.JOB_ID, entry, 30)
end

-- Starts the fake server once the maps are in (Main, Studio only).
-- `onArrive` is Lobbies.arrive.
function StandInPeer.start(onArrive: (Player) -> boolean)
	arrive = onArrive
	local teams = make("PEERT", "Peer server: Teams", "public", nil, -901, "PeerHost")
	if teams then
		Rooms.apply(teams, Ctx.maps, -901, { op = "set", key = "mapId", value = mapId("map:twin_lakes") })
		Rooms.apply(teams, Ctx.maps, -901, { op = "set", key = "mode", value = "TEAM" })
		Rooms.apply(teams, Ctx.maps, -901, { op = "addAi", level = "hard", faction = "chaos" })
	end
	make("PEERL", "Peer server: password", "public", "peer", -902, "LockedHost")
	local private = make("PEERP", "Peer server: private", "private", nil, -903, "QuietHost")
	local busy = make("PEERM", "Peer server: in match", "public", nil, -904, "BusyHost")
	if busy then
		Rooms.apply(busy, Ctx.maps, -904, { op = "set", key = "mapId", value = mapId("map:crossroads") })
		Rooms.setPhase(busy, "match", "peer-match", os.time() - 7 * 60)
	end
	print(`[Lobby] (Studio) stand-in peer server "{StandInPeer.JOB_ID}": {#rooms} rooms: PEERT Teams, PEERL password "peer", {if private then private.id else "?"} private, PEERM in a match`)
	task.spawn(function()
		while true do
			publish()
			task.wait(10)
		end
	end)
end

-- The stand-in teleport to another lobby server (Teleport.standIn's hop).
function StandInPeer.hop(jobId: string, players: { Player }, data: any)
	local code = type(data) == "table" and data.hop or nil
	task.wait(1.5) -- the teleport
	for i, r in rooms do
		if r.id == code and jobId == StandInPeer.JOB_ID then
			table.remove(rooms, i)
			Directory.adopt(r)
			publish()
			break
		end
	end
	for _, p in players do
		if p.Parent == Players then
			-- leaving the old server leaves its room (Main's PlayerRemoving)
			local old = Directory.roomOf(p.UserId)
			if old and old.phase == "setup" and old.id ~= code then
				Directory.leave(p.UserId)
			end
			arrive(p)
		end
	end
	Ctx.publish()
end

return StandInPeer

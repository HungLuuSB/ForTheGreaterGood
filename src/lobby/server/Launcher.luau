--!strict
-- Starting a room's match (L-4; contract sections 4 and 6): check, reserve a
-- server of the match place, write the config and the lookup keys, teleport
-- the room's players together. Any failure before the teleport lands puts
-- everyone back in the room with the reason; a player whose own teleport
-- fails is retried alone, then gets their seat back in the lobby.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require("../shared/Config")
local Ctx = require("./Ctx")
local Directory = require("./Directory")
local MatchConfig = require("../shared/MatchConfig")
local Returns = require("./Returns")
local Rooms = require("../shared/Rooms")

local Launcher = {}

local rng = Random.new()
local retries: { [number]: number } = {} -- per player, for the match they're joining

-- Players of the room who are on this server.
local function present(room: Rooms.Room): { Player }
	local out = {}
	for _, m in room.members do
		local p = Players:GetPlayerByUserId(m.user)
		if p then
			table.insert(out, p)
		end
	end
	return out
end

local function fail(room: Rooms.Room, reason: string, keys: { string })
	for _, k in keys do
		Ctx.store.remove(k)
	end
	if Directory.get(room.id) ~= room then
		return
	end
	Rooms.setPhase(room, "setup", nil)
	Rooms.setNotice(room, `Couldn't start the match: {reason}. Everyone is back in the room; try again.`)
	Ctx.publish()
end

local function reserve(): (string?, string?, string?)
	local err: string? = nil
	for attempt = 1, Config.TELEPORT_RETRIES do
		local code, id, e = Ctx.teleport.reserve(Config.MATCH_PLACE_ID)
		if code and id then
			return code, id, nil
		end
		err = e
		task.wait(attempt)
	end
	return nil, nil, `no match server ({err or "?"})`
end

local function run(room: Rooms.Room)
	local matchId = HttpService:GenerateGUID(false)
	local config = MatchConfig.build(room, matchId, rng:NextInteger(1, 2 ^ 31 - 1), os.time(), { placeId = game.PlaceId, jobId = game.JobId })
	local bad = MatchConfig.validate(config)
	if bad then
		fail(room, `the config failed its own check ({bad})`, {})
		return
	end
	local code, serverId, err = reserve()
	if code == nil or serverId == nil then
		fail(room, err or "no match server", {})
		return
	end
	local keys = { `config/{matchId}`, `server/{serverId}`, `access/{matchId}`, `room/{matchId}` }
	local writes: { { any } } = {
		{ keys[1], config },
		{ keys[2], matchId },
		{ keys[3], { accessCode = code, privateServerId = serverId } },
		{ keys[4], { privacy = room.privacy, password = room.password, maxPlayers = room.maxPlayers } },
	}
	for _, user in MatchConfig.users(config) do
		table.insert(keys, `player/{user}`)
		table.insert(writes, { `player/{user}`, matchId })
	end
	for _, w in writes do
		local ok, e = Ctx.store.set(w[1], w[2], Config.CONFIG_TTL)
		if not ok then
			fail(room, `the match store didn't answer ({e})`, keys)
			return
		end
	end
	if Directory.get(room.id) ~= room or room.phase ~= "starting" then
		fail(room, "the room changed", keys)
		return
	end
	local going = present(room)
	if #going == 0 then
		fail(room, "nobody is here to play", keys)
		return
	end
	-- away before the teleport: leaving this server keeps their seat
	Rooms.setPhase(room, "match", matchId)
	Rooms.setNotice(room, nil)
	for _, p in going do
		retries[p.UserId] = 0
	end
	Ctx.publish()
	local ok, terr = false, nil
	for attempt = 1, Config.TELEPORT_RETRIES do
		ok, terr = Ctx.teleport.teleport(going, Config.MATCH_PLACE_ID, code, { matchId = matchId })
		if ok then
			break
		end
		task.wait(2 ^ (attempt - 1))
	end
	if not ok then
		fail(room, `the teleport failed ({terr})`, keys)
		return
	end
	print(`[Lobby] room {room.id}: match {matchId} on {serverId}, {#going} player(s) teleported`)
	Returns.watch(room, config, os.time())
end

-- The host starts (`force` skips the ready check). Returns nil, or why not.
function Launcher.start(room: Rooms.Room, from: number, force: boolean): string?
	local err = Rooms.checkStart(room, Ctx.maps, from, force)
	if err then
		return err
	end
	Rooms.setPhase(room, "starting", nil)
	Rooms.setNotice(room, nil)
	Ctx.publish()
	task.spawn(run, room)
	return nil
end

-- One player's teleport failed (TeleportInitFailed): try them alone again,
-- then give them their seat back in the lobby with the reason.
function Launcher.teleportFailed(player: Player, message: string)
	local room = Directory.roomOf(player.UserId)
	if room == nil or room.phase ~= "match" or room.matchId == nil then
		return
	end
	local n = (retries[player.UserId] or 0) + 1
	retries[player.UserId] = n
	warn(`[Lobby] teleport of {player.Name} failed ({message}), try {n}`)
	if n <= Config.TELEPORT_RETRIES then
		task.wait(n)
		if Launcher.rejoin(player) == nil then
			return
		end
	end
	Rooms.setAway(room, player.UserId, false)
	Ctx.toast(player.UserId, `Couldn't reach the match ({message}). Rejoin from the room to try again.`, "error")
	Ctx.publish()
end

-- Sends a player (back) into their room's running match. nil, or why not.
function Launcher.rejoin(player: Player): string?
	local room = Directory.roomOf(player.UserId)
	if room == nil or room.phase ~= "match" or room.matchId == nil then
		return "No match to rejoin"
	end
	local matchId = room.matchId :: string
	local ok, access = Ctx.store.get(`access/{matchId}`)
	if not ok or type(access) ~= "table" or type(access.accessCode) ~= "string" then
		return "The match can't be found"
	end
	Rooms.setAway(room, player.UserId, true)
	Ctx.publish()
	local sent, err = Ctx.teleport.teleport({ player }, Config.MATCH_PLACE_ID, access.accessCode, { matchId = matchId })
	if not sent then
		Rooms.setAway(room, player.UserId, false)
		Ctx.publish()
		return `Couldn't rejoin ({err})`
	end
	return nil
end

return Launcher

--!strict
-- While a room's match runs, and when its players come back (L-4; contract
-- sections 5 and 6): the room polls the match's result and heartbeat; a
-- result brings the room back to setup with the summary and adds the match
-- to every member's history; a match server silent past the timeout ends
-- it as abandoned. Players arriving from a match (teleport data names the
-- match ID, but only the store's own `player/<userId>` key and the config's
-- player list are trusted) land in their room, rebuilt from the match record
-- if this isn't the server they left.

local Players = game:GetService("Players")

local Config = require("../shared/Config")
local Ctx = require("./Ctx")
local Directory = require("./Directory")
local MatchConfig = require("../shared/MatchConfig")
local Profile = require("../shared/Profile")
local Profiles = require("./Profiles")
local Rooms = require("../shared/Rooms")

local Returns = {}

local watching: { [string]: boolean } = {}

local function mapName(id: string): string
	local m = Rooms.mapOf(Ctx.maps, id)
	return if m then m.name else id
end

local function readConfig(matchId: string): MatchConfig.MatchConfig?
	local ok, c = Ctx.store.get(`config/{matchId}`)
	if not ok or c == nil then
		return nil
	end
	local bad = MatchConfig.validate(c)
	if bad then
		warn(`[Lobby] config {matchId}: {bad}`)
		return nil
	end
	return c
end

-- A valid result for the config, or nil.
local function readResult(c: MatchConfig.MatchConfig): MatchConfig.Result?
	local ok, r = Ctx.store.get(`result/{c.matchId}`)
	if not ok or r == nil then
		return nil
	end
	local bad = MatchConfig.validateResult(r, c)
	if bad then
		warn(`[Lobby] result {c.matchId}: {bad}`)
		return nil
	end
	return r
end

local function record(user: number, c: MatchConfig.MatchConfig, r: MatchConfig.Result?)
	Profiles.addMatch(user, Profile.entryFor(c, r, user, mapName(c.mapId), os.time()))
	Ctx.store.remove(`player/{user}`)
end

-- The match is over (r nil: abandoned, `reason` says why).
local function finish(room: Rooms.Room, c: MatchConfig.MatchConfig, r: MatchConfig.Result?, reason: string?)
	if room.matchId ~= c.matchId then
		return
	end
	if r then
		room.results = MatchConfig.summary(c, r, mapName(c.mapId))
	else
		local players = {}
		for _, p in c.players do
			table.insert(players, { name = p.name, user = p.user, ai = p.ai, faction = p.faction, allyTeam = p.allyTeam, color = p.color, won = false })
		end
		room.results = { matchId = c.matchId, mapName = mapName(c.mapId), mode = c.mode, outcome = "abandoned", reason = reason, seconds = 0, cheatsUsed = false, players = players }
	end
	local here: { [number]: boolean } = {}
	for _, m in room.members do
		here[m.user] = Players:GetPlayerByUserId(m.user) ~= nil and not Returns.inStandIn(m.user)
	end
	Rooms.setPhase(room, "setup", nil)
	for _, m in room.members do
		if not here[m.user] then
			m.away = true
		end
	end
	for _, user in MatchConfig.users(c) do
		if here[user] then
			record(user, c, r)
		end
	end
	Ctx.publish()
	print(`[Lobby] room {room.id}: match {c.matchId} {if r then r.outcome else "abandoned"}`)
	-- members not back after the grace leave the room
	task.delay(Config.AWAY_GRACE, function()
		if Directory.get(room.id) ~= room or room.phase ~= "setup" then
			return
		end
		local gone = {}
		for _, m in room.members do
			if m.away and Players:GetPlayerByUserId(m.user) == nil then
				table.insert(gone, m.user)
			end
		end
		for _, user in gone do
			if Rooms.leave(room, user) then
				Directory.close(room)
				break
			end
		end
		Ctx.publish()
	end)
end

-- Is `user` in the Studio stand-in match (set by Main in Studio)?
function Returns.inStandIn(_user: number): boolean
	return false
end

-- Polls a room's running match until it ends.
function Returns.watch(room: Rooms.Room, c: MatchConfig.MatchConfig, startedAt: number)
	if watching[c.matchId] then
		return
	end
	watching[c.matchId] = true
	local every = if Ctx.studio then 1 else Config.POLL_EVERY
	local arrival = if Ctx.studio then 15 else Config.ARRIVAL_TIMEOUT
	task.spawn(function()
		while Directory.get(room.id) == room and room.phase == "match" and room.matchId == c.matchId do
			task.wait(every)
			local r = readResult(c)
			if r then
				finish(room, c, r)
				break
			end
			local ok, alive = Ctx.store.get(`alive/{c.matchId}`)
			if ok and alive == nil and os.time() - startedAt > arrival then
				-- tell every lobby server the same: the first word stands
				local _, already = Ctx.store.get(`result/{c.matchId}`)
				if already == nil then
					Ctx.store.set(`result/{c.matchId}`, {
						version = Config.CONFIG_VERSION,
						matchId = c.matchId,
						outcome = "abandoned",
						seconds = 0,
						endedAt = os.time(),
						cheatsUsed = false,
						by = "lobby",
						players = (function()
							local out = {}
							for i in c.players do
								out[i] = { id = i, won = false }
							end
							return out
						end)(),
					}, Config.RESULT_TTL)
				end
				finish(room, c, nil, "The match server stopped answering")
				break
			end
		end
		watching[c.matchId] = nil
	end)
end

-- The room on this server that played `matchId` (running, or finished with
-- its results still shown).
local function roomOfMatch(matchId: string): Rooms.Room?
	for _, r in Directory.rooms do
		if r.matchId == matchId or (r.results and r.results.matchId == matchId) then
			return r
		end
	end
	return nil
end

-- A player joined this server, or the Studio stand-in match sent them back.
-- `hint` is the teleport data's match ID (checked, never trusted alone).
function Returns.arrive(player: Player, hint: any)
	local user = player.UserId
	local ok, stored = Ctx.store.get(`player/{user}`)
	local matchId: string? = if ok and type(stored) == "string" then stored else nil
	if matchId == nil and type(hint) == "string" and #hint <= 64 then
		matchId = hint -- the key may have expired: the config's player list decides
	end
	if matchId == nil then
		return
	end
	local c = readConfig(matchId)
	if c == nil or table.find(MatchConfig.users(c), user) == nil then
		return
	end
	local r = readResult(c)
	local room = roomOfMatch(matchId)
	if room == nil then
		if r and os.time() - r.endedAt > Config.AWAY_GRACE then
			-- long over: just its history entry, no room
			record(user, c, r)
			return
		end
		local _, saved = Ctx.store.get(`room/{matchId}`)
		room = Directory.recreate(c, saved, user)
		print(`[Lobby] room {room.id} rebuilt for match {matchId}`)
		if r == nil then
			Returns.watch(room, c, c.createdAt)
		end
	end
	local theRoom = room :: Rooms.Room
	Directory.attach(theRoom, user)
	Rooms.welcomeBack(theRoom, user, player.DisplayName, c.host)
	if r and theRoom.phase == "match" then
		finish(theRoom, c, r)
	elseif r then
		record(user, c, r)
	end
	Ctx.publish()
end

return Returns

--!strict
-- The match config the lobby writes and the results record the match server
-- writes back (L-4; docs/contracts/match.md sections 3 and 5). Pure Luau:
-- built and checked here, tested under Lune. The match place can copy
-- `validate` to check what it reads.

local Config = require("./Config")
local Rooms = require("./Rooms")

local MatchConfig = {}

export type Player = {
	id: number, -- sim player ID, 1..#players; also the map start it plays from
	start: number, -- the map start (== id in version 1; see the contract)
	faction: string, -- "order" | "chaos"
	allyTeam: number, -- 1..#ally teams; in FFA, its own id
	color: number, -- index into the palette (contract section 3)
	user: number?, -- a human's UserId (nil for an AI)
	name: string, -- display name ("AI 1 (normal)" for an AI)
	ai: string?, -- an AI's level: "easy" | "normal" | "hard"
}

export type MatchConfig = {
	version: number,
	matchId: string,
	createdAt: number, -- os.time() when the lobby wrote it
	seed: number,
	mapId: string,
	mode: string,
	win: string,
	friendlyFire: boolean,
	cheats: boolean,
	players: { Player },
	spectators: { { user: number, name: string } },
	lobby: { placeId: number, jobId: string, roomId: string, roomName: string },
}

export type Lobby = { placeId: number, jobId: string }

-- The config for a room that passed Rooms.checkStart. Sim player IDs follow
-- the map's starts: in Teams, ally teams sit together (team 1's players
-- first), since named 2v2 maps put players 1-2 and 3-4 on the same side;
-- ally teams are renumbered 1..n in team order.
function MatchConfig.build(room: Rooms.Room, matchId: string, seed: number, now: number, lobby: Lobby): MatchConfig
	local order: { number } = {}
	for i in room.slots do
		table.insert(order, i)
	end
	local team = room.settings.mode == "TEAM"
	if team then
		table.sort(order, function(a, b)
			local ta, tb = room.slots[a].team, room.slots[b].team
			if ta ~= tb then
				return ta < tb
			end
			return a < b
		end)
	end
	local allyOf: { [number]: number } = {}
	local allies = 0
	local players: { Player } = {}
	local aiNumber = 0
	for id, i in order do
		local s = room.slots[i]
		local ally = id
		if team then
			if allyOf[s.team] == nil then
				allies += 1
				allyOf[s.team] = allies
			end
			ally = allyOf[s.team]
		end
		local name
		if s.kind == "human" then
			local m = Rooms.member(room, s.user :: number)
			name = if m then m.name else `Player {id}`
		else
			aiNumber += 1
			name = `AI {aiNumber} ({s.level})`
		end
		table.insert(players, {
			id = id,
			start = id,
			faction = s.faction,
			allyTeam = ally,
			color = s.color,
			user = if s.kind == "human" then s.user else nil,
			name = name,
			ai = if s.kind == "ai" then s.level else nil,
		})
	end
	local spectators = {}
	for _, m in room.members do
		if Rooms.slotOf(room, m.user) == nil then
			table.insert(spectators, { user = m.user, name = m.name })
		end
	end
	return {
		version = Config.CONFIG_VERSION,
		matchId = matchId,
		createdAt = now,
		seed = seed,
		mapId = room.settings.mapId,
		mode = room.settings.mode,
		win = room.settings.win,
		friendlyFire = room.settings.friendlyFire,
		cheats = room.settings.cheats,
		players = players,
		spectators = spectators,
		lobby = { placeId = lobby.placeId, jobId = lobby.jobId, roomId = room.id, roomName = room.name },
	}
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function oneOf(list: { string }, v: any): boolean
	return type(v) == "string" and table.find(list, v) ~= nil
end

-- Checks a config read back from MemoryStore. Returns nil, or what's wrong.
function MatchConfig.validate(c: any): string?
	if type(c) ~= "table" then
		return "not a table"
	end
	if c.version ~= Config.CONFIG_VERSION then
		return `version {tostring(c.version)}, expected {Config.CONFIG_VERSION}`
	end
	if type(c.matchId) ~= "string" or #c.matchId == 0 or #c.matchId > 64 then
		return "matchId"
	end
	if not isInt(c.seed, 0, 2 ^ 31 - 1) then
		return "seed"
	end
	if type(c.mapId) ~= "string" or not oneOf(Config.MODES, c.mode) or not oneOf(Config.WINS, c.win) then
		return "map, mode or win"
	end
	if type(c.friendlyFire) ~= "boolean" or type(c.cheats) ~= "boolean" then
		return "options"
	end
	if type(c.players) ~= "table" or #c.players < 2 or #c.players > Config.MAX_ALLY_TEAMS * Config.MAX_TEAM_SIZE then
		return "player count"
	end
	local users: { [number]: boolean } = {}
	local colors: { [number]: boolean } = {}
	local humans = 0
	for i, p in c.players do
		if type(p) ~= "table" or p.id ~= i or p.start ~= i then
			return `player {i}: id`
		end
		if not oneOf(Config.FACTIONS, p.faction) or not isInt(p.allyTeam, 1, #c.players) then
			return `player {i}: faction or ally team`
		end
		if not isInt(p.color, 1, #Config.COLORS) or colors[p.color] then
			return `player {i}: color`
		end
		colors[p.color] = true
		if type(p.name) ~= "string" then
			return `player {i}: name`
		end
		if p.ai ~= nil then
			if p.user ~= nil or not oneOf(Config.LEVELS, p.ai) then
				return `player {i}: AI`
			end
		else
			if type(p.user) ~= "number" or users[p.user] then
				return `player {i}: user`
			end
			users[p.user] = true
			humans += 1
		end
		if c.mode == "FFA" and p.allyTeam ~= i then
			return `player {i}: FFA ally team`
		end
	end
	if humans == 0 then
		return "no human player"
	end
	if c.mode == "FFA" and #c.players > Config.MAX_FFA then
		return "FFA player count"
	end
	if type(c.spectators) ~= "table" then
		return "spectators"
	end
	for _, s in c.spectators do
		if type(s) ~= "table" or type(s.user) ~= "number" or users[s.user] then
			return "spectator"
		end
		users[s.user] = true
	end
	local l = c.lobby
	if type(l) ~= "table" or type(l.placeId) ~= "number" or type(l.jobId) ~= "string" or type(l.roomId) ~= "string" then
		return "lobby"
	end
	return nil
end

-- Every UserId the match admits (players and spectators).
function MatchConfig.users(c: MatchConfig): { number }
	local out = {}
	for _, p in c.players do
		if p.user then
			table.insert(out, p.user)
		end
	end
	for _, s in c.spectators do
		table.insert(out, s.user)
	end
	return out
end

MatchConfig.OUTCOMES = table.freeze({ "finished", "draw", "abandoned" })

export type ResultPlayer = {
	id: number,
	won: boolean,
	outAt: number?, -- seconds into the match when eliminated
	stats: { [string]: number }?,
}

export type Result = {
	version: number,
	matchId: string,
	outcome: string, -- "finished" | "draw" | "abandoned"
	winner: number?, -- the winning ally team ("finished" only; absent when every human is out while AI fight on)
	seconds: number,
	endedAt: number,
	cheatsUsed: boolean,
	players: { ResultPlayer },
}

-- Checks a results record against its config. Returns nil, or what's wrong.
function MatchConfig.validateResult(r: any, c: MatchConfig): string?
	if type(r) ~= "table" then
		return "not a table"
	end
	if r.version ~= Config.CONFIG_VERSION or r.matchId ~= c.matchId then
		return "version or matchId"
	end
	if not oneOf(MatchConfig.OUTCOMES, r.outcome) then
		return "outcome"
	end
	if r.winner ~= nil and (r.outcome ~= "finished" or not isInt(r.winner, 1, #c.players)) then
		return "winner"
	end
	if type(r.seconds) ~= "number" or r.seconds < 0 or type(r.endedAt) ~= "number" or type(r.cheatsUsed) ~= "boolean" then
		return "seconds, endedAt or cheatsUsed"
	end
	if type(r.players) ~= "table" or #r.players ~= #c.players then
		return "players"
	end
	for i, p in r.players do
		if type(p) ~= "table" or p.id ~= i or type(p.won) ~= "boolean" then
			return `player {i}`
		end
		if p.stats ~= nil then
			if type(p.stats) ~= "table" then
				return `player {i}: stats`
			end
			for k, v in p.stats do
				if type(k) ~= "string" or type(v) ~= "number" then
					return `player {i}: stats`
				end
			end
		end
	end
	return nil
end

-- The room's summary of a finished match: who played, who won, the time.
function MatchConfig.summary(c: MatchConfig, r: Result, mapName: string): any
	local players = {}
	for i, p in c.players do
		local rp = r.players[i]
		table.insert(players, {
			name = p.name,
			user = p.user,
			ai = p.ai,
			faction = p.faction,
			allyTeam = p.allyTeam,
			color = p.color,
			won = rp.won,
			outAt = rp.outAt,
			stats = rp.stats,
		})
	end
	return {
		matchId = c.matchId,
		mapName = mapName,
		mode = c.mode,
		outcome = r.outcome,
		winner = r.winner,
		seconds = r.seconds,
		cheatsUsed = r.cheatsUsed,
		players = players,
	}
end

return MatchConfig

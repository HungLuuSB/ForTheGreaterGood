--!strict
-- The match config the lobby writes and the results record the match server
-- writes back (docs/contracts/match.md sections 3 and 5; lobby L-4), checked
-- the same way in both places: the lobby place before it stores a config or
-- trusts a result, the match place before it boots from a config or writes
-- a result (S-145, moved from src/lobby/shared at the user's choice). The
-- lobby keeps building configs (`build`, `summary` in src/lobby); this module
-- holds the record shapes, the limits they're checked against and the checks.
-- Pure Luau, both runtimes.

local MatchConfig = {}

MatchConfig.CONFIG_VERSION = 1 -- every record carries `version`; another one is refused
MatchConfig.MODES = table.freeze({ "FFA", "TEAM" })
MatchConfig.WINS = table.freeze({ "COMMAND_ENDS", "ANNIHILATION" })
MatchConfig.LEVELS = table.freeze({ "easy", "normal", "hard" }) -- AI levels
MatchConfig.FACTIONS = table.freeze({ "order", "chaos" })
MatchConfig.MAX_ALLY_TEAMS = 4 -- guide 16.1: Team mode, 2-4 ally teams of up to 4
MatchConfig.MAX_TEAM_SIZE = 4
MatchConfig.MAX_FFA = 8 -- guide 16.1: FFA up to 8, each alone

-- Player colors (contract: `color` is an index into this list). Distinct on
-- the dark terrain and on the minimap; no two players share one.
MatchConfig.COLORS = table.freeze({
	table.freeze({ name = "Blue", rgb = table.freeze({ 64, 132, 230 }) }),
	table.freeze({ name = "Red", rgb = table.freeze({ 222, 70, 62 }) }),
	table.freeze({ name = "Green", rgb = table.freeze({ 82, 186, 92 }) }),
	table.freeze({ name = "Yellow", rgb = table.freeze({ 236, 200, 64 }) }),
	table.freeze({ name = "Purple", rgb = table.freeze({ 156, 92, 214 }) }),
	table.freeze({ name = "Orange", rgb = table.freeze({ 238, 132, 46 }) }),
	table.freeze({ name = "Cyan", rgb = table.freeze({ 60, 200, 210 }) }),
	table.freeze({ name = "Pink", rgb = table.freeze({ 232, 110, 180 }) }),
	table.freeze({ name = "White", rgb = table.freeze({ 226, 229, 235 }) }),
	table.freeze({ name = "Olive", rgb = table.freeze({ 140, 150, 70 }) }),
	table.freeze({ name = "Brown", rgb = table.freeze({ 150, 100, 62 }) }),
	table.freeze({ name = "Teal", rgb = table.freeze({ 40, 130, 120 }) }),
})

export type Player = {
	id: number, -- sim player ID, 1..#players; also the map start it plays from
	start: number, -- the map start (== id in version 1; see the contract)
	faction: string, -- "order" | "chaos"
	allyTeam: number, -- 1..#ally teams; in FFA, its own id
	color: number, -- index into COLORS
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
	if c.version ~= MatchConfig.CONFIG_VERSION then
		return `version {tostring(c.version)}, expected {MatchConfig.CONFIG_VERSION}`
	end
	if type(c.matchId) ~= "string" or #c.matchId == 0 or #c.matchId > 64 then
		return "matchId"
	end
	if not isInt(c.seed, 0, 2 ^ 31 - 1) then
		return "seed"
	end
	if type(c.mapId) ~= "string" or not oneOf(MatchConfig.MODES, c.mode) or not oneOf(MatchConfig.WINS, c.win) then
		return "map, mode or win"
	end
	if type(c.friendlyFire) ~= "boolean" or type(c.cheats) ~= "boolean" then
		return "options"
	end
	if type(c.players) ~= "table" or #c.players < 2 or #c.players > MatchConfig.MAX_ALLY_TEAMS * MatchConfig.MAX_TEAM_SIZE then
		return "player count"
	end
	local users: { [number]: boolean } = {}
	local colors: { [number]: boolean } = {}
	local humans = 0
	for i, p in c.players do
		if type(p) ~= "table" or p.id ~= i or p.start ~= i then
			return `player {i}: id`
		end
		if not oneOf(MatchConfig.FACTIONS, p.faction) or not isInt(p.allyTeam, 1, #c.players) then
			return `player {i}: faction or ally team`
		end
		if not isInt(p.color, 1, #MatchConfig.COLORS) or colors[p.color] then
			return `player {i}: color`
		end
		colors[p.color] = true
		if type(p.name) ~= "string" then
			return `player {i}: name`
		end
		if p.ai ~= nil then
			if p.user ~= nil or not oneOf(MatchConfig.LEVELS, p.ai) then
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
	if c.mode == "FFA" and #c.players > MatchConfig.MAX_FFA then
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
	if r.version ~= MatchConfig.CONFIG_VERSION or r.matchId ~= c.matchId then
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

return table.freeze(MatchConfig)

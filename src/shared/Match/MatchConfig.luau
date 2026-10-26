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

MatchConfig.CONFIG_VERSION = 2 -- every record carries `version`; another one is refused (2: host, startBoxes; S-174)
MatchConfig.MODES = table.freeze({ "FFA", "TEAM" })
MatchConfig.WINS = table.freeze({ "COMMAND_ENDS", "ANNIHILATION" })
MatchConfig.LEVELS = table.freeze({ "easy", "normal", "hard", "hard_aggressive" }) -- AI levels ("hard" is Hard - Balanced; S-187)
MatchConfig.FACTIONS = table.freeze({ "order", "chaos" })
MatchConfig.MAX_PLAYERS = 16 -- guide 16.1 (S-169, the user: 16 on any map)
MatchConfig.MAX_ALLY_TEAMS = 8 -- Team mode: 2-8 sides (never more than the map's starts: the match place checks)
MatchConfig.MAX_TEAM_SIZE = 16 -- any size of side, within MAX_PLAYERS
MatchConfig.MAX_FFA = 16 -- FFA, each alone (never more than the map's starts)

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
	-- 13-16 for 16 players (S-169; lobby-D's picks)
	table.freeze({ name = "Navy", rgb = table.freeze({ 38, 60, 150 }) }),
	table.freeze({ name = "Maroon", rgb = table.freeze({ 140, 28, 48 }) }),
	table.freeze({ name = "Lime", rgb = table.freeze({ 168, 224, 60 }) }),
	table.freeze({ name = "Lavender", rgb = table.freeze({ 196, 168, 246 }) }),
})

export type Player = {
	id: number, -- sim player ID, 1..#players; also the map start it plays from
	start: number, -- 0: picked in the match's pre-game (S-171: no fixed starts); == id is accepted from older lobbies and means the same
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
	host: number, -- the room host's UserId (a player or a spectator): starts the match from the pre-game (S-174)
	-- each side's spawn box as the host drew it: allyTeam → { x0, z0, x1, z1 },
	-- fractions of the map from its low-X / low-Z corner (0..1, x0 < x1,
	-- z0 < z1); absent: the map's own boxes (S-174)
	startBoxes: { [number]: { number } }?,
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
	if type(c.players) ~= "table" or #c.players < 2 or #c.players > MatchConfig.MAX_PLAYERS then
		return "player count"
	end
	local users: { [number]: boolean } = {}
	local colors: { [number]: boolean } = {}
	local humans = 0
	for i, p in c.players do
		if type(p) ~= "table" or p.id ~= i or not (p.start == 0 or p.start == i) then
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
	if c.mode == "TEAM" then
		local sides: { [number]: boolean } = {}
		local n = 0
		for _, p in c.players do
			if not sides[p.allyTeam] then
				sides[p.allyTeam] = true
				n += 1
			end
		end
		if n < 2 or n > MatchConfig.MAX_ALLY_TEAMS then
			return "side count"
		end
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
	if type(c.host) ~= "number" or not users[c.host] then
		return "host"
	end
	if c.startBoxes ~= nil then
		if type(c.startBoxes) ~= "table" then
			return "startBoxes"
		end
		local sides: { [number]: boolean } = {}
		for _, p in c.players do
			sides[p.allyTeam] = true
		end
		for ally, b in c.startBoxes do
			if not sides[ally] or type(b) ~= "table" or #b ~= 4 then
				return `startBoxes[{tostring(ally)}]`
			end
			for k = 1, 4 do
				if type(b[k]) ~= "number" or b[k] ~= b[k] or b[k] < 0 or b[k] > 1 then
					return `startBoxes[{ally}]`
				end
			end
			if b[1] >= b[3] or b[2] >= b[4] then
				return `startBoxes[{ally}]: empty`
			end
		end
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

-- Why a player couldn't get into (or stay in) a match (S-180; the user: "any
-- failed attempt to connect to the game match must be displayed on the
-- lobby when return with error code + description"; lobby-D's table,
-- docs/contracts/match.md section 11). 1xx: the lobby's side; 2xx: the
-- match server's, sent back in the returning player's teleport data
-- ({ matchId, error = { code, detail? } }) and, for a whole match, in the
-- result record's `error`.
export type ErrorEntry = { title: string, description: string }
export type MatchError = { code: number, detail: string? }
local function e(title: string, description: string): ErrorEntry
	return table.freeze({ title = title, description = description })
end
MatchConfig.ERRORS = table.freeze({
	[101] = e("No match place", "The lobby couldn't find the game's match place."),
	[102] = e("Bad match setup", "The lobby built a match setup that failed its own check."),
	[103] = e("No match server", "Roblox didn't give the lobby a server for the match."),
	[104] = e("Match store unavailable", "The lobby couldn't save the match setup (MemoryStore)."),
	[105] = e("Room changed", "The room changed while the match was starting."),
	[106] = e("Nobody to send", "None of the room's players were on this lobby server."),
	[110] = e("Teleport failed", "Roblox couldn't send the players to the match server."),
	[111] = e("Match server not found", "The teleport couldn't find the match server."),
	[112] = e("Match server closed", "The match server shut down before you arrived."),
	[113] = e("Match server full", "The match server had no room for you."),
	[114] = e("Teleport not allowed", "Roblox refused the teleport to the match."),
	[115] = e("Too many teleports", "Roblox is limiting teleports right now."),
	[116] = e("Already teleporting", "Another teleport was still in progress."),
	[120] = e("Match server stopped answering", "The match server stopped reporting, so the match was ended."),
	[121] = e("Match not found", "The running match's details have expired; it can't be rejoined."),
	[201] = e("No match setup", "The match server found no setup for itself."),
	[202] = e("Bad match setup", "The match server refused the lobby's match setup."),
	[203] = e("Version mismatch", "The lobby and the match place are on different versions."),
	[204] = e("Game version mismatch", "Your game client and the match server are on different versions."),
	[205] = e("Not in this match", "You aren't one of this match's players or spectators."),
	[206] = e("Match full", "The match had no free seat for you."),
	[207] = e("Match already over", "The match ended before you arrived."),
	[208] = e("Players didn't arrive", "Not everyone reached the match in time, so it didn't start."),
	[209] = e("Everyone left", "Every player left, so the match was abandoned."),
	[210] = e("Match server error", "The match server hit an error and ended the match."),
	[299] = e("Match server problem", "The match server sent you back for a reason it didn't name."),
} :: { [number]: ErrorEntry })
MatchConfig.ERROR_DETAIL_MAX = 200 -- characters of `detail` kept

-- An error from outside (teleport data, a result record), cleaned: a listed
-- code and a short string detail; nil when it isn't one.
function MatchConfig.cleanError(v: any): MatchError?
	if type(v) ~= "table" or type(v.code) ~= "number" or MatchConfig.ERRORS[v.code] == nil then
		return nil
	end
	local detail = if type(v.detail) == "string" and #v.detail > 0 then string.sub(v.detail, 1, MatchConfig.ERROR_DETAIL_MAX) else nil
	return { code = v.code, detail = detail }
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
	error: MatchError?, -- why the match failed (S-180): 201-203, 208-210, or the lobby's 120
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
	if r.error ~= nil and MatchConfig.cleanError(r.error) == nil then
		return "error"
	end
	return nil
end

return table.freeze(MatchConfig)

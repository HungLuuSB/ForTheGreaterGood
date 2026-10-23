--!strict
-- A player's profile record (L-8; contract section 7): totals and the
-- recent match history. Pure Luau. The lobby server is its only writer
-- (DataStore UpdateAsync with this module's transforms), and adding a match
-- is idempotent by match ID, so a retried or repeated write never counts a
-- match twice.

local Config = require("./Config")

local Profile = {}

Profile.VERSION = 1

export type Entry = {
	matchId: string,
	at: number, -- os.time() when it ended
	mapId: string,
	mapName: string,
	mode: string,
	result: string, -- "won" | "lost" | "draw" | "abandoned" | "spectated"
	seconds: number,
	faction: string?, -- nil for a spectator
	players: number,
	ai: number,
	cheats: boolean, -- cheats were on: never counted in the totals
}

export type Record = {
	version: number,
	created: number,
	played: number,
	wins: number,
	losses: number,
	draws: number,
	abandoned: number,
	factions: { [string]: number }, -- matches played per faction
	history: { Entry }, -- newest first, up to Config.HISTORY_MAX
}

function Profile.new(now: number): Record
	return { version = Profile.VERSION, created = now, played = 0, wins = 0, losses = 0, draws = 0, abandoned = 0, factions = {}, history = {} }
end

local function num(v: any): number
	return if type(v) == "number" and v == v and v >= 0 then math.floor(v) else 0
end

-- A stored value, whatever shape it has (nil, an older version, damaged),
-- as a Record. Unknown or damaged fields fall back to their defaults.
function Profile.migrate(data: any, now: number): Record
	if type(data) ~= "table" then
		return Profile.new(now)
	end
	local r = Profile.new(if type(data.created) == "number" then data.created else now)
	r.played, r.wins, r.losses, r.draws, r.abandoned = num(data.played), num(data.wins), num(data.losses), num(data.draws), num(data.abandoned)
	if type(data.factions) == "table" then
		for _, f in Config.FACTIONS do
			r.factions[f] = num(data.factions[f])
		end
	end
	if type(data.history) == "table" then
		for _, e in data.history do
			if type(e) == "table" and type(e.matchId) == "string" and type(e.result) == "string" then
				table.insert(r.history, e)
				if #r.history >= Config.HISTORY_MAX then
					break
				end
			end
		end
	end
	return r
end

-- Adds a match unless the history already has it. Returns whether it did.
-- Matches with cheats on and spectated ones are listed but not counted.
function Profile.addMatch(r: Record, e: Entry): boolean
	for _, old in r.history do
		if old.matchId == e.matchId then
			return false
		end
	end
	table.insert(r.history, 1, e)
	while #r.history > Config.HISTORY_MAX do
		table.remove(r.history)
	end
	if e.cheats or e.result == "spectated" then
		return true
	end
	if e.result == "abandoned" then
		r.abandoned += 1
		return true
	end
	r.played += 1
	if e.result == "won" then
		r.wins += 1
	elseif e.result == "lost" then
		r.losses += 1
	else
		r.draws += 1
	end
	if e.faction then
		r.factions[e.faction] = (r.factions[e.faction] or 0) + 1
	end
	return true
end

-- The history entry for `user` from a match config and its result (nil
-- result: the match server died, "abandoned").
function Profile.entryFor(c: any, r: any, user: number, mapName: string, now: number): Entry
	local mine, ai = nil, 0
	for i, p in c.players do
		if p.ai then
			ai += 1
		elseif p.user == user then
			mine = i
		end
	end
	local result
	if r == nil or r.outcome == "abandoned" then
		result = "abandoned"
	elseif mine == nil then
		result = "spectated"
	elseif r.outcome == "draw" then
		result = "draw"
	else
		result = if r.players[mine].won then "won" else "lost"
	end
	return {
		matchId = c.matchId,
		at = if r then r.endedAt else now,
		mapId = c.mapId,
		mapName = mapName,
		mode = c.mode,
		result = result,
		seconds = if r then r.seconds else 0,
		faction = if mine then c.players[mine].faction else nil,
		players = #c.players,
		ai = ai,
		cheats = c.cheats or (r ~= nil and r.cheatsUsed),
	}
end

-- What the profile page shows above the history.
function Profile.summary(r: Record): any
	local favourite, most = nil, 0
	for _, f in Config.FACTIONS do
		local n = r.factions[f] or 0
		if n > most then
			favourite, most = f, n
		end
	end
	local decided = r.wins + r.losses
	return {
		played = r.played,
		wins = r.wins,
		losses = r.losses,
		draws = r.draws,
		abandoned = r.abandoned,
		winRate = if decided > 0 then r.wins / decided else nil,
		favourite = favourite,
		created = r.created,
	}
end

return Profile

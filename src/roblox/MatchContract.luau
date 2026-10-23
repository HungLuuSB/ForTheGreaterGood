--!strict
-- The match server's side of the lobby ↔ match contract (C-173,
-- docs/contracts/match.md v1, the lobby stream's L-4): checking the match
-- config the lobby stored, turning it into the Sim config and a lobby-style
-- seat list (so the results screen and Lobby.results work as in a skirmish),
-- and the results record written back. Pure Luau, no requires, tested under
-- Lune (tests/client/MatchContract.spec).
--
-- `validate` and `validateResult` are copies of the lobby's
-- src/lobby/shared/MatchConfig.luau (with its Config constants inlined
-- below); keep them in step with it until the check moves to src/shared.

local MatchContract = {}

MatchContract.VERSION = 1
MatchContract.MAP = "FtggMatch" -- the MemoryStore HashMap (contract section 4)
MatchContract.HEARTBEAT_EVERY = 30
MatchContract.HEARTBEAT_TTL = 120
MatchContract.RESULT_TTL = 3 * 24 * 3600
MatchContract.WAIT_SECONDS = 90 -- waiting for the listed humans after the first arrives (section 6)
MatchContract.RETURN_SECONDS = 30 -- the results screen's auto-return (section 6)

MatchContract.MODES = table.freeze({ "FFA", "TEAM" })
MatchContract.WINS = table.freeze({ "COMMAND_ENDS", "ANNIHILATION" })
MatchContract.LEVELS = table.freeze({ "easy", "normal", "hard" })
MatchContract.FACTIONS = table.freeze({ "order", "chaos" })
MatchContract.MAX_ALLY_TEAMS = 4
MatchContract.MAX_TEAM_SIZE = 4
MatchContract.MAX_FFA = 8
MatchContract.OUTCOMES = table.freeze({ "finished", "draw", "abandoned" })

-- Player colours (contract section 3): `color` is an index into this list.
MatchContract.COLORS = table.freeze({
	{ 64, 132, 230 }, -- 1 Blue
	{ 222, 70, 62 }, -- 2 Red
	{ 82, 186, 92 }, -- 3 Green
	{ 236, 200, 64 }, -- 4 Yellow
	{ 156, 92, 214 }, -- 5 Purple
	{ 238, 132, 46 }, -- 6 Orange
	{ 60, 200, 210 }, -- 7 Cyan
	{ 232, 110, 180 }, -- 8 Pink
	{ 226, 229, 235 }, -- 9 White
	{ 140, 150, 70 }, -- 10 Olive
	{ 150, 100, 62 }, -- 11 Brown
	{ 40, 130, 120 }, -- 12 Teal
})

-- The stats a results record carries (the sim's Stats.report names).
MatchContract.STATS = table.freeze({ "unitsBuilt", "unitsLost", "unitsKilled", "damageDealt", "damageTaken", "supplyGathered", "powerGathered", "supplySpent", "powerSpent" })

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end

local function oneOf(list: { string }, v: any): boolean
	return type(v) == "string" and table.find(list, v) ~= nil
end

-- Checks a config read back from MemoryStore. Returns nil, or what's wrong.
-- (The lobby's MatchConfig.validate.)
function MatchContract.validate(c: any): string?
	if type(c) ~= "table" then
		return "not a table"
	end
	if c.version ~= MatchContract.VERSION then
		return `version {tostring(c.version)}, expected {MatchContract.VERSION}`
	end
	if type(c.matchId) ~= "string" or #c.matchId == 0 or #c.matchId > 64 then
		return "matchId"
	end
	if not isInt(c.seed, 0, 2 ^ 31 - 1) then
		return "seed"
	end
	if type(c.mapId) ~= "string" or not oneOf(MatchContract.MODES, c.mode) or not oneOf(MatchContract.WINS, c.win) then
		return "map, mode or win"
	end
	if type(c.friendlyFire) ~= "boolean" or type(c.cheats) ~= "boolean" then
		return "options"
	end
	if type(c.players) ~= "table" or #c.players < 2 or #c.players > MatchContract.MAX_ALLY_TEAMS * MatchContract.MAX_TEAM_SIZE then
		return "player count"
	end
	local users: { [number]: boolean } = {}
	local colors: { [number]: boolean } = {}
	local humans = 0
	for i, p in c.players do
		if type(p) ~= "table" or p.id ~= i or p.start ~= i then
			return `player {i}: id`
		end
		if not oneOf(MatchContract.FACTIONS, p.faction) or not isInt(p.allyTeam, 1, #c.players) then
			return `player {i}: faction or ally team`
		end
		if not isInt(p.color, 1, #MatchContract.COLORS) or colors[p.color] then
			return `player {i}: color`
		end
		colors[p.color] = true
		if type(p.name) ~= "string" then
			return `player {i}: name`
		end
		if p.ai ~= nil then
			if p.user ~= nil or not oneOf(MatchContract.LEVELS, p.ai) then
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
	if c.mode == "FFA" and #c.players > MatchContract.MAX_FFA then
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

-- The sim team of each player: faction parity, Order odd and Chaos even
-- (Scenarios.standard_start), numbered in player order (as Lobby.config).
function MatchContract.teams(c: any): { number }
	local out = {}
	local nextTeam = { order = 1, chaos = 2 }
	for i, p in c.players do
		out[i] = nextTeam[p.faction]
		nextTeam[p.faction] += 2
	end
	return out
end

-- The Sim config (contract section 3, "To the sim config").
function MatchContract.toSim(c: any): any
	local teams = MatchContract.teams(c)
	local players, ai = {}, {}
	for i, p in c.players do
		table.insert(players, { id = i, team = teams[i], allyTeam = p.allyTeam })
		if p.ai then
			ai[i] = p.ai
		end
	end
	return {
		seed = c.seed,
		players = players,
		mapId = c.mapId,
		scenario = "standard_start",
		match = { mode = c.mode, win = c.win, ai = ai, friendlyFire = c.friendlyFire, cheats = c.cheats },
	}
end

-- A lobby-style state (src/roblox/Lobby's State) for the match: the seats
-- from the config, in play. Lobby.results, Lobby.done and the results
-- screen then work as in a skirmish.
function MatchContract.toLobby(c: any): any
	local slots = {}
	for _, p in c.players do
		table.insert(slots, {
			kind = if p.ai then "ai" else "human",
			faction = p.faction,
			level = p.ai or "normal",
			ally = p.allyTeam,
			user = p.user,
			name = p.name,
		})
	end
	return {
		phase = "playing",
		mapId = c.mapId,
		mode = c.mode,
		win = c.win,
		friendlyFire = c.friendlyFire,
		cheats = c.cheats,
		slots = slots,
		results = nil,
		match = { matchId = c.matchId, roomName = c.lobby.roomName }, -- marks a lobby-run match (the results screen's Return to lobby)
	}
end

-- Sim player ID of a listed human, or "spectator", or nil (not listed:
-- kicked).
function MatchContract.seatOf(c: any, user: number): (number | string)?
	for i, p in c.players do
		if p.user == user then
			return i
		end
	end
	for _, s in c.spectators do
		if s.user == user then
			return "spectator"
		end
	end
	return nil
end

-- The colour index of each sim team (the client draws team colours from
-- the palette).
function MatchContract.teamColors(c: any): { [string]: number }
	local out = {}
	local teams = MatchContract.teams(c)
	for i, p in c.players do
		out[tostring(teams[i])] = p.color
	end
	return out
end

-- The results record (contract section 5). `outcome`: "finished", "draw"
-- or "abandoned"; `winner` the winning ally team ("finished"); `sim` and
-- `stats` (Stats.report) give the rest when the match ran; `startTick` is
-- when it started; `now` is os.time().
function MatchContract.result(c: any, outcome: string, sim: any?, stats: { [number]: any }?, startTick: number, now: number, reason: string?, winner: number?): any
	local players = {}
	for i in c.players do
		local p: any = { id = i, won = false }
		if sim and outcome == "finished" then
			p.won = sim.players[i] ~= nil and sim.players[i].allyTeam == winner
		end
		local out = sim and sim.match.eliminated[i]
		if out then
			p.outAt = (out - startTick) / 15
		end
		local st = stats and stats[i]
		if st then
			local flat = {}
			for _, k in MatchContract.STATS do
				if type(st[k]) == "number" then
					flat[k] = st[k]
				end
			end
			p.stats = flat
		end
		table.insert(players, p)
	end
	return {
		version = MatchContract.VERSION,
		matchId = c.matchId,
		outcome = outcome,
		winner = if outcome == "finished" then winner else nil,
		seconds = if sim then math.max(0, (sim.tick - startTick) / 15) else 0,
		endedAt = now,
		cheatsUsed = sim ~= nil and sim.cheats ~= nil and sim.cheats.used == true,
		reason = reason,
		players = players,
	}
end

-- The outcome when the match is over for the humans, its winner and a
-- reason: the sim's own end ("finished" with its winner, or "draw");
-- before that, "abandoned" when no human is left on the server, else from
-- who still stands: one ally team left → it won; none → a draw; several
-- (every human out while AI fight on in a free-for-all) → a draw with that
-- reason (the lobby stream decides how profiles count it).
function MatchContract.outcomeOf(sim: any, humansPresent: number): (string, number?, string?)
	if sim.match.over then
		local w = sim.match.winner
		if w ~= nil and w ~= 0 then
			return "finished", w, nil
		end
		return "draw", nil, nil
	end
	if humansPresent == 0 then
		return "abandoned", nil, "every player left"
	end
	local standing: { [number]: boolean } = {}
	local count = 0
	for _, pid in sim.playerOrder do
		if not sim.match.eliminated[pid] then
			local ally = sim.players[pid].allyTeam
			if not standing[ally] then
				standing[ally] = true
				count += 1
			end
		end
	end
	if count == 1 then
		return "finished", next(standing), nil
	end
	return "draw", nil, if count == 0 then nil else "every human is out; AI teams still fight"
end

-- Checks a results record against its config (the lobby's validateResult).
function MatchContract.validateResult(r: any, c: any): string?
	if type(r) ~= "table" then
		return "not a table"
	end
	if r.version ~= MatchContract.VERSION or r.matchId ~= c.matchId then
		return "version or matchId"
	end
	if not oneOf(MatchContract.OUTCOMES, r.outcome) then
		return "outcome"
	end
	if r.outcome == "finished" and not isInt(r.winner, 1, #c.players) then
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

return MatchContract

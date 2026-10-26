--!strict
-- The match server's side of the lobby ↔ match contract (C-173,
-- docs/contracts/match.md v1, the lobby stream's L-4): turning the match
-- config the lobby stored into the Sim config and a lobby-style seat list
-- (so the results screen and Lobby.results work as in a skirmish), and the
-- results record written back. The checks, limits and palette are the
-- shared @shared/Match/MatchConfig (S-145), the same the lobby place runs.
-- Pure Luau, tested under Lune (tests/client/MatchContract.spec).

local MatchConfig = require("@shared/Match/MatchConfig")

local MatchContract = {}

MatchContract.VERSION = MatchConfig.CONFIG_VERSION
MatchContract.MAP = "FtggMatch" -- the MemoryStore HashMap (contract section 4)
MatchContract.HEARTBEAT_EVERY = 30
MatchContract.HEARTBEAT_TTL = 120
MatchContract.RESULT_TTL = 3 * 24 * 3600
MatchContract.WAIT_SECONDS = 90 -- waiting for the listed humans after the first arrives (section 6)
MatchContract.RETURN_SECONDS = 30 -- the results screen's auto-return (section 6)
MatchContract.COLORS = MatchConfig.COLORS -- the palette (contract section 3): { name, rgb }

-- The stats a results record carries (the sim's Stats.report names).
MatchContract.STATS = table.freeze({ "unitsBuilt", "unitsLost", "unitsKilled", "damageDealt", "damageTaken", "supplyGathered", "powerGathered", "supplySpent", "powerSpent" })

-- Why players went back to the lobby (docs/contracts/match.md section 11,
-- F38, the user: every failed attempt shows in the lobby with a code and a
-- description): the match side's codes. The lobby holds the titles and
-- descriptions; the match sends { code, detail? } in the return teleport's
-- data and the result record's `error`.
MatchContract.ERROR = table.freeze({
	NO_SETUP = 201, -- no server/<id> or config/<id>
	BAD_SETUP = 202, -- the config failed the check (detail: the reason)
	VERSION = 203, -- the config's version isn't this place's
	GAME_VERSION = 204, -- the client's protocol or defs differ (REJECT)
	NOT_LISTED = 205, -- not a player or spectator of this match
	FULL = 206, -- no free seat
	OVER = 207, -- the match ended before they arrived
	NO_SHOW = 208, -- no listed human arrived in time: it never started
	EVERYONE_LEFT = 209,
	SERVER_ERROR = 210, -- the match server failed (detail: the error)
	OTHER = 299,
})
MatchContract.DETAIL_MAX = 200 -- characters of `detail` the lobby keeps
MatchContract.ARRIVE_SECONDS = 120 -- after the config is read, no listed human yet: NO_SHOW

export type Error = { code: number, detail: string? }

function MatchContract.error(code: number, detail: string?): Error
	return { code = code, detail = if detail and #detail > 0 then string.sub(detail, 1, MatchContract.DETAIL_MAX) else nil }
end

-- The error for a config this server can't run: none found, another
-- version, or failing the check (`why`, from validate).
function MatchContract.refusal(raw: any, why: string): Error
	local E = MatchContract.ERROR
	if raw == nil then
		return MatchContract.error(E.NO_SETUP)
	elseif type(raw) == "table" and raw.version ~= MatchContract.VERSION then
		return MatchContract.error(E.VERSION, `setup version {tostring(raw.version)}, match place {MatchContract.VERSION}`)
	end
	return MatchContract.error(E.BAD_SETUP, why)
end

-- Checks a config read back from MemoryStore. Returns nil, or what's wrong.
function MatchContract.validate(c: any): string?
	return MatchConfig.validate(c)
end

-- The Sim config (contract section 3, "To the sim config"). Player i is
-- seat i with its own team i and its faction (S-174: teams no longer encode
-- the faction); the host's seat starts the match from the pre-game (nil
-- when the host spectates); the host's spawn boxes, if drawn.
function MatchContract.toSim(c: any): any
	local players, ai = {}, {}
	local host: number? = nil
	for i, p in c.players do
		table.insert(players, { id = i, team = i, allyTeam = p.allyTeam, faction = p.faction })
		if p.ai then
			ai[i] = p.ai
		end
		if p.user ~= nil and p.user == c.host then
			host = i
		end
	end
	-- JSON keeps the ally teams as string keys
	local boxes: { [number]: { number } }? = nil
	if type(c.startBoxes) == "table" then
		local out = {}
		for ally, b in c.startBoxes do
			out[tonumber(ally) :: number] = b
		end
		boxes = out
	end
	return {
		seed = c.seed,
		players = players,
		mapId = c.mapId,
		scenario = "standard_start",
		-- every match opens with the pre-game: starts picked in game (S-171, C-218)
		match = { mode = c.mode, win = c.win, ai = ai, friendlyFire = c.friendlyFire, cheats = c.cheats, startMode = "choose", host = host, startBoxes = boxes },
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

-- The results record (contract section 5). `outcome`: "finished", "draw"
-- or "abandoned"; `winner` the winning ally team ("finished"); `sim` and
-- `stats` (Stats.report) give the rest when the match ran; `startTick` is
-- when it started; `now` is os.time(); `err` (optional) why the match
-- failed (an ERROR code).
function MatchContract.result(c: any, outcome: string, sim: any?, stats: { [number]: any }?, startTick: number, now: number, reason: string?, winner: number?, err: Error?): any
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
		error = err, -- why the match failed (section 11), for every returning player
		players = players,
	}
end

-- The outcome when the match is over for the humans, its winner and a
-- reason: the sim's own end ("finished" with its winner, or "draw");
-- before that, "abandoned" when no human is left on the server, else from
-- who still stands: one ally team left → it won; none → a draw; several
-- (every human out while AI fight on in a free-for-all) → "finished" with
-- no winner, so every player's `won` is false and the humans' profiles
-- count a loss (the lobby stream's decision, contract section 5).
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
	if count == 0 then
		return "draw", nil, nil
	end
	return "finished", nil, "every human is out; AI teams still fight"
end

-- Checks a results record against its config.
function MatchContract.validateResult(r: any, c: any): string?
	return MatchConfig.validateResult(r, c)
end

return MatchContract

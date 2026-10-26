--!strict
-- The Studio stand-in for a match server (L-6). Studio can't reserve or
-- teleport, so the stand-in Teleport hands the room's players here and this
-- plays the match server's side of docs/contracts/match.md in-process:
-- it finds its match through `server/<privateServerId>` like a real match
-- server, checks the config, refreshes `alive/<matchId>`, and at the end
-- writes `result/<matchId>` and sends everyone "back" (Returns.arrive, as a
-- teleport into the lobby would). The players never leave the server; their
-- client shows the stand-in match screen while they're in it.
--
-- Controls (the stand-in screen's buttons, Studio only):
--   finish   end now with a result
--   die      the server "crashes": heartbeats stop, no result, players are
--            sent back; the lobby's timeout ends the match as abandoned
--   leave    this player goes back early; the match runs on
-- Match-side errors (F38): refusals send players back with their code in the
-- teleport data (201 no config, 202 a bad one, 205 not listed); the
-- attribute `StandInFail = "match:<code>"` on ServerScriptService.Lobby
-- stages any 2xx at arrival (a whole-match code also writes the abandoned
-- result with it: 201-203, 208-210).

local Config = require("../shared/Config")
local Ctx = require("./Ctx")
local MatchConfig = require("../shared/MatchConfig")
local MatchErrors = require("../shared/MatchErrors")
local Prng = require("@shared/Util/Prng")
local Returns = require("./Returns")

local StandInMatch = {}

type Match = {
	matchId: string,
	config: MatchConfig.MatchConfig,
	players: { [number]: Player },
	endsAt: number,
	finishNow: boolean,
	dead: boolean,
}

local matches: { [string]: Match } = {} -- by private server ID
local flags: Instance? = nil -- ServerScriptService.Lobby (its StandInFail attribute)

function StandInMatch.init(attributes: Instance)
	flags = attributes
end

-- a match server sending players back with an error (F38)
local function refuse(players: { Player }, matchId: string?, err: MatchErrors.Error)
	warn(`[Lobby] stand-in match: sending back {#players} player(s), {MatchErrors.line(err)}`)
	for _, p in players do
		task.spawn(Returns.arrive, p, matchId, err)
	end
end

local WHOLE = { [201] = true, [202] = true, [203] = true, [208] = true, [209] = true, [210] = true }
local playing: { [number]: string } = {} -- user -> private server ID

function StandInMatch.has(user: number): boolean
	return playing[user] ~= nil
end

local function sendBack(m: Match, player: Player)
	m.players[player.UserId] = nil
	playing[player.UserId] = nil
	Ctx.send(player.UserId, { kind = "standIn", active = false })
	Returns.arrive(player, m.matchId)
end

-- A made-up but well-formed result: the winner and the numbers come from
-- the match seed, so the same config always ends the same way.
local function fakeResult(c: MatchConfig.MatchConfig, seconds: number): MatchConfig.Result
	local rng = Prng.new(c.seed)
	local allies = 0
	for _, p in c.players do
		allies = math.max(allies, p.allyTeam)
	end
	local winner = rng:nextInteger(1, allies)
	local players = {}
	for i, p in c.players do
		local won = p.allyTeam == winner
		players[i] = {
			id = i,
			won = won,
			outAt = if won then nil else math.floor(seconds * rng:nextNumber(0.5, 0.95)),
			stats = {
				unitsBuilt = rng:nextInteger(20, 120),
				unitsLost = rng:nextInteger(5, 80),
				unitsKilled = rng:nextInteger(5, 80),
				damageDealt = rng:nextInteger(5000, 90000),
				damageTaken = rng:nextInteger(5000, 90000),
				supplyGathered = rng:nextInteger(2000, 30000),
				powerGathered = rng:nextInteger(4000, 60000),
				supplySpent = rng:nextInteger(2000, 30000),
				powerSpent = rng:nextInteger(4000, 60000),
			},
		}
	end
	return {
		version = Config.CONFIG_VERSION,
		matchId = c.matchId,
		outcome = "finished",
		winner = winner,
		seconds = seconds,
		endedAt = os.time(),
		cheatsUsed = false,
		players = players,
	}
end

local function run(serverId: string, m: Match)
	local started = os.clock()
	local lastBeat = -math.huge
	while not (m.finishNow or m.dead or os.clock() >= m.endsAt) do
		if os.clock() - lastBeat >= 2 then
			lastBeat = os.clock()
			local n = 0
			for _ in m.players do
				n += 1
			end
			Ctx.store.set(`alive/{m.matchId}`, { at = os.time(), players = n }, Config.HEARTBEAT_TTL)
		end
		task.wait(0.25)
	end
	matches[serverId] = nil
	if not m.dead then
		-- a real match runs minutes: report a plausible length
		local seconds = math.floor((os.clock() - started) * 30)
		Ctx.store.set(`result/{m.matchId}`, fakeResult(m.config, seconds), Config.RESULT_TTL)
	else
		Ctx.store.remove(`alive/{m.matchId}`)
	end
	print(`[Lobby] stand-in match {m.matchId}: {if m.dead then "died" else "ended"}`)
	for _, p in m.players do
		sendBack(m, p)
	end
end

-- The stand-in Teleport's target: players arrive at private server
-- `serverId` carrying teleport data `data` ({ matchId }).
function StandInMatch.start(serverId: string, players: { Player }, data: any)
	local m = matches[serverId]
	if m == nil then
		-- what a real match server does first: its match from its own ID
		local ok, matchId = Ctx.store.get(`server/{serverId}`)
		local _, c = Ctx.store.get(`config/{matchId}`)
		if not ok or c == nil then
			refuse(players, nil, { code = 201 })
			return
		end
		local bad = MatchConfig.validate(c)
		if bad then
			refuse(players, matchId, { code = if c.version ~= Config.CONFIG_VERSION then 203 else 202, detail = bad })
			return
		end
		if type(data) ~= "table" or data.matchId ~= matchId then
			warn(`[Lobby] stand-in match on {serverId}: teleport data doesn't match; trusting the store`)
		end
		local staged = flags and flags:GetAttribute("StandInFail")
		local code = if type(staged) == "string" then tonumber(string.match(staged, "^match:(%d+)$")) else nil
		local err = if code then MatchErrors.clean({ code = code, detail = "staged in Studio" }) else nil
		if err then
			if WHOLE[err.code] then
				Ctx.store.set(`result/{matchId}`, {
					version = Config.CONFIG_VERSION,
					matchId = matchId,
					outcome = "abandoned",
					seconds = 0,
					endedAt = os.time(),
					cheatsUsed = false,
					error = err,
					players = (function()
						local out = {}
						for i in c.players do
							out[i] = { id = i, won = false }
						end
						return out
					end)(),
				}, Config.RESULT_TTL)
			end
			refuse(players, matchId, err)
			return
		end
		m = {
			matchId = matchId,
			config = c,
			players = {},
			endsAt = os.clock() + Config.STAND_IN_SECONDS,
			finishNow = false,
			dead = false,
		}
		matches[serverId] = m
		task.spawn(run, serverId, m)
	end
	local match = m :: Match
	local allowed = MatchConfig.users(match.config)
	for _, p in players do
		if table.find(allowed, p.UserId) then
			match.players[p.UserId] = p
			playing[p.UserId] = serverId
			Ctx.send(p.UserId, {
				kind = "standIn",
				active = true,
				matchId = match.matchId,
				mapId = match.config.mapId,
				seconds = math.max(0, math.floor(match.endsAt - os.clock())),
			})
		else
			refuse({ p }, match.matchId, { code = 205 }) -- not on the list: back to the lobby
		end
	end
end

function StandInMatch.control(player: Player, action: any)
	local serverId = playing[player.UserId]
	local m = serverId and matches[serverId]
	if m == nil then
		return
	end
	if action == "finish" then
		m.finishNow = true
	elseif action == "die" then
		m.dead = true
	elseif action == "leave" then
		sendBack(m, player)
	end
end

return StandInMatch

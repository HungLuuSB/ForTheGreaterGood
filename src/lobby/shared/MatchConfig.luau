--!strict
-- The match config the lobby builds from a room, and the room's summary of
-- a finished match (L-4; docs/contracts/match.md sections 3 and 5). The
-- record shapes, limits and checks are shared with the match place in
-- `@shared/Match/MatchConfig` (S-145); this module re-exports them, so the
-- lobby has one place to require. Pure Luau, tested under Lune.

local Rooms = require("./Rooms")
local Shared = require("@shared/Match/MatchConfig")

local MatchConfig = {}

export type Player = Shared.Player
export type MatchConfig = Shared.MatchConfig
export type ResultPlayer = Shared.ResultPlayer
export type Result = Shared.Result

MatchConfig.validate = Shared.validate
MatchConfig.validateResult = Shared.validateResult
MatchConfig.users = Shared.users
MatchConfig.OUTCOMES = Shared.OUTCOMES

export type Lobby = { placeId: number, jobId: string }

-- The config for a room that passed Rooms.checkStart. In Teams, ally teams
-- sit together (team 1's players first) and are renumbered 1..n in team
-- order. Every player's `start` is 0: starts are picked in the match's
-- pre-game (S-171; the map's starts are only hints).
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
			start = 0,
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
		version = Shared.CONFIG_VERSION,
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

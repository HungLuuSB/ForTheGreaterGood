--!strict
-- The match config the lobby builds from a room, and the room's summary of
-- a finished match (L-4; docs/contracts/match.md sections 3 and 5). The
-- record shapes, limits and checks are shared with the match place in
-- `@shared/Match/MatchConfig` (S-145); this module re-exports them, so the
-- lobby has one place to require. Pure Luau, tested under Lune.

local Rooms = require("./Rooms")
local Shared = require("@shared/Match/MatchConfig")
local TeamColors = require("@shared/Match/TeamColors")

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

-- Who plays, in match order: each seat's slot index, its player ID and
-- ally team. In Teams, ally teams sit together (team 1's players first) and
-- are renumbered 1..n in team order; in a free-for-all each player is its
-- own ally team. The match config and the room's colours both use it, so a
-- seat has the same ID in both.
export type Seat = { slot: number, id: number, allyTeam: number }
function MatchConfig.seats(room: Rooms.Room): { Seat }
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
	local out: { Seat } = {}
	for id, i in order do
		local ally = id
		if team then
			local t = room.slots[i].team
			if allyOf[t] == nil then
				allies += 1
				allyOf[t] = allies
			end
			ally = allyOf[t]
		end
		table.insert(out, { slot = i, id = id, allyTeam = ally })
	end
	return out
end

-- Each seat's colour as `viewer` (a user ID; nil or a spectator: the
-- spectator's view) sees it, by slot index (S-172): you and your allies
-- cold, enemies warm, as the match shows them.
function MatchConfig.colors(room: Rooms.Room, viewer: number?): { [number]: TeamColors.Color }
	local seats = MatchConfig.seats(room)
	local players: { TeamColors.Player } = {}
	local own = 0
	for _, seat in seats do
		local s = room.slots[seat.slot]
		table.insert(players, { id = seat.id, allyTeam = seat.allyTeam })
		if viewer ~= nil and s.kind == "human" and s.user == viewer then
			own = seat.id
		end
	end
	local byId = TeamColors.forViewer(own, players)
	local out: { [number]: TeamColors.Color } = {}
	for _, seat in seats do
		out[seat.slot] = byId[seat.id]
	end
	return out
end

-- The config for a room that passed Rooms.checkStart, its players in
-- MatchConfig.seats order. Every player's `start` is 0: starts are picked
-- in the match's pre-game (S-171; the map's starts are only hints). `color`
-- is still the seat's unique palette index (validated, unused: the match
-- colours players by TeamColors.forViewer, S-172).
function MatchConfig.build(room: Rooms.Room, matchId: string, seed: number, now: number, lobby: Lobby): MatchConfig
	local players: { Player } = {}
	local aiNumber = 0
	for _, seat in MatchConfig.seats(room) do
		local id = seat.id
		local s = room.slots[seat.slot]
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
			allyTeam = seat.allyTeam,
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
		host = room.host, -- the room host's UserId (F32): the match's pre-game starts it; seated or not
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

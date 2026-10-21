--!strict
-- Match flow (guide 16.3, C-70): a simple lobby for one human against the
-- skirmish AI (S-17). Pure Luau, no requires: Main.server passes the maps
-- (named MapRegistry maps with their start counts) and drives the phases:
--   lobby    settings change (map, mode, win, faction, AI slots and levels)
--   playing  the match runs; a player is out when the Match system says so
--   results  the match is over, or the human is out (the AI may fight on in
--            a free-for-all): who won, how long, each player's end
-- and back to the lobby. The human is sim player 1; factions follow teams
-- (odd = Order, even = Chaos, Scenarios.standard_start).

local Lobby = {}

Lobby.LEVELS = { "easy", "normal", "hard" }
Lobby.MODES = { "FFA", "TEAM" }
Lobby.WINS = { "COMMAND_ENDS", "ANNIHILATION" }
Lobby.FACTIONS = { "order", "chaos" }

export type Map = { id: string, name: string, starts: number }
export type State = {
	phase: string, -- "lobby" | "playing" | "results"
	mapId: string,
	mode: string,
	win: string,
	faction: string,
	ai: { string }, -- one level per AI slot
	results: any?,
}

function Lobby.new(maps: { Map }): State
	return { phase = "lobby", mapId = maps[1].id, mode = "FFA", win = "COMMAND_ENDS", faction = "order", ai = { "normal" }, results = nil }
end

local function mapOf(maps: { Map }, id: string): Map?
	for _, m in maps do
		if m.id == id then
			return m
		end
	end
	return nil
end

-- Applies a client's lobby message. Returns "start", "lobby" or nil (a
-- setting changed, or nothing), and an error for a refused message.
--   { op = "set", key = "mapId" | "mode" | "win" | "faction", value }
--   { op = "ai", index, level? }   level nil removes the slot; index #ai + 1 adds one
--   { op = "start" }, { op = "lobby" }
function Lobby.apply(s: State, maps: { Map }, msg: any): (string?, string?)
	if type(msg) ~= "table" then
		return nil, "not a message"
	end
	if msg.op == "lobby" then
		if s.phase == "results" then
			s.phase, s.results = "lobby", nil
			return "lobby", nil
		end
		return nil, "not after a match"
	end
	if s.phase ~= "lobby" then
		return nil, "the match is on"
	end
	local map = mapOf(maps, s.mapId) :: Map
	if msg.op == "set" then
		local v = msg.value
		if msg.key == "mapId" and type(v) == "string" and mapOf(maps, v) then
			s.mapId = v
			local starts = (mapOf(maps, v) :: Map).starts
			while #s.ai > starts - 1 do
				table.remove(s.ai)
			end
		elseif msg.key == "mode" and table.find(Lobby.MODES, v) then
			s.mode = v
		elseif msg.key == "win" and table.find(Lobby.WINS, v) then
			s.win = v
		elseif msg.key == "faction" and table.find(Lobby.FACTIONS, v) then
			s.faction = v
		else
			return nil, "bad setting"
		end
		return nil, nil
	elseif msg.op == "ai" then
		local i = msg.index
		if type(i) ~= "number" or i < 1 or i > #s.ai + 1 or i ~= math.floor(i) then
			return nil, "bad slot"
		end
		if msg.level == nil then
			if s.ai[i] and #s.ai > 1 then
				table.remove(s.ai, i)
			end
		elseif table.find(Lobby.LEVELS, msg.level) then
			if i == #s.ai + 1 and #s.ai + 1 > map.starts - 1 then
				return nil, "the map has no more starts"
			end
			s.ai[i] = msg.level
		else
			return nil, "bad level"
		end
		return nil, nil
	elseif msg.op == "start" then
		if #s.ai < 1 then
			return nil, "add an AI"
		end
		if s.mode == "TEAM" and #s.ai < 2 then
			return nil, "teams need 2 AIs or more"
		end
		s.phase = "playing"
		return "start", nil
	end
	return nil, "unknown op"
end

-- The Sim config for the lobby's settings: the human is player 1; AI
-- players 2.. take teams so factions follow the human's pick (Order odd,
-- Chaos even), alternating; in TEAM mode they split into two ally teams
-- with the human on ally team 1.
function Lobby.config(s: State, seed: number): any
	local humanTeam = if s.faction == "order" then 1 else 2
	local players = { { id = 1, team = humanTeam, allyTeam = 1 } }
	local nextTeam = { [1] = 1, [0] = 2 } -- next free team of each parity (odd, even)
	if humanTeam == 1 then
		nextTeam[1] = 3
	else
		nextTeam[0] = 4
	end
	local ai = {}
	for i, level in s.ai do
		local id = i + 1
		local parity = if i % 2 == 1 then (humanTeam + 1) % 2 else humanTeam % 2 -- enemies first: the other faction
		local team = nextTeam[parity]
		nextTeam[parity] += 2
		local allyTeam = if s.mode == "FFA" then id else (if i % 2 == 1 then 2 else 1)
		table.insert(players, { id = id, team = team, allyTeam = allyTeam })
		ai[id] = level
	end
	if s.mode == "FFA" then
		players[1].allyTeam = 1
	end
	return {
		seed = seed,
		players = players,
		mapId = s.mapId,
		scenario = "standard_start",
		match = { mode = s.mode, win = s.win, ai = ai },
	}
end

-- The results screen's summary from the finished sim.
function Lobby.results(s: State, sim: any, startTick: number): any
	local out = { winner = sim.match.winner, seconds = (sim.tick - startTick) / 15, players = {} }
	local units: { [number]: number } = {}
	for _, id in sim.world.ids do
		local o = sim.world.owner[id]
		units[o] = (units[o] or 0) + 1
	end
	for _, pid in sim.playerOrder do
		local p = sim.players[pid]
		local out_ = sim.match.eliminated[pid]
		table.insert(out.players, {
			id = pid,
			name = if pid == 1 then "You" else `AI {pid - 1} ({s.ai[pid - 1] or "?"})`,
			faction = if p.team % 2 == 1 then "Order" else "Chaos",
			allyTeam = p.allyTeam,
			won = p.allyTeam == sim.match.winner,
			outAt = if out_ then (out_ - startTick) / 15 else nil,
			units = units[pid] or 0,
		})
	end
	out.over = sim.match.over
	out.youWon = sim.match.over and sim.players[1].allyTeam == sim.match.winner
	return out
end

return Lobby

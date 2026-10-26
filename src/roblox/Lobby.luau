--!strict
-- Match flow (guide 16.3; C-70, slots since C-77): a lobby for humans and
-- the skirmish AI (S-17). Pure Luau, no requires: Main.server passes the
-- maps (named MapRegistry maps with their start counts), seats the Roblox
-- players and drives the phases:
--   lobby    settings change: map, mode, win rule, and per slot who plays it
--            (a human, an AI with its level, or open for a human to take),
--            its faction and, in Teams, its ally team
--   playing  the match runs; a player is out when the Match system says so
--   results  the match is over, or every human is out (the AI may fight on
--            in a free-for-all): who won, how long, each player's end and
--            statistics
-- and back to the lobby. Slot i is sim player i. The first human seated
-- (slot 1) hosts: only they change the settings, the AI slots and start;
-- each human picks their own faction. A human who leaves during a match
-- keeps the seat to rejoin; in the lobby the seat opens again.

local Lobby = {}

Lobby.LEVELS = { "easy", "normal", "hard" }
Lobby.MODES = { "FFA", "TEAM" }
Lobby.WINS = { "COMMAND_ENDS", "ANNIHILATION" }
Lobby.FACTIONS = { "order", "chaos" }

export type Map = { id: string, name: string, starts: number }
export type Slot = {
	kind: string, -- "human" | "ai" | "open"
	faction: string,
	level: string, -- an AI slot's difficulty
	ally: number, -- Teams: ally team 1 or 2
	user: number?, -- the seated human's Roblox UserId
	name: string?, -- their display name
}
export type State = {
	phase: string, -- "lobby" | "playing" | "results"
	mapId: string,
	mode: string,
	win: string,
	friendlyFire: boolean, -- S-73: a match option, on by default
	cheats: boolean, -- C-119: the host allows cheat commands (allow-listed players only); off by default
	slots: { Slot },
	results: any?,
}

local function slot(kind: string, faction: string, ally: number): Slot
	return { kind = kind, faction = faction, level = "normal", ally = ally, user = nil, name = nil }
end

-- A new lobby on the first map; `kinds` (optional) are the starting seats
-- (default: one open for the host, one AI).
function Lobby.new(maps: { Map }, kinds: { string }?): State
	local slots = {}
	for i, kind in kinds or { "open", "ai" } do
		table.insert(slots, slot(kind, if i % 2 == 1 then "order" else "chaos", if i % 2 == 1 then 1 else 2))
	end
	return { phase = "lobby", mapId = maps[1].id, mode = "FFA", win = "COMMAND_ENDS", friendlyFire = true, cheats = false, slots = slots, results = nil }
end

local function mapOf(maps: { Map }, id: string): Map?
	for _, m in maps do
		if m.id == id then
			return m
		end
	end
	return nil
end

-- The slot a human sits in, or nil.
function Lobby.slotOf(s: State, user: number): number?
	for i, sl in s.slots do
		if sl.kind == "human" and sl.user == user then
			return i
		end
	end
	return nil
end

-- Seats a human: their seat if they have one (a rejoin), else the first
-- open slot during the lobby. Returns the slot, or nil (no seat: they watch).
function Lobby.seat(s: State, user: number, name: string): number?
	local mine = Lobby.slotOf(s, user)
	if mine then
		s.slots[mine].name = name
		return mine
	end
	if s.phase ~= "lobby" then
		return nil
	end
	for i, sl in s.slots do
		if sl.kind == "open" then
			sl.kind, sl.user, sl.name = "human", user, name
			return i
		end
	end
	return nil
end

-- A human left: in the lobby their seat opens (a host leaving passes the
-- host to the next human by moving them to slot 1); in a match it stays
-- theirs to rejoin.
function Lobby.leave(s: State, user: number)
	local i = Lobby.slotOf(s, user)
	if i == nil or s.phase ~= "lobby" then
		return
	end
	local sl = s.slots[i]
	sl.kind, sl.user, sl.name = "open", nil, nil
	if i == 1 then
		for j = 2, #s.slots do
			if s.slots[j].kind == "human" then
				s.slots[1], s.slots[j] = s.slots[j], s.slots[1]
				break
			end
		end
	end
end

-- Applies slot `from`'s lobby message. Returns "start", "lobby" or nil (a
-- setting changed, or nothing), and an error for a refused message.
--   { op = "set", key = "mapId" | "mode" | "win" | "friendlyFire" | "cheats", value }   host
--   { op = "slot", index, kind = "ai" | "open" | nil, level? }   host; nil removes it, index #slots + 1 adds one
--   { op = "faction", index, value }   a human for their own slot; the host for AI and open slots
--   { op = "ally", index, value = 1 | 2 }                         host
--   { op = "start" }, { op = "lobby" }                             host
function Lobby.apply(s: State, maps: { Map }, msg: any, from: number?): (string?, string?)
	if type(msg) ~= "table" then
		return nil, "not a message"
	end
	local host = from == 1
	if msg.op == "lobby" then
		if not host then
			return nil, "only the host"
		end
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
	local i = msg.index
	local function validIndex(max: number): boolean
		return type(i) == "number" and i == math.floor(i) and i >= 1 and i <= max
	end
	if msg.op == "faction" then
		if not validIndex(#s.slots) or not table.find(Lobby.FACTIONS, msg.value) then
			return nil, "bad faction"
		end
		local sl = s.slots[i]
		local mine = sl.kind == "human" and i == from
		if not (mine or (host and sl.kind ~= "human")) then
			return nil, "not your slot"
		end
		sl.faction = msg.value
		return nil, nil
	end
	if not host then
		return nil, "only the host"
	end
	if msg.op == "set" then
		local v = msg.value
		if msg.key == "mapId" and type(v) == "string" and mapOf(maps, v) then
			local starts = (mapOf(maps, v) :: Map).starts
			for j = starts + 1, #s.slots do
				if s.slots[j].kind == "human" then
					return nil, "a human sits beyond the map's starts"
				end
			end
			s.mapId = v
			while #s.slots > starts do
				table.remove(s.slots)
			end
		elseif msg.key == "mode" and table.find(Lobby.MODES, v) then
			s.mode = v
		elseif msg.key == "win" and table.find(Lobby.WINS, v) then
			s.win = v
		elseif msg.key == "friendlyFire" and type(v) == "boolean" then
			s.friendlyFire = v
		elseif msg.key == "cheats" and type(v) == "boolean" then
			s.cheats = v
		else
			return nil, "bad setting"
		end
		return nil, nil
	elseif msg.op == "slot" then
		if not validIndex(#s.slots + 1) or i == 1 then
			return nil, "bad slot"
		end
		local sl = s.slots[i]
		if sl and sl.kind == "human" then
			return nil, "a human sits there"
		end
		if msg.kind == nil then
			if sl and #s.slots > 2 then
				table.remove(s.slots, i)
			end
			return nil, nil
		end
		if msg.kind ~= "ai" and msg.kind ~= "open" then
			return nil, "bad kind"
		end
		if msg.level ~= nil and not table.find(Lobby.LEVELS, msg.level) then
			return nil, "bad level"
		end
		if sl == nil then
			if #s.slots + 1 > map.starts then
				return nil, "the map has no more starts"
			end
			sl = slot(msg.kind, if #s.slots % 2 == 1 then "chaos" else "order", if #s.slots % 2 == 1 then 2 else 1)
			table.insert(s.slots, sl)
		end
		sl.kind = msg.kind
		sl.level = msg.level or sl.level
		return nil, nil
	elseif msg.op == "ally" then
		if not validIndex(#s.slots) or (msg.value ~= 1 and msg.value ~= 2) then
			return nil, "bad ally team"
		end
		s.slots[i].ally = msg.value
		return nil, nil
	elseif msg.op == "start" then
		local playing, allies = 0, {}
		for _, sl in s.slots do
			if sl.kind ~= "open" then
				playing += 1
				allies[sl.ally] = true
			end
		end
		if playing < 2 then
			return nil, "two players or more"
		end
		if s.mode == "TEAM" and not (allies[1] and allies[2]) then
			return nil, "both teams need a player"
		end
		-- open seats nobody took don't play: the rest renumber in order
		for j = #s.slots, 1, -1 do
			if s.slots[j].kind == "open" then
				table.remove(s.slots, j)
			end
		end
		s.phase = "playing"
		return "start", nil
	end
	return nil, "unknown op"
end

-- The Sim config for the lobby: slot i is player i with team i and the
-- slot's faction (S-174); its ally team is its own in a free-for-all, else
-- the slot's.
function Lobby.config(s: State, seed: number): any
	local players, ai = {}, {}
	for i, sl in s.slots do
		table.insert(players, { id = i, team = i, allyTeam = if s.mode == "FFA" then i else sl.ally, faction = sl.faction })
		if sl.kind == "ai" then
			ai[i] = sl.level
		end
	end
	return {
		seed = seed,
		players = players,
		mapId = s.mapId,
		scenario = "standard_start",
		match = { mode = s.mode, win = s.win, ai = ai, friendlyFire = s.friendlyFire, cheats = s.cheats },
	}
end

-- Sim player IDs the humans play.
function Lobby.humans(s: State): { number }
	local out = {}
	for i, sl in s.slots do
		if sl.kind == "human" then
			table.insert(out, i)
		end
	end
	return out
end

-- Is the match over for the humans: it ended, or every human is out?
function Lobby.done(s: State, sim: any): boolean
	if sim.match.over then
		return true
	end
	local humans = Lobby.humans(s)
	if #humans == 0 then
		return false
	end
	for _, id in humans do
		if not sim.match.eliminated[id] then
			return false
		end
	end
	return true
end

-- The results screen's summary from the finished sim; `stats` (optional)
-- is the sim's Stats.report (S-63): per player units built / lost / killed,
-- damage dealt, supply and power gathered and spent. Each client finds itself by
-- its UserId (`user`) and decides victory or defeat from `won`.
function Lobby.results(s: State, sim: any, startTick: number, stats: { [number]: any }?): any
	local out = { winner = sim.match.winner, seconds = (sim.tick - startTick) / 15, players = {}, over = sim.match.over }
	local units: { [number]: number } = {}
	for _, id in sim.world.ids do
		local o = sim.world.owner[id]
		units[o] = (units[o] or 0) + 1
	end
	local aiNumber = 0
	for _, pid in sim.playerOrder do
		local p = sim.players[pid]
		local sl = s.slots[pid]
		local out_ = sim.match.eliminated[pid]
		local name
		if sl and sl.kind == "human" then
			name = sl.name or `Player {pid}`
		else
			aiNumber += 1
			name = `AI {aiNumber} ({if sl then sl.level else "?"})`
		end
		table.insert(out.players, {
			id = pid,
			user = if sl then sl.user else nil,
			name = name,
			human = sl ~= nil and sl.kind == "human",
			faction = if p.faction == "chaos" then "Chaos" else "Order",
			team = p.team, -- its team color (the statistics panel, C-105)
			allyTeam = p.allyTeam,
			won = sim.match.over and p.allyTeam == sim.match.winner,
			outAt = if out_ then (out_ - startTick) / 15 else nil,
			units = units[pid] or 0,
			stats = if stats then stats[pid] else nil,
		})
	end
	return out
end

return Lobby

--!strict
-- Match rules (guide 16.1–16.4): FFA / Team setup checks, unit caps, win
-- conditions, elimination and the match result.
--
--   * FFA: every player is their own ally team, up to 8 players.
--     TEAM: 2–4 ally teams of 1–4 players each (DECISIONS D87).
--   * Unit cap per player: units and structures owned, frames included.
--     At the cap, new construction fails ("unit_cap") and finished factory
--     items wait at the exit until there is room.
--   * Win conditions, checked every tick by the Match system:
--       COMMAND_ENDS  a player with no Command Vehicle (COMMANDER) left is out;
--       ANNIHILATION  a player with no units or structures left is out.
--     An eliminated player's units and structures self-destruct (lethal
--     overkill damage: no wrecks), applied by the next Damage step. An ally
--     team is defeated when all its players are out; when at most one ally
--     team remains the match ends (winner 0 = nobody left: a draw).
--   * Per-player counts are kept by Lifecycle hooks, so checks are O(players).

local Categories = require("@shared/Defs/Categories")
local Combat = require("./Combat/Combat")
local World = require("./World")
local Lifecycle = require("./Lifecycle")
local MatchState = require("./MatchState")
local Types = require("./Types")

local Match = {}

Match.MAX_FFA_PLAYERS = 8
Match.MAX_ALLY_TEAMS = 4
Match.MAX_TEAM_SIZE = 4

local COMMANDER = Categories.Bit.COMMANDER

-- Guide 16.4: 300 per player in 1v1 down to 150 in an 8-player FFA.
function Match.defaultCap(playerCount: number): number
	return math.clamp(300 - 25 * (playerCount - 2), 150, 300)
end

-- Checks a match config against the players; errors with a clear message.
-- Returns the unit cap to use.
function Match.validate(config: MatchState.Config, players: { [number]: Types.Player }, order: { number }): number
	if config.mode ~= "FFA" and config.mode ~= "TEAM" then
		error(`Match: mode must be "FFA" or "TEAM", got {tostring(config.mode)}`, 3)
	end
	if config.win ~= "COMMAND_ENDS" and config.win ~= "ANNIHILATION" then
		error(`Match: win must be "COMMAND_ENDS" or "ANNIHILATION", got {tostring(config.win)}`, 3)
	end
	local sizes: { [number]: number } = {}
	local allyCount = 0
	for _, pid in order do
		local ally = players[pid].allyTeam :: number
		if sizes[ally] == nil then
			sizes[ally] = 0
			allyCount += 1
		end
		sizes[ally] += 1
	end
	if config.mode == "FFA" then
		if #order < 2 or #order > Match.MAX_FFA_PLAYERS then
			error(`Match: FFA needs 2..{Match.MAX_FFA_PLAYERS} players, got {#order}`, 3)
		end
		if allyCount ~= #order then
			error("Match: in FFA every player is their own ally team", 3)
		end
	else
		if allyCount < 2 or allyCount > Match.MAX_ALLY_TEAMS then
			error(`Match: TEAM needs 2..{Match.MAX_ALLY_TEAMS} ally teams, got {allyCount}`, 3)
		end
		for _, pid in order do
			if sizes[players[pid].allyTeam :: number] > Match.MAX_TEAM_SIZE then
				error(`Match: an ally team has more than {Match.MAX_TEAM_SIZE} players`, 3)
			end
		end
	end
	for pid, level in config.ai or {} do
		if players[pid] == nil then
			error(`Match: ai names unknown player {tostring(pid)}`, 3)
		end
		if level ~= "easy" and level ~= "normal" and level ~= "hard" then
			error(`Match: ai level must be "easy", "normal" or "hard", got {tostring(level)}`, 3)
		end
	end
	local cap = config.unitCap or Match.defaultCap(#order)
	if cap ~= math.floor(cap) or cap < 1 or cap > 65535 then
		error(`Match: unitCap must be an integer in 1..65535, got {cap}`, 3)
	end
	return cap
end

-- Is `player` at their unit cap? (Never without match rules.)
function Match.atCap(sim: Types.Sim, player: number): boolean
	local m = sim.match
	return m.enabled and m.unitCap > 0 and (m.units[player] or 0) >= m.unitCap
end

local function isCommander(sim: Types.Sim, id: number): boolean
	return bit32.band(sim.defs.unitByIndex[sim.world.defIndex[id]].categoryMask, COMMANDER) ~= 0
end

table.insert(Lifecycle.addedHooks, function(sim: Types.Sim, id: number)
	local m = sim.match
	local owner = sim.world.owner[id]
	if sim.players[owner] == nil then
		return
	end
	m.units[owner] = (m.units[owner] or 0) + 1
	if isCommander(sim, id) then
		m.commanders[owner] = (m.commanders[owner] or 0) + 1
	end
end)

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	local m = sim.match
	local owner = sim.world.owner[id]
	if sim.players[owner] == nil then
		return
	end
	-- (units placed with World.spawn directly, as some tests do, were never counted)
	if (m.units[owner] or 0) > 0 then
		m.units[owner] -= 1
	end
	if isCommander(sim, id) and (m.commanders[owner] or 0) > 0 then
		m.commanders[owner] -= 1
	end
end)

Match.SELF_DESTRUCT_PER_TICK = 20 -- an eliminated player's units go this many a tick (S-144)
Match.SELF_DESTRUCT_STRUCTURE = 10 -- a structure counts as this many (S-164: freeing a footprint costs ms)

-- Self-destructs the next eliminated players' units, a few a tick: a whole
-- base at once cost tens of ms in one tick (every structure's footprint
-- freed, every death and wreck sent; S-144, the live server's watchdog).
-- Structures weigh SELF_DESTRUCT_STRUCTURE against the tick's allowance,
-- so about 2 go a tick (S-164: 20 a tick still cost Damage 96 ms in B's
-- Studio run); the first in line always goes, so the list always shrinks.
local function selfDestruct(sim: Types.Sim)
	local m = sim.match
	local list = m.doomed
	if #list == 0 then
		return
	end
	local w = sim.world
	local done, i = 0, 1
	while i <= #list do
		local id, gen = list[i], list[i + 1]
		if World.isRef(w, id, gen) then
			local weight = if sim.defs.unitByIndex[w.defIndex[id]].domain == "structure" then Match.SELF_DESTRUCT_STRUCTURE else 1
			if done > 0 and done + weight > Match.SELF_DESTRUCT_PER_TICK then
				break
			end
			Combat.queueDamage(sim.combat, id, w.health[id] * 4 + 1, 0)
			done += weight
		end
		i += 2
	end
	m.doomed = table.move(list, i, #list, 1, {}) -- the rest, for the next ticks
end

-- Match system body (after Construction, every tick).
function Match.step(sim: Types.Sim)
	local m = sim.match
	if not m.enabled then
		return
	end
	selfDestruct(sim)
	if m.over then
		return
	end
	local w = sim.world
	local c = sim.combat
	local newly: { number } = {}
	for _, pid in sim.playerOrder do
		if m.eliminated[pid] == nil then
			local out = if m.win == "COMMAND_ENDS" then (m.commanders[pid] or 0) == 0 else (m.units[pid] or 0) == 0
			if out then
				m.eliminated[pid] = sim.tick
				table.insert(newly, pid)
				Combat.addEvent(c, { kind = "ELIMINATED", tick = sim.tick, unit = 0, other = pid })
			end
		end
	end
	if #newly > 0 then
		-- self-destruct everything they still own, a few a tick (S-144)
		for _, id in w.ids do
			if table.find(newly, w.owner[id]) then
				table.insert(m.doomed, id)
				table.insert(m.doomed, w.gen[id])
			end
		end
	end
	local alive: { number } = {}
	for _, ally in sim.allyTeams do
		for _, pid in sim.playerOrder do
			if sim.players[pid].allyTeam == ally and m.eliminated[pid] == nil then
				table.insert(alive, ally)
				break
			end
		end
	end
	if #alive <= 1 then
		m.over = true
		m.winner = alive[1] or 0
		m.endTick = sim.tick
		Combat.addEvent(c, { kind = "MATCH_END", tick = sim.tick, unit = 0, other = m.winner })
	end
end

return Match

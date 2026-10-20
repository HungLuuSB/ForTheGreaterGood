--!strict
-- The server simulation: fixed tick, fixed system order (guide 3.3).
--
--   local sim = Sim.new({ seed = 123, players = { { id = 1, team = 1 }, { id = 2, team = 2 } } })
--   Sim.submit(sim, 1, payload)   -- a Schema command record from player 1
--   Sim.step(sim)                 -- one 66.7 ms tick
--
-- Deterministic: the same config, the same commands at the same ticks, the
-- same result. Sim.step never reads a clock, never yields and never uses
-- pairs() order. The tick loop driving it (Heartbeat accumulator, catch-up
-- cap) lives in the Roblox entry script, which needs Studio (later).

local Defs = require("@shared/Defs/Defs")
local Hash = require("@shared/Util/Hash")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Passability = require("@shared/Grid/Passability")
local Packer = require("@shared/Net/Packer")
local Prng = require("@shared/Util/Prng")
local Profiler = require("@shared/Util/Profiler")
local Schema = require("@shared/Net/Schema")
local BuildState = require("./BuildState")
local Combat = require("./Combat/Combat")
local Economy = require("./Economy")
local Nav = require("./Nav")
local _Placement = require("./Placement") -- registers its Lifecycle removal hook
local Replay = require("./Replay")
local Scenarios = require("./Scenarios")
local Types = require("./Types")
local World = require("./World")

local Sim = {}

Sim.TICK_RATE = 15
Sim.CHECKPOINT_INTERVAL = 300 -- ticks between world-hash checkpoints (guide 17.1)
Sim.MAX_TEAMS = Schema.MAX_TEAMS

export type Sim = Types.Sim

export type Config = {
	seed: number,
	players: { Types.Player },
	mapId: string?, -- MapRegistry ID, default "none" (no terrain, no movement)
	scenario: string?, -- key in Scenarios, default "empty"
	defs: Defs.DefSet?, -- default Defs.load()
}

type System = { name: string, every: number, run: (Sim) -> () }

-- Fixed order; never changes at runtime (guide 3.3).
local SYSTEMS: { System } = {
	{ name = "Sim.Commands", every = 1, run = require("./Systems/Commands") },
	{ name = "Sim.Economy", every = 5, run = require("./Systems/Economy") },
	{ name = "Sim.Sensors", every = 2, run = require("./Systems/Sensors") },
	{ name = "Sim.Targeting", every = 1, run = require("./Systems/Targeting") },
	{ name = "Sim.Pathing", every = 1, run = require("./Systems/Pathing") },
	{ name = "Sim.Movement", every = 1, run = require("./Systems/Movement") },
	{ name = "Sim.Weapons", every = 1, run = require("./Systems/Weapons") },
	{ name = "Sim.Projectiles", every = 1, run = require("./Systems/Projectiles") },
	{ name = "Sim.Damage", every = 1, run = require("./Systems/Damage") },
	{ name = "Sim.Construction", every = 1, run = require("./Systems/Construction") },
	{ name = "Sim.NetOut", every = 1, run = require("./Systems/NetOut") },
}

Sim.SYSTEM_ORDER = table.freeze((function()
	local names = {}
	for i, s in SYSTEMS do
		names[i] = s.name
	end
	return names
end)())

function Sim.new(config: Config): Sim
	local seed = config.seed
	local scenario = config.scenario or "empty"
	local setup = Scenarios[scenario]
	if setup == nil then
		error(`Sim.new: unknown scenario "{scenario}"`, 2)
	end

	local players: { [number]: Types.Player } = {}
	local order: { number } = {}
	for _, p in config.players do
		if p.id ~= math.floor(p.id) or p.id < 1 or p.id > 255 or players[p.id] then
			error(`Sim.new: player IDs must be unique integers in 1..255, got {p.id}`, 2)
		end
		if p.team ~= math.floor(p.team) or p.team < 1 or p.team > Sim.MAX_TEAMS then
			error(`Sim.new: team must be an integer in 1..{Sim.MAX_TEAMS}, got {p.team}`, 2)
		end
		players[p.id] = { id = p.id, team = p.team }
		table.insert(order, p.id)
	end
	table.sort(order)

	local defs = config.defs or Defs.load()
	local mapId = config.mapId or "none"
	local layers = MapRegistry.load(mapId)
	local map = if layers then Passability.build(layers) else nil
	local headerPlayers = {}
	for i, id in order do
		headerPlayers[i] = { id = id, team = players[id].team }
	end

	local sim: Sim = {
		tick = 0,
		seed = seed,
		mapId = mapId,
		scenario = scenario,
		world = World.new(),
		rng = Prng.new(seed),
		defs = defs,
		map = map,
		nav = if map then Nav.new(map, defs) else nil,
		combat = Combat.new(defs, layers),
		build = BuildState.new(),
		eco = Economy.new((function()
			local teams = {}
			for _, id in order do
				table.insert(teams, players[id].team)
			end
			return teams
		end)()),
		players = players,
		playerOrder = order,
		queue = {},
		replay = Replay.new({
			protocolVersion = Schema.PROTOCOL_VERSION,
			defsHash = defs.hash,
			seed = seed,
			mapId = mapId,
			scenario = scenario,
			players = headerPlayers,
		}),
		stats = { commandsApplied = 0, commandsRejected = 0 },
	}
	setup(sim)
	return sim
end

-- Queues one command record from `player` for the next tick. Returns false
-- and a reason for unknown players and malformed payloads (guide 19: decode
-- defensively, drop bad packets). Never throws on bad input.
function Sim.submit(sim: Sim, player: number, payload: buffer): (boolean, string?)
	if sim.players[player] == nil then
		sim.stats.commandsRejected += 1
		return false, `unknown player {player}`
	end
	local ok, result = pcall(function()
		local r = Packer.Reader.new(payload)
		local cmd = Schema.decodeCommand(r)
		if not r:atEnd() then
			r:fail(`{r:remaining()} trailing byte(s)`)
		end
		return cmd
	end)
	if not ok then
		sim.stats.commandsRejected += 1
		return false, tostring(result)
	end
	table.insert(sim.queue, { player = player, payload = payload, cmd = result })
	return true, nil
end

-- Hash of the whole simulation state: tick, PRNG state, world, combat
-- (projectiles, wrecks), economy and construction.
function Sim.hash(sim: Sim): number
	local h = Hash.u32(Hash.OFFSET_BASIS, sim.tick)
	local s0, s1, s2, s3 = sim.rng:getState()
	h = Hash.u32(Hash.u32(Hash.u32(Hash.u32(h, s0), s1), s2), s3)
	h = Economy.hash(sim.eco, Combat.hash(sim.combat, World.hash(sim.world, h)))
	local ids = table.clone(sim.world.ids)
	table.sort(ids)
	return BuildState.hash(sim.build, ids, h)
end

-- Advances one tick: every system in order, at its rate.
function Sim.step(sim: Sim)
	local tick = sim.tick + 1
	sim.tick = tick
	table.clear(sim.combat.events) -- events describe one tick (NetOut sends them)
	for _, system in SYSTEMS do
		if tick % system.every == 0 then
			Profiler.begin(system.name)
			system.run(sim)
			Profiler.finish()
		end
	end
	if tick % Sim.CHECKPOINT_INTERVAL == 0 then
		Replay.addCheckpoint(sim.replay, tick, Sim.hash(sim))
	end
end

-- Rebuilds a simulation from a replay header. Errors if the replay was
-- recorded with another protocol version or def set.
function Sim.fromReplay(log: Replay.Log, defs: Defs.DefSet?): Sim
	local h = log.header
	local set = defs or Defs.load()
	if h.protocolVersion ~= Schema.PROTOCOL_VERSION then
		error(`Sim.fromReplay: replay protocol {h.protocolVersion}, this build is {Schema.PROTOCOL_VERSION}`, 2)
	end
	if h.defsHash ~= set.hash then
		error(`Sim.fromReplay: replay defs hash {h.defsHash}, this build is {set.hash}`, 2)
	end
	return Sim.new({ seed = h.seed, players = h.players, mapId = h.mapId, scenario = h.scenario, defs = set })
end

-- Plays a replay to `untilTick` (default: its last entry's tick) and compares
-- every checkpoint. Returns the new sim, and the first mismatching tick or nil.
function Sim.runReplay(log: Replay.Log, untilTick: number?): (Sim, number?)
	local sim = Sim.fromReplay(log)
	local last = 0
	for _, e in log.entries do
		last = math.max(last, e.tick)
	end
	local target = untilTick or last
	local entries = log.entries
	local i = 1
	local expected: { [number]: number } = {}
	for _, cp in Replay.checkpoints(log) do
		expected[cp[1]] = cp[2]
	end

	while sim.tick < target do
		local nextTick = sim.tick + 1
		-- Queue the commands that were applied on nextTick, in recorded order.
		while entries[i] and entries[i].tick <= nextTick do
			local e = entries[i]
			if e.kind == Replay.Kind.COMMAND and e.tick == nextTick then
				local ok, err = Sim.submit(sim, e.player :: number, e.payload :: buffer)
				if not ok then
					error(`Sim.runReplay: recorded command at tick {e.tick} was rejected: {err}`, 2)
				end
			end
			i += 1
		end
		Sim.step(sim)
		local want = expected[sim.tick]
		if want ~= nil and want ~= Sim.hash(sim) then
			return sim, sim.tick
		end
	end
	return sim, nil
end

return Sim

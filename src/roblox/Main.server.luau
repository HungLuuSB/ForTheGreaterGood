--!strict
-- Roblox server entry, minimal (STUDIO_HANDOFF step 3, C-9): runs the real
-- Sim at 15 Hz from a Heartbeat accumulator (at most 3 steps per frame,
-- guide 3.3), sends each human player's NetOut outbox over one remote per
-- Schema.Channel, and feeds Cmd messages to Sim.submit.
--
-- Join (net.md section 10): a client's HELLO on the Snapshot channel is
-- checked with NetOut.hello (REJECT on a protocol or defs mismatch), then
-- NetOut.join queues its WELCOME; nothing is sent to a player before that.
-- Not yet: guide 19 checks beyond a rate limit and a size cap, replay saving.
--
-- Match flow (C-70; seats since C-77): a profile with `lobby = true` starts
-- in a lobby (src/roblox/Lobby: map, mode, win rule, and seats: a human,
-- an AI and its level, or open; factions and ally teams), published to
-- clients as the Remotes folder's "Lobby" attribute (JSON) and changed
-- through the "Lobby" remote. Roblox players take open seats as they join
-- (the first hosts; `seats` in the profile sets the starting ones); seat i
-- plays sim player i. In the lobby an empty sim on the chosen map runs as
-- a preview; Start builds the match (the skirmish AI plays its seats,
-- S-17), the Match system ends it, the results (with the sim's Stats, S-63) are
-- published once every human is out or the match is over, and "back to
-- lobby" returns to the preview. A human who leaves mid-match keeps the
-- seat and rejoins into it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- full paths, so check_build can resolve them
local Sim = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Sim")) :: any
local NetOut = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("NetOut")) :: any
local Defs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Defs"):WaitForChild("Defs")) :: any
local Packer = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Packer")) :: any
local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Schema")) :: any
local PlayerReplay = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("PlayerReplay")) :: any
local Config = require(script.Parent:WaitForChild("MatchConfig")) :: any
local Combat = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Combat"):WaitForChild("Combat")) :: any
local Spawn = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Spawn")) :: any
local SimWorld = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("World")) :: any
local Skirmish = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("AI"):WaitForChild("Skirmish")) :: any
local MapRegistry = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Grid"):WaitForChild("MapRegistry")) :: any
local Lobby = require(script.Parent:WaitForChild("Lobby")) :: any
local Stats = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Stats")) :: any
local StatSeries = require(script.Parent:WaitForChild("StatSeries")) :: any
local Build = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Build")) :: any
local HttpService = game:GetService("HttpService")

local DT = 1 / Sim.TICK_RATE
local MAX_STEPS_PER_FRAME = 3
local CMD_MAX_BYTES = 2048
local CMD_RATE = 20 -- messages per second, burst 40
local SEND_ORDER = { "Snapshot", "Events", "Tactical", "State", "Projectiles", "Strategic", "Eco" }

-- An RTS has no avatars.
Players.CharacterAutoLoads = false

-- Remotes, one per channel (net.md section 1)
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local remoteOf: { [string]: any } = {}
for name, ch in Schema.Channel do
	local r = Instance.new(if ch.reliable then "RemoteEvent" else "UnreliableRemoteEvent")
	r.Name = name
	r.Parent = remotes
	remoteOf[name] = r
end

-- Global sim speed for debugging (C-35): the tick loop runs `speed` times
-- as fast (0 = paused); clients read it from the Remotes folder's SimSpeed
-- attribute to pace their render clock. Changed with the client's - / = / P
-- keys through SimSpeed requests, honored in Studio only.
local SPEEDS = { 0, 0.1, 0.25, 0.5, 1, 2, 4 }
local speed = Config.speed or 1
remotes:SetAttribute("SimSpeed", speed)
local speedRemote = Instance.new("RemoteEvent")
speedRemote.Name = "SimSpeed"
speedRemote.Parent = remotes
speedRemote.OnServerEvent:Connect(function(player: Player, value: any)
	if RunService:IsStudio() and type(value) == "number" and table.find(SPEEDS, value) then
		speed = value
		remotes:SetAttribute("SimSpeed", speed)
		print(`[Entry] {player.Name} set the sim speed to {speed}x`)
	end
end)
-- Test-only weapon overrides from the match profile (MatchConfig
-- `weaponOverrides`, C-60): numbers no client simulates (a stockpile's
-- build time and cost, an interception chance, the reload), merged into a copy of the
-- registry's weapons for this server only. The copy keeps the registry's
-- hash so clients still join; their defs keep the registry's numbers,
-- which only the stock pip's animation between records reads (the server
-- sends the progress every sixteenth anyway).
local OVERRIDABLE: { [string]: any } = { stockpile = { buildTime = true, cost = true }, intercepts = { chance = true }, reload = true }

local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

local function withOverrides(base: any, overrides: { [string]: any }?): any
	if overrides == nil or next(overrides) == nil then
		return base
	end
	local weapons, byIndex = table.clone(base.weapons), table.clone(base.weaponByIndex)
	for id, fields in overrides do
		local w = copy(base.weapons[id] or error(`[Entry] weaponOverrides: no weapon {id}`))
		for field, values in fields do
			local allowed = OVERRIDABLE[field]
			if allowed == nil or w[field] == nil then
				error(`[Entry] weaponOverrides.{id}.{field}: only reload, an existing stockpile's buildTime / cost or intercepts.chance can be overridden`)
			end
			if allowed == true then
				w[field] = values -- a number (reload)
				continue
			end
			for k, v in values do
				if not allowed[k] then
					error(`[Entry] weaponOverrides.{id}.{field}.{k} can't be overridden (clients simulate it)`)
				end
				w[field][k] = copy(v)
			end
		end
		weapons[id] = w
		byIndex[w.index] = w
		print(`[Entry] test override: {id} {game:GetService("HttpService"):JSONEncode(fields)}`)
	end
	return { units = base.units, weapons = weapons, unitByIndex = base.unitByIndex, weaponByIndex = byIndex, hash = base.hash }
end

local defs = withOverrides(Defs.load(), Config.weaponOverrides)

local sim: any
local brains: { any } = {} -- the skirmish AI's players in a lobby match (C-70)
local PREVIEW_PLAYERS = 8 -- the lobby preview has a sim player for every seat a human may take
local matchStartTick = 0
local series: any = nil -- the statistics panel's samples over time (StatSeries, C-105)
local matchId = 0
local seed = Config.seed
local endedAt: number? = nil

local slotOf: { [Player]: number } = {} -- Roblox player → sim player ID
-- Spectators (C-79, S-18): Roblox players without a seat watch everything;
-- their index in sim.net.spectators (0 until their HELLO)
local specOf: { [Player]: number } = {}
-- Player replays (C-79, S-18): each human's stream in a lobby match,
-- recorded tick by tick; kept for the results' Save / Watch
local recorders: { [number]: any } = {} -- sim player ID → PlayerReplay
local recordedBytes = 0
local MAX_RECORDED_BYTES = 32 * 1024 * 1024 -- all recordings together; past it they stop growing
local savedReplays: { [number]: { { name: string, file: buffer } } } = {} -- UserId → saved this session
local lobby: any = nil -- the lobby's state (C-70; seats since C-77)
local lobbyMaps: { any } = {}
local joined: { [Player]: boolean } = {} -- HELLO accepted: receives the outbox
local tokens: { [Player]: number } = {}

local function encode(cmd: any): buffer
	local w = Packer.Writer.new(64)
	Schema.encodeCommand(w, cmd)
	return w:finish()
end

local function unitsOf(player: number): { number }
	local out = {}
	for _, id in sim.world.ids do
		if sim.world.owner[id] == player then
			table.insert(out, id)
		end
	end
	return out
end

local function centroid(ids: { number }): (number, number)
	local sx, sz = 0, 0
	for _, id in ids do
		sx += sim.world.posX[id]
		sz += sim.world.posZ[id]
	end
	return sx / math.max(#ids, 1), sz / math.max(#ids, 1)
end

local function isHuman(id: number): boolean
	if lobby then
		return lobby.slots[id] ~= nil and lobby.slots[id].kind == "human"
	end
	return table.find(Config.humanSlots, id) ~= nil
end

-- Placeholder orders (Config.demoOrders) for bot players: each drives to the midpoint
-- between its own and the enemy's centroids, re-issued every DEMO_EVERY
-- ticks, so the sides meet and brawl instead of driving through each other
-- (the sim's FIGHT is still a plain move, net.md section 9).
local DEMO_EVERY = 150
local function demoOrders()
	local grid = sim.map.layers.grid
	for _, p in Config.players do
		if isHuman(p.id) then
			continue -- humans give their own orders (client task 5)
		end
		local own = unitsOf(p.id)
		local enemy = {}
		for _, q in Config.players do
			if q.team ~= p.team then
				for _, id in unitsOf(q.id) do
					table.insert(enemy, id)
				end
			end
		end
		if #own > 0 and #enemy > 0 then
			local ox, oz = centroid(own)
			local ex, ez = centroid(enemy)
			local cell, offX, offZ = grid:encode((ox + ex) / 2, (oz + ez) / 2)
			Sim.submit(sim, p.id, encode({ cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = own, cell = cell, offX = offX, offZ = offZ }))
		end
	end
end

-- The lobby (C-70): its maps with their start counts, its remote.
local lobbyRemote = Instance.new("RemoteEvent")
lobbyRemote.Name = "Lobby"
lobbyRemote.Parent = remotes
local publishLobby: () -> ()

-- The match is over for the humans (or a Studio debug ended it): the
-- results, with the statistics over time (C-105).
local function finishMatch()
	lobby.phase = "results"
	local report = Stats.report(sim)
	lobby.results = Lobby.results(lobby, sim, matchStartTick, report)
	if series then
		StatSeries.sample(series, sim, report)
		lobby.results.series = series
	end
	lobby.results.replays = next(recorders) ~= nil
	brains = {}
	print(`[Entry] match over for the humans: {if sim.match.over then `ally team {sim.match.winner} won` else "all out"}`)
	publishLobby()
end

function publishLobby()
	if lobby then
		local names = {}
		for _, m in lobbyMaps do
			table.insert(names, { id = m.id, name = m.name, starts = m.starts })
		end
		remotes:SetAttribute("Lobby", HttpService:JSONEncode({ state = lobby, maps = names, levels = Lobby.LEVELS }))
	end
end
if Config.lobby then
	local ids = {}
	for name in MapRegistry.NAMED do
		table.insert(ids, name)
	end
	table.sort(ids)
	table.insert(ids, "normandy")
	for _, name in ids do
		local id = "map:" .. name
		local layers = MapRegistry.load(id)
		local named = MapRegistry.NAMED[name]
		table.insert(lobbyMaps, { id = id, name = if named then named.name else "Normandy", starts = #layers.starts })
	end
	lobby = Lobby.new(lobbyMaps, Config.seats)
end

local function startMatch()
	brains = {}
	if lobby then
		if lobby.phase == "playing" then
			sim = Sim.new(Lobby.config(lobby, seed))
			brains = Skirmish.forMatch(sim)
			matchStartTick = sim.tick
			series = StatSeries.new(sim.tick)
			recorders, recordedBytes = {}, 0
			for _, id in Lobby.humans(lobby) do
				local header = { protocol = Schema.PROTOCOL_VERSION, defsHash = sim.defs.hash, mapId = sim.mapId, viewer = id, players = {} }
				for _, pid in sim.playerOrder do
					local p = sim.players[pid]
					table.insert(header.players, { id = pid, team = p.team, allyTeam = p.allyTeam })
				end
				recorders[id] = PlayerReplay.new(header, sim.tick + 1)
			end
		else
			-- the lobby's preview: the chosen map, nobody on it; a sim player
			-- for every seat, so any seated human can join it
			local preview = {}
			for i = 1, PREVIEW_PLAYERS do
				table.insert(preview, { id = i, team = i })
			end
			sim = Sim.new({ seed = seed, players = preview, mapId = lobby.mapId, scenario = "empty", defs = defs })
		end
	else
		sim = Sim.new({ seed = seed, players = Config.players, mapId = Config.mapId, scenario = Config.scenario, defs = defs })
	end
	-- the profile's extra units (MatchConfig `spawns`), optionally tougher for tests
	for _, s in Config.spawns or {} do
		local ids = {}
		local cols = s.cols or s.count or 1 -- a formation: rows of `cols` units, each row `rowDx`, `rowDz` from the last
		for i = 0, (s.count or 1) - 1 do
			local col, row = i % cols, i // cols
			local x = s.x + col * (s.dx or 0) + row * (s.rowDx or 0)
			local z = s.z + col * (s.dz or 0) + row * (s.rowDz or 0)
			local id = Spawn.unit(sim, s.def, s.player, x, z, s.heading or 0)
			if s.health then
				SimWorld.setHealth(sim.world, id, sim.world.health[id] * s.health)
			end
			table.insert(ids, id)
		end
		if s.moveTo then
			local cell, offX, offZ = sim.map.layers.grid:encode(s.moveTo[1], s.moveTo[2])
			Sim.submit(sim, s.player, encode({ cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = offX, offZ = offZ }))
		end
		if s.fireAt then
			local cell, offX, offZ = sim.map.layers.grid:encode(s.fireAt[1], s.fireAt[2])
			Sim.submit(sim, s.player, encode({ cmdType = Schema.CmdType.ATTACK_GROUND, flags = 0, unitIds = ids, cell = cell, offX = offX, offZ = offZ }))
		end
	end
	-- the profile's starting stores (tests: a strong economy from the start)
	local start = Config.startResources
	if start then
		for _ = 1, 5 do
			Sim.step(sim) -- the economy (every 5th tick) counts the spawned depots' storage
		end
		for _, acc in sim.eco.accounts do
			acc.supply.stored = math.min(start.supply or acc.supply.stored, acc.supply.storage)
			acc.power.stored = math.min(start.power or acc.power.stored, acc.power.storage)
		end
	end
	matchId += 1
	endedAt = nil
	-- a new match is a fresh view for everyone connected: WELCOME again
	for player, ok in joined do
		if ok and slotOf[player] then
			NetOut.join(sim, slotOf[player], true)
		elseif ok and specOf[player] then
			specOf[player] = NetOut.addSpectator(sim)
		end
	end
	if Config.demoOrders then
		demoOrders()
	end
	if lobby then
		print(`[Entry] {if lobby.phase == "playing" then "match" else "lobby preview"} {matchId}: {lobby.mapId}, {lobby.mode}, {#brains} AI, seed {seed}`)
		publishLobby()
	else
		print(`[Entry] match {matchId}: {Config.scenario} on {Config.mapId}, seed {seed}`)
	end
end

-- Seats move when a match starts (open slots drop out) or the host leaves:
-- every seated human's sim player follows their slot.
local function reseat()
	for player in slotOf do
		local i = Lobby.slotOf(lobby, player.UserId)
		if i and i ~= slotOf[player] then
			slotOf[player] = i
			if joined[player] then
				NetOut.join(sim, i, true) -- a fresh view as the seat's player
			end
		end
	end
end

lobbyRemote.OnServerEvent:Connect(function(player: Player, msg: any)
	if lobby == nil or slotOf[player] == nil then
		return
	end
	local before = lobby.mapId
	local action, err = Lobby.apply(lobby, lobbyMaps, msg, slotOf[player])
	if err then
		print(`[Entry] lobby ({player.Name}): {err}`)
	end
	if action == "start" then
		reseat()
		seed += 1
		startMatch()
	elseif action == "lobby" or lobby.mapId ~= before then
		startMatch() -- the preview, on the (new) map
	else
		publishLobby()
	end
end)

local function assignSlot(player: Player)
	if lobby then
		local i = Lobby.seat(lobby, player.UserId, player.DisplayName)
		if i then
			slotOf[player] = i
			tokens[player] = 40
			print(`[Entry] {player.Name} takes seat {i}`)
		else
			specOf[player] = 0
			print(`[Entry] {player.Name}: no free seat, watches as a spectator`)
		end
		publishLobby()
		return
	end
	local taken: { [number]: boolean } = {}
	for _, id in slotOf do
		taken[id] = true
	end
	for _, id in Config.humanSlots do
		if not taken[id] then
			slotOf[player] = id
			tokens[player] = 40
			local team = 0
			for _, p in Config.players do
				if p.id == id then
					team = p.team
				end
			end
			print(`[Entry] {player.Name} plays sim player {id} (team {team})`)
			return
		end
	end
	specOf[player] = 0
	print(`[Entry] {player.Name}: no free slot, watches as a spectator`)
end

Players.PlayerAdded:Connect(assignSlot)
for _, player in Players:GetPlayers() do
	assignSlot(player)
end
Players.PlayerRemoving:Connect(function(player)
	slotOf[player] = nil
	specOf[player] = nil -- its viewer stays in the sim until the next match (NetOut has no removal)
	joined[player] = nil
	tokens[player] = nil
	if lobby then
		Lobby.leave(lobby, player.UserId) -- in a match the seat stays theirs to rejoin
		reseat()
		publishLobby()
	end
end)

remoteOf.Snapshot.OnServerEvent:Connect(function(player: Player, payload: any)
	local id = slotOf[player]
	if (id == nil and specOf[player] == nil) or typeof(payload) ~= "buffer" or buffer.len(payload) > 64 then
		return
	end
	local ok, reject = pcall(NetOut.hello, sim, payload)
	if not ok then
		return -- not a HELLO
	end
	if reject then
		remoteOf.Snapshot:FireClient(player, reject)
		print(`[Entry] {player.Name}: stale client, rejected`)
		return
	end
	joined[player] = true
	if id == nil then
		specOf[player] = NetOut.addSpectator(sim) -- a fresh viewer: its first outbox opens with a WELCOME
		print(`[Entry] {player.Name} joined as a spectator`)
		return
	end
	NetOut.join(sim, id) -- a reconnect keeps the camera
	print(`[Entry] {player.Name} joined as sim player {id}`)
end)

remoteOf.Cmd.OnServerEvent:Connect(function(player: Player, payload: any)
	local id = slotOf[player]
	if id == nil or not joined[player] or typeof(payload) ~= "buffer" or buffer.len(payload) > CMD_MAX_BYTES then
		return
	end
	if (tokens[player] or 0) < 1 then
		return -- rate limited
	end
	tokens[player] -= 1
	Sim.submit(sim, id, payload)
end)

-- The results screen's replays (C-79): "save" keeps the player's recording
-- of the match for this server session (and, on a live server, a DataStore
-- copy), "watch" sends a recording to the
-- client in chunks, "list" names the saved ones.
--   client → server: { op = "save" } | { op = "watch", index? } | { op = "list" }
--   server → client: { op = "saved", name, bytes, datastore = string? } |
--                    { op = "list", names } | { op = "chunk", index, count, data }
local CHUNK_BYTES = 200 * 1024
local replayRemote = Instance.new("RemoteEvent")
replayRemote.Name = "Replay"
replayRemote.Parent = remotes
local function namesOf(list: { any }): { string }
	local out = {}
	for _, r in list do
		table.insert(out, r.name)
	end
	return out
end
replayRemote.OnServerEvent:Connect(function(player: Player, msg: any)
	if type(msg) ~= "table" then
		return
	end
	local mine = savedReplays[player.UserId] or {}
	savedReplays[player.UserId] = mine
	local current = slotOf[player] and recorders[slotOf[player]]
	if msg.op == "save" and current then
		local file = PlayerReplay.serialize(current)
		local name = string.format("Match %d · %s · %d:%02d", matchId, sim.mapId, math.floor((current.lastTick - current.firstTick + 1) / 15 / 60), math.floor((current.lastTick - current.firstTick + 1) / 15) % 60)
		table.insert(mine, { name = name, file = file })
		replayRemote:FireClient(player, { op = "saved", name = name, bytes = buffer.len(file) })
		-- the DataStore copy only in a live server: Studio refuses it without API
		-- access and logs an error even under pcall
		if RunService:IsStudio() then
			return
		end
		task.spawn(function()
			local ok, err = pcall(function()
				local store = game:GetService("DataStoreService"):GetDataStore("FtggReplays")
				store:SetAsync(`{player.UserId}/{matchId}`, file)
			end)
			replayRemote:FireClient(player, { op = "saved", name = name, bytes = buffer.len(file), datastore = if ok then "saved" else tostring(err) })
			print(`[Entry] replay {name} for {player.Name}: {buffer.len(file)} bytes, DataStore {if ok then "saved" else tostring(err)}`)
		end)
	elseif msg.op == "list" then
		replayRemote:FireClient(player, { op = "list", names = namesOf(mine) })
	elseif msg.op == "watch" then
		local file: buffer?
		if type(msg.index) == "number" and mine[msg.index] then
			file = mine[msg.index].file
		elseif current then
			file = PlayerReplay.serialize(current)
		end
		if file == nil then
			return
		end
		local count = math.max(1, math.ceil(buffer.len(file) / CHUNK_BYTES))
		for i = 1, count do
			local from = (i - 1) * CHUNK_BYTES
			local n = math.min(CHUNK_BYTES, buffer.len(file) - from)
			local part = buffer.create(n)
			buffer.copy(part, 0, file, from, n)
			replayRemote:FireClient(player, { op = "chunk", index = i, count = count, data = part })
		end
	end
end)

local function send()
	local viewers: { [Player]: any } = {}
	for player, id in slotOf do
		viewers[player] = sim.net.players[id]
	end
	for player, index in specOf do
		viewers[player] = sim.net.spectators[index]
	end
	for player, pn in viewers do
		if pn and joined[player] then
			for _, ch in SEND_ORDER do
				local remote = remoteOf[ch]
				for _, msg in pn.outbox[ch] do
					remote:FireClient(player, msg)
				end
			end
		end
	end
end

local function sidesLeft(): number
	local teams: { [number]: boolean } = {}
	local n = 0
	for _, id in sim.world.ids do
		local team = sim.players[sim.world.owner[id]].team
		if not teams[team] then
			teams[team] = true
			n += 1
		end
	end
	return n
end

startMatch()

-- Studio inspection through execute_luau (its VM doesn't share `shared`):
-- game.ServerStorage.FtggDebug:Invoke() returns a summary of the live sim;
-- Invoke("damage", unitId, amount) queues damage through the sim's own
-- damage step (as a hit with no attacker), for testing what the client shows;
-- Invoke("spawn", defId, playerId, x, z, heading, count?, spacing?) adds
-- units in a row along x (the sim's own Spawn), for playtests of what the
-- client draws; Invoke("build", builderId, defId, x, z) orders a builder to
-- construct there (the sim's own build command), for what an unfinished
-- unit looks like.
if RunService:IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "FtggDebug"
	debugFn.OnInvoke = function(query: string?, ...: any)
		if query == "damage" then
			local id, amount = ...
			Combat.queueDamage(sim.combat, id, amount, 0)
			return true
		elseif query == "spawn" then
			local defId, playerId, x, z, heading, count, spacing = ...
			local ids = {}
			for i = 0, (count or 1) - 1 do
				table.insert(ids, Spawn.unit(sim, defId, playerId, x + i * (spacing or 12), z, heading or 0))
			end
			return ids
		elseif query == "results" then
			-- ends a lobby match now and shows the results (the statistics panel, C-105)
			if lobby and lobby.phase == "playing" then
				finishMatch()
				return true
			end
			return false
		elseif query == "build" then
			local builder, defId, x, z = ...
			Build.commandBuild(sim, { builder }, sim.defs.units[defId].index, x, z, 0)
			return true
		end
		local byOwner: { [number]: number } = {}
		for _, id in sim.world.ids do
			local owner = sim.world.owner[id]
			byOwner[owner] = (byOwner[owner] or 0) + 1
		end
		local players = {}
		for pid, pn in sim.net.players do
			players[pid] = { camera = pn.camera, tactical = #pn.tacticalList, bytes = table.clone(pn.bytes) }
		end
		return { tick = sim.tick, matchId = matchId, unitsByOwner = byOwner, players = players }
	end
	debugFn.Parent = game:GetService("ServerStorage")
end

local acc = 0
local stepTime, peak, steps = 0, 0, 0
local reportAt = os.clock() + 10

RunService.Heartbeat:Connect(function(dt: number)
	for player, t in tokens do
		tokens[player] = math.min(40, t + dt * CMD_RATE)
	end
	acc += dt * speed
	local n = 0
	while acc >= DT and n < MAX_STEPS_PER_FRAME do
		local t0 = os.clock()
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if lobby and lobby.phase == "playing" then
			if recordedBytes < MAX_RECORDED_BYTES then
				for id, rep in recorders do
					local outbox = sim.net.players[id].outbox
					PlayerReplay.record(rep, sim.tick, outbox)
					for _, list in outbox do
						for _, msg in list do
							recordedBytes += buffer.len(msg)
						end
					end
				end
			end
		end
		-- the end for the humans: the match is over, or they are all out (the
		-- AI may fight on in a free-for-all; the results don't wait for it)
		if lobby and lobby.phase == "playing" and series and StatSeries.due(series, sim.tick) then
			StatSeries.sample(series, sim, Stats.report(sim))
		end
		if lobby and lobby.phase == "playing" and Lobby.done(lobby, sim) then
			finishMatch()
		end
		if Config.demoOrders and sim.tick % DEMO_EVERY == 0 then
			demoOrders()
		end
		local ms = (os.clock() - t0) * 1000
		stepTime += ms
		peak = math.max(peak, ms)
		steps += 1
		send()
		acc -= DT
		n += 1
	end
	if n == MAX_STEPS_PER_FRAME then
		acc = math.min(acc, DT) -- don't spiral after a hitch
	end

	if os.clock() >= reportAt then
		print(string.format("[Entry] %d ticks: sim step avg %.2f ms, peak %.2f ms; %d units", steps, stepTime / math.max(steps, 1), peak, #sim.world.ids))
		stepTime, peak, steps = 0, 0, 0
		reportAt = os.clock() + 10
	end

	if Config.restartAfter and sidesLeft() <= 1 then
		endedAt = endedAt or os.clock()
		if os.clock() - (endedAt :: number) >= Config.restartAfter then
			seed += 1
			startMatch()
		end
	end
end)

remotes.Parent = ReplicatedStorage

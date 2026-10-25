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
--
-- Match role (C-173, docs/contracts/match.md v1, the lobby stream's L-4):
-- a reserved server of this place runs the one match the lobby place stored
-- for it (MemoryStore `FtggMatch`: server/<PrivateServerId> → config/<id>).
-- It admits only the listed users (players into their seats, spectators to
-- watch), holds the sim at its first tick while everyone loads (up to 90 s
-- after the first arrives), keeps alive/<id> fresh, writes result/<id>, and
-- teleports everyone back to their lobby server. The Studio profile
-- `contract` runs the same path from an in-memory stand-in store.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- full paths, so check_build can resolve them
local Sim = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Sim")) :: any
local NetOut = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("NetOut")) :: any
local Defs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Defs"):WaitForChild("Defs")) :: any
local Packer = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Packer")) :: any
local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Schema")) :: any
local CheatText = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("CheatText")) :: any
local PlayerReplay = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("PlayerReplay")) :: any
local Config = require(script.Parent:WaitForChild("MatchConfig")) :: any
local Combat = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Combat"):WaitForChild("Combat")) :: any
local Spawn = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Spawn")) :: any
local Layers = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Grid"):WaitForChild("Layers")) :: any
local SimWorld = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("World")) :: any
local Skirmish = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("AI"):WaitForChild("Skirmish")) :: any
local MapRegistry = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Grid"):WaitForChild("MapRegistry")) :: any
local Lobby = require(script.Parent:WaitForChild("Lobby")) :: any
local Stats = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Stats")) :: any
local CheatConfig = require(script.Parent:WaitForChild("CheatConfig")) :: any
local Build = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Build")) :: any
local MatchContract = require(script.Parent:WaitForChild("MatchContract")) :: any
local Watchdog = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Watchdog")) :: any
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
local cheatSpeed: number? = nil -- the last /speed the sim took (S-102; it never reads it itself)
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
local dog: any -- the per-tick budget watchdog of the current sim (S-140, C-171)
local brains: { any } = {} -- the skirmish AI's players in a lobby match (C-70)
local PREVIEW_PLAYERS = 8 -- the lobby preview has a sim player for every seat a human may take
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
-- the match role (C-173), set up after the lobby below; declared here for finishMatch
local contract: any = nil -- the validated match config
local contractRaw: any = nil -- what the store held, for a refusal's return trip
local resultWritten = false
local storeSet: (string, any, number) -> ()
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
	lobby.results = Lobby.results(lobby, sim, sim.match.startTick, Stats.report(sim))
	lobby.results.series = Stats.series(sim) -- samples over time, kept by the sim (S-88, request 41)
	lobby.results.replays = next(recorders) ~= nil
	brains = {}
	print(`[Entry] match over for the humans: {if sim.match.over then `ally team {sim.match.winner} won` else "all out"}`)
	if contract and not resultWritten then
		-- the results record (contract section 5), then everyone goes back after RETURN_SECONDS
		local present = 0
		for player, seat in slotOf do
			if typeof(seat) == "number" and player.Parent then
				present += 1
			end
		end
		local outcome, winner, reason = MatchContract.outcomeOf(sim, present)
		local record = MatchContract.result(contract, outcome, sim, Stats.report(sim), sim.match.startTick, os.time(), reason, winner)
		storeSet("result/" .. contract.matchId, record, MatchContract.RESULT_TTL)
		resultWritten = true
		lobby.returnAt = workspace:GetServerTimeNow() + MatchContract.RETURN_SECONDS
		print(`[Match] result: {record.outcome}{if record.winner then `, ally team {record.winner} won` else ""}{if record.reason then ` ({record.reason})` else ""}, {present} humans present; writing result/{contract.matchId}`)
	end
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
	-- then the hand-made maps (Normandy, The Canyon: S-53, S-132)
	local handmade = {}
	for name in MapRegistry.HANDMADE do
		table.insert(handmade, name)
	end
	table.sort(handmade)
	table.move(handmade, 1, #handmade, #ids + 1, ids)
	for _, name in ids do
		local id = "map:" .. name
		local layers = MapRegistry.load(id)
		local entry = MapRegistry.NAMED[name] or MapRegistry.HANDMADE[name]
		table.insert(lobbyMaps, { id = id, name = entry.name, starts = #layers.starts })
	end
	lobby = Lobby.new(lobbyMaps, Config.seats)
end

-- The match role (C-173): a reserved server (not a VIP server, which has an
-- owner) or the Studio `contract` profile. Its store is the MemoryStore
-- HashMap, or an in-memory stand-in in Studio.
local matchServer = (game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0) or Config.contract ~= nil
local hashMap: any = nil
local standIn: { [string]: any } = {}
local function storeGet(key: string): any
	if hashMap == nil then
		return standIn[key]
	end
	for attempt = 1, 3 do
		local ok, v = pcall(hashMap.GetAsync, hashMap, key)
		if ok then
			return v
		end
		warn(`[Match] store read {key} (attempt {attempt}/3): {v}`)
		task.wait(attempt)
	end
	warn(`[Match] store read {key} FAILED after 3 attempts`)
	return nil
end
-- `quiet` skips the success line (the heartbeat prints its own)
storeSet = function(key: string, value: any, ttl: number, quiet: boolean?)
	if hashMap == nil then
		standIn[key] = value
		if not quiet then
			print(`[Match] stored {key} (Studio stand-in)`)
		end
		return
	end
	task.spawn(function()
		for attempt = 1, 3 do
			local ok, err = pcall(hashMap.SetAsync, hashMap, key, value, ttl)
			if ok then
				if not quiet or attempt > 1 then
					print(`[Match] stored {key}{if attempt > 1 then ` (attempt {attempt})` else ""}`)
				end
				return
			end
			warn(`[Match] store write {key} (attempt {attempt}/3): {err}`)
			task.wait(attempt)
		end
		warn(`[Match] store write {key} FAILED after 3 attempts`)
	end)
end
local matchArrived: { [number]: boolean } = {} -- listed humans whose clients finished loading
local firstArrival: number? = nil
if matchServer then
	local serverKey = game.PrivateServerId
	if Config.contract then
		serverKey = "studio"
		standIn["server/studio"] = Config.contract.matchId
		standIn["config/" .. Config.contract.matchId] = Config.contract
	else
		hashMap = game:GetService("MemoryStoreService"):GetHashMap(MatchContract.MAP)
	end
	print(`[Match] match server up (job {game.JobId}); reading server/{serverKey}`)
	local matchId: any = nil
	local tries = 0
	for _ = 1, 10 do -- the lobby writes the keys before it teleports; allow for store lag
		tries += 1
		matchId = storeGet("server/" .. serverKey)
		if matchId then
			break
		end
		task.wait(1)
	end
	if type(matchId) == "string" then
		print(`[Match] server/{serverKey} → match {matchId} (read {tries}); reading config/{matchId}`)
		contractRaw = storeGet("config/" .. matchId)
	else
		warn(`[Match] server/{serverKey}: no match id after {tries} reads`)
	end
	local why = if contractRaw == nil then "no match config for this server" else MatchContract.validate(contractRaw)
	if why then
		warn(`[Match] config refused: {why}`)
		if type(contractRaw) == "table" and type(contractRaw.matchId) == "string" and type(contractRaw.players) == "table" then
			storeSet("result/" .. contractRaw.matchId, MatchContract.result(contractRaw, "abandoned", nil, nil, 0, os.time(), why), MatchContract.RESULT_TTL)
			resultWritten = true
		end
	else
		contract = contractRaw
		lobby = MatchContract.toLobby(contract)
		lobby.phase = "waiting" -- everyone loads first; the sim holds at its first tick
		print(`[Match] config read: {contract.matchId}: {contract.mapId} {contract.mode}, {#contract.players} players, {#contract.spectators} spectators, from room "{contract.lobby.roomName}" (lobby place {contract.lobby.placeId}, server {contract.lobby.jobId})`)
		for i, p in contract.players do
			print(`[Match]   seat {i}: {p.name} ({if p.user then `user {p.user}` else `AI {p.ai}`}), {p.faction}, ally team {p.allyTeam}`)
		end
		for _, s in contract.spectators do
			print(`[Match]   spectator: {s.name} (user {s.user})`)
		end
		-- the heartbeat the lobby polls (contract section 6)
		task.spawn(function()
			local beat = 0
			while not resultWritten do
				beat += 1
				storeSet("alive/" .. contract.matchId, { at = os.time(), players = #Players:GetPlayers() }, MatchContract.HEARTBEAT_TTL, true)
				print(`[Match] heartbeat {beat}: {lobby.phase}, tick {if sim then sim.tick else 0}, {#Players:GetPlayers()} connected`)
				task.wait(MatchContract.HEARTBEAT_EVERY)
			end
			print(`[Match] heartbeat stopped after {beat} (result written)`)
		end)
	end
end

-- Back to the lobby place (contract section 6): the lobby server the room
-- lives on, else any (it rebuilds the room from the store). In Studio it
-- only says so.
local TeleportService = game:GetService("TeleportService")
local function sendBack(list: { Player })
	local c = contract or contractRaw
	if #list == 0 then
		return
	end
	if type(c) ~= "table" or type(c.lobby) ~= "table" then
		for _, p in list do
			warn(`[Match] {p.Name}: no lobby to return to (no readable config): kicked`)
			p:Kick("This match couldn't start. Rejoin the game to return to the lobby.")
		end
		return
	end
	local names = {}
	for _, p in list do
		table.insert(names, p.Name)
	end
	if Config.contract or RunService:IsStudio() then
		for _, p in list do
			print(`[Match] (Studio) would teleport {p.Name} back to lobby place {c.lobby.placeId}, server {c.lobby.jobId}`)
		end
		return
	end
	local function attempt(toServer: boolean): boolean
		local options = Instance.new("TeleportOptions")
		if toServer then
			options.ServerInstanceId = c.lobby.jobId
		end
		options:SetTeleportData({ matchId = c.matchId })
		local target = if toServer then `the room's server {c.lobby.jobId}` else "any lobby server"
		print(`[Match] teleport back: {table.concat(names, ", ")} → place {c.lobby.placeId}, {target}`)
		local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, c.lobby.placeId, list, options)
		if ok then
			print(`[Match] teleport back started for {table.concat(names, ", ")}`)
		else
			warn(`[Match] teleport back to {target} failed: {err}`)
		end
		return ok
	end
	if not attempt(true) then
		attempt(false)
	end
end
TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
	local c = contract or contractRaw
	if type(c) ~= "table" or type(c.lobby) ~= "table" then
		return
	end
	warn(`[Match] {player.Name}'s return failed ({result.Name}: {message}); retrying to any lobby server`)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ matchId = c.matchId })
	local ok, err = pcall(TeleportService.TeleportAsync, TeleportService, c.lobby.placeId, { player }, options)
	if ok then
		print(`[Match] retry teleport started for {player.Name}`)
	else
		warn(`[Match] retry teleport for {player.Name} failed: {err}`)
	end
end)

local function startMatch()
	brains = {}
	if contract then
		-- the lobby's match (C-173): built once at boot, held while everyone loads
		sim = Sim.new(MatchContract.toSim(contract))
		brains = Skirmish.forMatch(sim)
		recorders, recordedBytes = {}, 0
		for _, id in Lobby.humans(lobby) do
			local header = { protocol = Schema.PROTOCOL_VERSION, defsHash = sim.defs.hash, mapId = sim.mapId, viewer = id, players = {} }
			for _, pid in sim.playerOrder do
				local p = sim.players[pid]
				table.insert(header.players, { id = pid, team = p.team, allyTeam = p.allyTeam })
			end
			recorders[id] = PlayerReplay.new(header, sim.tick + 1)
		end
	elseif lobby then
		if lobby.phase == "playing" then
			local config = Lobby.config(lobby, seed)
			-- cheats: the host's lobby toggle, or always in Studio (C-119)
			config.match.cheats = config.match.cheats or RunService:IsStudio()
			-- a profile's `startMode = "choose"` gives the in-match lobby the pre-game (C-218)
			config.match.startMode = Config.startMode
			sim = Sim.new(config)
			brains = Skirmish.forMatch(sim)
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
		-- test profiles: cheats in Studio, and "speed" (the sim's offline option), C-119;
		-- `match` gives a profile match rules and AI players (the watchdog run, C-204)
		sim = Sim.new({ seed = seed, players = Config.players, mapId = Config.mapId, scenario = Config.scenario, defs = defs, cheats = RunService:IsStudio(), offline = RunService:IsStudio(), match = Config.match })
		if Config.match then
			brains = Skirmish.forMatch(sim)
		end
		-- `startCheats`: { player, text } cheat lines (CheatText) the profile sends at the start
		for _, c in Config.startCheats or {} do
			local cmd, err = CheatText.parse(c[2], defs)
			if cmd then
				Sim.submit(sim, c[1], encode(cmd))
			else
				warn(`[Entry] startCheats "{c[2]}": {err}`)
			end
		end
	end
	-- every sim player's team, ally team and name, for the client's colours
	-- (Shared/Match/TeamColors.forViewer, S-172) and the pre-game's list (C-217)
	local players = {}
	for _, pid in sim.playerOrder do
		local p = sim.players[pid]
		local seat = contract and contract.players[pid]
		table.insert(players, { id = pid, team = p.team, allyTeam = p.allyTeam, name = seat and seat.name })
	end
	remotes:SetAttribute("Players", HttpService:JSONEncode(players))
	-- the profile's speed until a /speed: the sim's own default (1) isn't a request (C-204)
	speed = Config.speed or 1
	cheatSpeed = sim.cheats and sim.cheats.speed
	remotes:SetAttribute("SimSpeed", speed)
	-- warns when a live tick runs over guide 18.1's budget, and sums up each minute (S-140)
	dog = Watchdog.new(sim)
	-- the profile's extra units (MatchConfig `spawns`), optionally tougher for tests
	for _, s in (if contract then {} else Config.spawns) or {} do
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
	local start = if contract then nil else Config.startResources
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
	if Config.demoOrders and not contract then
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
	if contract then
		-- the lobby's match (C-173): loading progress and Return to lobby only
		if type(msg) ~= "table" then
			return
		end
		local seat = slotOf[player]
		if msg.op == "loaded" and lobby.phase == "waiting" and typeof(seat) == "number" and type(msg.progress) == "number" then
			local loading = lobby.loading or {}
			lobby.loading = loading
			loading[tostring(seat)] = math.clamp(msg.progress, 0, 1)
			if msg.progress >= 1 and not matchArrived[seat] then
				matchArrived[seat] = true
				firstArrival = firstArrival or workspace:GetServerTimeNow()
				print(`[Match] {player.Name} loaded`)
			end
			publishLobby()
		elseif msg.op == "return" and lobby.phase == "results" then
			print(`[Match] {player.Name} pressed Return to lobby`)
			sendBack({ player })
		end
		return
	end
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
	if matchServer then
		-- the lobby's list decides (contract section 6): seats, spectators, or out
		if contract == nil then
			warn(`[Match] refused {player.Name} (user {player.UserId}): this server has no valid match config; sending back`)
			task.defer(sendBack, { player }) -- a refused match: everyone goes back
			return
		end
		local seat = MatchContract.seatOf(contract, player.UserId)
		if seat == nil and Config.contractAdmitAny then
			-- Studio: the playtester plays the first human seat nobody holds
			for i, p in contract.players do
				local held = false
				for _, s in slotOf do
					held = held or s == i
				end
				if p.user and not held then
					seat = i
					break
				end
			end
		end
		if typeof(seat) == "number" then
			slotOf[player] = seat
			tokens[player] = 40
			print(`[Match] admitted {player.Name} (user {player.UserId}) to seat {seat} ({contract.players[seat].name})`)
		elseif seat == "spectator" then
			specOf[player] = 0
			print(`[Match] admitted {player.Name} (user {player.UserId}) as a spectator`)
		else
			warn(`[Match] refused {player.Name} (user {player.UserId}): not listed, kicked`)
			player:Kick("You're not part of this match.")
			return
		end
		if resultWritten then
			print(`[Match] {player.Name} arrived after the result: sending back`)
			task.defer(sendBack, { player }) -- the match is closed: straight back
		end
		publishLobby()
		return
	end
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
	if contract then
		print(`[Match] {player.Name} (user {player.UserId}) left during {lobby.phase}`)
		-- every listed human gone before the end: no result to play for (contract section 5)
		if not resultWritten and (lobby.phase == "waiting" or lobby.phase == "playing") then
			local left = 0
			for other, seat in slotOf do
				if typeof(seat) == "number" and other ~= player then
					left += 1
				end
			end
			if left == 0 then
				storeSet("result/" .. contract.matchId, MatchContract.result(contract, "abandoned", sim, Stats.report(sim), sim.match.startTick, os.time(), "every player left"), MatchContract.RESULT_TTL)
				resultWritten = true
				print("[Match] every player left: abandoned")
			end
		end
		publishLobby()
		return
	end
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

-- Cheat commands (C-119; the sim's CHEAT, net.md 9a) reach the sim only
-- from allow-listed players (CheatConfig), in Studio or a lobby match whose
-- host turned Cheats on; the sim also rejects them unless the match allows.
local CHEAT_CMD = Schema.CmdType.CHEAT
local function mayCheat(player: Player): boolean
	if not CheatConfig.allow[player.UserId] then
		return false
	end
	return RunService:IsStudio() or (lobby ~= nil and lobby.cheats == true)
end

remoteOf.Cmd.OnServerEvent:Connect(function(player: Player, payload: any)
	local id = slotOf[player]
	if id == nil or not joined[player] or typeof(payload) ~= "buffer" or buffer.len(payload) > CMD_MAX_BYTES then
		return
	end
	if buffer.len(payload) >= 1 and buffer.readu8(payload, 0) == CHEAT_CMD and not mayCheat(player) then
		return -- not allowed to cheat: dropped before the sim (and its replay) sees it
	end
	if (tokens[player] or 0) < 1 then
		return -- rate limited
	end
	if contract and lobby.phase == "waiting" then
		return -- the lobby's match hasn't started (C-173)
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
-- Key bindings (C-159): each player's rebound keys, as Core/Keybinds.encode
-- writes them (only what differs from the defaults). "get" answers the
-- saved string; "set" stores one. A live server keeps them in the
-- FtggSettings DataStore; Studio refuses DataStores without API access, so
-- there they last for the server session.
--   client → server: InvokeServer("get") → string | InvokeServer("set", text) → boolean
local KEYBINDS_MAX = 2000 -- characters; every action rebound is ~400
local keybindsSaved: { [number]: string } = {}
local keybindsRemote = Instance.new("RemoteFunction")
keybindsRemote.Name = "Keybinds"
keybindsRemote.Parent = remotes
keybindsRemote.OnServerInvoke = function(player: Player, op: any, text: any): any
	local key = `keys/{player.UserId}`
	if op == "get" then
		local mine = keybindsSaved[player.UserId]
		if mine == nil and not RunService:IsStudio() then
			local ok, stored = pcall(function()
				return game:GetService("DataStoreService"):GetDataStore("FtggSettings"):GetAsync(key)
			end)
			mine = if ok and type(stored) == "string" then stored else ""
			keybindsSaved[player.UserId] = mine
		end
		return mine or ""
	elseif op == "set" and type(text) == "string" and #text <= KEYBINDS_MAX and string.match(text, "^[%w_=;]*$") then
		keybindsSaved[player.UserId] = text
		if not RunService:IsStudio() then
			task.spawn(function()
				local ok, err = pcall(function()
					game:GetService("DataStoreService"):GetDataStore("FtggSettings"):SetAsync(key, text)
				end)
				if not ok then
					warn(`[Entry] keybinds for {player.Name}: DataStore {err}`)
				end
			end)
		end
		return true
	end
	return false
end

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
		if sim.cheats.used then
			name ..= " · cheats used" -- the replay list says so (C-120)
		end
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
-- unit looks like; Invoke("hold", ids) sets them to hold fire, for
-- screenshots of armies side by side (C-183).
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
		elseif query == "hold" then
			for _, id in (...) :: { number } do
				if sim.world.slot[id] then
					sim.world.fireState[id] = 0 -- World.FireState.HOLD_FIRE
				end
			end
			return true
		elseif query == "matchstore" then
			-- Invoke("matchstore"): the Studio stand-in store of a lobby match (C-173)
			return HttpService:JSONEncode(standIn)
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
		elseif query == "deposits" then
			-- Invoke("deposits"): every deposit cell's center (upgrade screenshots, C-121)
			local out = {}
			local pm = sim.map :: any
			if pm then
				local g = pm.grid
				for cz = 0, g.cellsZ - 1 do
					for cx = 0, g.cellsX - 1 do
						if Layers.getSupply(pm.layers, g:index(cx, cz)) > 0 then
							local wx, wz = g:cellCenter(cx, cz)
							table.insert(out, { wx, wz })
						end
					end
				end
			end
			return out
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
	local wanted = sim.cheats and sim.cheats.speed
	if wanted ~= cheatSpeed then
		-- a new match (no /speed yet) goes back to normal speed
		speed = if wanted ~= nil then wanted elseif cheatSpeed ~= nil then 1 else speed
		cheatSpeed = wanted
		remotes:SetAttribute("SimSpeed", speed)
	end
	-- the lobby's match (C-173): it starts once every listed human has
	-- loaded, or WAIT_SECONDS after the first did; the results screen sends
	-- everyone back after RETURN_SECONDS
	local waiting = contract ~= nil and lobby.phase == "waiting"
	if waiting then
		local all = true
		for _, id in Lobby.humans(lobby) do
			all = all and matchArrived[id] == true
		end
		if all or (firstArrival and workspace:GetServerTimeNow() - firstArrival >= MatchContract.WAIT_SECONDS) then
			lobby.phase = "playing"
			waiting = false
			local missing = {}
			for _, id in Lobby.humans(lobby) do
				if not matchArrived[id] then
					table.insert(missing, contract.players[id].name)
				end
			end
			print(`[Match] start at tick {sim.tick}{if all then ": everyone loaded" else `: {MatchContract.WAIT_SECONDS} s wait over, not loaded: {table.concat(missing, ", ")}`}`)
			publishLobby()
		end
	elseif contract and lobby.phase == "results" and lobby.returnAt and workspace:GetServerTimeNow() >= lobby.returnAt then
		lobby.returnAt = nil
		print(`[Match] auto-return after {MatchContract.RETURN_SECONDS} s: {#Players:GetPlayers()} players`)
		sendBack(Players:GetPlayers())
		publishLobby()
	end
	acc += dt * speed
	local n = 0
	while acc >= DT and n < MAX_STEPS_PER_FRAME do
		local t0 = os.clock()
		if not waiting then -- the AI waits for the start too
			for _, b in brains do
				Skirmish.tick(b)
			end
		end
		Sim.step(sim)
		Watchdog.afterStep(dog)
		-- a lobby match records from its first tick, the loading wait included (C-173)
		if lobby and (lobby.phase == "playing" or (contract and lobby.phase == "waiting")) then
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

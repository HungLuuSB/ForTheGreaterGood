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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- full paths, so check_build can resolve them
local Sim = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Sim")) :: any
local NetOut = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("NetOut")) :: any
local Defs = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Defs"):WaitForChild("Defs")) :: any
local Packer = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Packer")) :: any
local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("Schema")) :: any
local Config = require(script.Parent:WaitForChild("MatchConfig")) :: any
local Combat = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Combat"):WaitForChild("Combat")) :: any
local Spawn = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("Spawn")) :: any
local SimWorld = require(game:GetService("ServerScriptService"):WaitForChild("Sim"):WaitForChild("World")) :: any

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
local defs = Defs.load()

local sim: any
local matchId = 0
local seed = Config.seed
local endedAt: number? = nil

local slotOf: { [Player]: number } = {} -- Roblox player → sim player ID
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

local function startMatch()
	sim = Sim.new({ seed = seed, players = Config.players, mapId = Config.mapId, scenario = Config.scenario, defs = defs })
	-- the profile's extra units (MatchConfig `spawns`), optionally tougher for tests
	for _, s in Config.spawns or {} do
		local ids = {}
		for i = 0, (s.count or 1) - 1 do
			local id = Spawn.unit(sim, s.def, s.player, s.x + i * (s.dx or 0), s.z + i * (s.dz or 0), s.heading or 0)
			if s.health then
				SimWorld.setHealth(sim.world, id, sim.world.health[id] * s.health)
			end
			table.insert(ids, id)
		end
		if s.moveTo then
			local cell, offX, offZ = sim.map.layers.grid:encode(s.moveTo[1], s.moveTo[2])
			Sim.submit(sim, s.player, encode({ cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = offX, offZ = offZ }))
		end
	end
	matchId += 1
	endedAt = nil
	-- a new match is a fresh view for everyone connected: WELCOME again
	for player, ok in joined do
		if ok then
			NetOut.join(sim, slotOf[player], true)
		end
	end
	if Config.demoOrders then
		demoOrders()
	end
	print(`[Entry] match {matchId}: {Config.scenario} on {Config.mapId}, seed {seed}`)
end

local function assignSlot(player: Player)
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
	print(`[Entry] {player.Name}: no free slot, nothing is sent`)
end

Players.PlayerAdded:Connect(assignSlot)
for _, player in Players:GetPlayers() do
	assignSlot(player)
end
Players.PlayerRemoving:Connect(function(player)
	slotOf[player] = nil
	joined[player] = nil
	tokens[player] = nil
end)

remoteOf.Snapshot.OnServerEvent:Connect(function(player: Player, payload: any)
	local id = slotOf[player]
	if id == nil or typeof(payload) ~= "buffer" or buffer.len(payload) > 64 then
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
	NetOut.join(sim, id) -- a reconnect keeps the camera
	joined[player] = true
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

local function send()
	for player, id in slotOf do
		local pn = sim.net.players[id]
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
-- client draws.
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
		Sim.step(sim)
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

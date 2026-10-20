--!strict
-- Client entry (guide 15): receives the server's channels into the client
-- World, draws tactical units with interpolation, runs the RTS camera and
-- sends its camera rectangle. Identity and map come from attributes until
-- the protocol 6 join handshake (C-9).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then
	game.Loaded:Wait()
end
ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer :: Player
while player:GetAttribute("SimPlayer") == nil do
	player:GetAttributeChangedSignal("SimPlayer"):Wait()
end

local Defs = require("@shared/Defs/Defs")
local MapRegistry = require("@shared/Grid/MapRegistry")
local Schema = require("@shared/Net/Schema")
local Camera = require("./Camera")
local Interp = require("./Core/Interp")
local NetIn = require("./Core/NetIn")
local World = require("./Core/World")
local Hud = require("./Debug/Hud")
local Ground = require("./Render/Ground")
local UnitRenderer = require("./Render/UnitRenderer")

local defs = Defs.load()
if remotes:GetAttribute("ProtocolVersion") ~= Schema.PROTOCOL_VERSION or remotes:GetAttribute("DefsHash") ~= defs.hash then
	warn(
		`[Client] version mismatch: server protocol {remotes:GetAttribute("ProtocolVersion")} defs {remotes:GetAttribute("DefsHash")}, `
			.. `client protocol {Schema.PROTOCOL_VERSION} defs {defs.hash}. Update the client.`
	)
	return
end

local mapId = remotes:GetAttribute("MapId") :: string
local layers = MapRegistry.load(mapId)
assert(layers, `[Client] map {mapId} has no layers`)
Ground.build(layers)

local me = {
	player = player:GetAttribute("SimPlayer") :: number,
	team = player:GetAttribute("SimTeam") :: number,
	allyTeam = player:GetAttribute("SimTeam") :: number,
}

local world = World.new(layers.grid, defs, me, layers)
local clock = Interp.newClock()
local renderer = UnitRenderer.new()
local camState = Camera.new(0, 0, 220)
Camera.bind(camState)
local hud = Hud.new()

for name, ch in Schema.Channel do
	if name == "Cmd" or name == "Eco" or name == "Snapshot" then
		continue
	end
	local remote = remotes:WaitForChild(name) :: any
	remote.OnClientEvent:Connect(function(msg: any)
		if typeof(msg) == "buffer" then
			NetIn.apply(world, name, msg, os.clock())
		end
	end)
end
local cmd = remotes:WaitForChild("Cmd") :: RemoteEvent

-- a new match on the server: start from an empty view
remotes:GetAttributeChangedSignal("MatchId"):Connect(function()
	UnitRenderer.clear(renderer)
	world = World.new(layers.grid, defs, me, layers)
	clock = Interp.newClock()
	camState.lastRect = nil -- resend the camera so the server rebuilds the tactical tier
end)

print(`[Client] sim player {me.player}, team {me.team}, map {mapId}`)

-- Studio inspection through execute_luau (its VM doesn't share `shared`):
-- game.ReplicatedStorage.FtggClientDebug:Invoke() returns a summary.
if RunService:IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "FtggClientDebug"
	debugFn.OnInvoke = function(query: string?)
		if query == "view" then
			return require("./Debug/ViewDump")(layers.grid)
		end
		local byTeam, tiers, drawn = {}, {}, 0
		for _, u in world.units do
			byTeam[u.team] = (byTeam[u.team] or 0) + 1
			tiers[u.tier] = (tiers[u.tier] or 0) + 1
		end
		for _ in renderer.drawn do
			drawn += 1
		end
		return {
			latestTick = world.latestTick,
			renderTick = clock.tick,
			strategicTick = world.strategicTick,
			unitsByTeam = byTeam,
			tiers = tiers,
			models = drawn,
			dropped = world.dropped,
			camera = { x = camState.x, z = camState.z, distance = camState.distance, rect = camState.rect },
		}
	end
	debugFn.Parent = ReplicatedStorage
end

RunService:BindToRenderStep("FtggClient", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local now = os.clock()
	local payload = Camera.update(camState, world, workspace.CurrentCamera, dt, now)
	if payload then
		cmd:FireServer(payload)
	end
	local t = Interp.advance(clock, world, now, dt)
	UnitRenderer.step(renderer, world, t, dt)
	-- consumed by combat effects later (client task 7)
	table.clear(world.died)
	table.clear(world.events)
	local drawn = 0
	for _ in renderer.drawn do
		drawn += 1
	end
	Hud.update(hud, world, t, drawn, camState.rect, now)
end)

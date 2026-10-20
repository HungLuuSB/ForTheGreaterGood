--!strict
-- Client entry (guide 15): joins with HELLO / WELCOME (net.md section 10),
-- receives the server's channels into the client World, draws tactical
-- units with interpolation, runs the RTS camera (sending its rectangle),
-- and wires mouse and keys to the client API (selection and orders).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not game:IsLoaded() then
	game.Loaded:Wait()
end
ReplicatedStorage:WaitForChild("Shared")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Defs = require("@shared/Defs/Defs")
local Schema = require("@shared/Net/Schema")
local Api = require("./Api")
local Camera = require("./Camera")
local Interp = require("./Core/Interp")
local NetIn = require("./Core/NetIn")
local World = require("./Core/World")
local Hud = require("./Debug/Hud")
local Controls = require("./Input/Controls")
local Effects = require("./Core/Effects")
local RenderEffects = require("./Render/Effects")
local Ground = require("./Render/Ground")
local Overlay = require("./Render/Overlay")
local PlacementGhost = require("./Render/PlacementGhost")
local UnitRenderer = require("./Render/UnitRenderer")

local defs = Defs.load()
local world = World.new(defs)
local clock = Interp.newClock()
local renderer = UnitRenderer.new()
local camState = Camera.new(0, 0, 220)
local cmd = remotes:WaitForChild("Cmd") :: RemoteEvent
local api = Api.new(world, function(payload: buffer)
	cmd:FireServer(payload)
end)

for name in Schema.Channel do
	if name == "Cmd" then
		continue
	end
	local remote = remotes:WaitForChild(name) :: any
	remote.OnClientEvent:Connect(function(msg: any)
		if typeof(msg) == "buffer" then
			NetIn.apply(world, name, msg, os.clock())
		end
	end)
end

Camera.bind(camState)
local controls = Controls.bind(api)
local overlay = Overlay.new()
local ghost = PlacementGhost.new()
local fx = Effects.new()
local fxRenderer = RenderEffects.new()

-- Drawn muzzle of a unit's weapon slot (tracers start there), if it has a model.
local function muzzleOf(id: number, slot: number): (number?, number?, number?)
	local model = UnitRenderer.modelOf(renderer, id)
	local u = world.units[id]
	local def = u and World.def(world, u)
	local name = def and def.weapons[slot] and def.weapons[slot].muzzle
	local att = model and name and model:FindFirstChild(name, true)
	if att and att:IsA("Attachment") then
		local p = att.WorldPosition
		return p.X, p.Y, p.Z
	end
	return nil, nil, nil
end
Overlay.bind(overlay, api, os.clock)
local hud = Hud.new()
api.changed.focus:Connect(function(p)
	camState.x, camState.z = p[1], p[2]
end)

-- Join: HELLO now; the WELCOME (or a REJECT) comes back on the Snapshot channel.
local snapshot = remotes:WaitForChild("Snapshot") :: RemoteEvent
snapshot:FireServer(NetIn.hello(defs.hash))

local seenJoins, seenMap = 0, 0
local warned = false

-- Studio inspection through execute_luau (its VM doesn't share `shared`):
-- game.ReplicatedStorage.FtggClientDebug:Invoke(query?) returns a summary.
if RunService:IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "FtggClientDebug"
	debugFn.OnInvoke = function(query: string?, ...: any)
		if query == "scene" then
			return require("./Debug/SceneDump")(world.grid)
		elseif query == "act" then
			-- Invoke("act", "smartOrder", x, z, unitId?, queue?): an API action, as the UI would call it
			local name = (...)
			local ok, why = api.actions[name](select(2, ...))
			return { ok = ok, why = why }
		end
		local byTeam, tiers, drawn = {}, {}, 0
		for _, u in world.units do
			byTeam[u.team] = (byTeam[u.team] or 0) + 1
			tiers[u.tier] = (tiers[u.tier] or 0) + 1
		end
		for _ in renderer.drawn do
			drawn += 1
		end
		local waypoints = 0
		for _, list in api.waypoints.byUnit do
			waypoints += #list
		end
		return {
			joined = world.joined,
			me = world.me,
			mapId = world.mapId,
			latestTick = world.latestTick,
			renderTick = clock.tick,
			unitsByTeam = byTeam,
			tiers = tiers,
			models = drawn,
			dropped = world.dropped,
			selection = table.clone(api.state.selection),
			groups = api.state.groups,
			waypoints = waypoints,
			economy = api.state.economy,
			camera = { x = camState.x, z = camState.z, distance = camState.distance, rect = camState.rect },
		}
	end
	debugFn.Parent = ReplicatedStorage
end

RunService:BindToRenderStep("FtggClient", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local now = os.clock()
	if world.rejected then
		if not warned then
			warned = true
			warn(`[Client] the server runs protocol {world.rejected.protocol}, defs {world.rejected.defsHash}; this client has {Schema.PROTOCOL_VERSION}, {defs.hash}. Update the client.`)
		end
		return
	end
	if not world.joined then
		return
	end
	if world.joins ~= seenJoins then
		-- a (re)join: start over from the server's full picture
		seenJoins = world.joins
		UnitRenderer.clear(renderer)
		Effects.clear(fx)
		clock = Interp.newClock()
		camState.lastRect = nil -- resend the camera so the tactical tier is rebuilt
		if world.mapVersion ~= seenMap then
			seenMap = world.mapVersion
			if world.layers then
				Ground.build(world.layers)
			end
		end
		print(`[Client] joined: sim player {world.me.player}, team {world.me.team}, map {world.mapId}`)
	end
	local payload = Camera.update(camState, world, workspace.CurrentCamera, dt, now)
	if payload then
		cmd:FireServer(payload)
	end
	api.state.camera.x, api.state.camera.z, api.state.camera.zoom = camState.x, camState.z, camState.distance
	api.state.camera.rect = camState.rect
	local t = Interp.advance(clock, world, now, dt)
	UnitRenderer.step(renderer, world, t, dt)
	Effects.update(fx, world, t, now, camState.x, camState.z, muzzleOf)
	RenderEffects.step(fxRenderer, fx, t, now)
	Api.frame(api, now)
	if api.state.placement then
		local hover = Controls.hover()
		if hover then
			api.actions.updatePlacement(hover.X, hover.Z)
		end
	end
	PlacementGhost.step(ghost, api)
	Overlay.step(overlay, api, now, controls.lineFrom, controls.lineTo)
	table.clear(world.died) -- the renderer and Effects have taken what they need
	local drawn = 0
	for _ in renderer.drawn do
		drawn += 1
	end
	local p = api.state.placement
	Hud.update(hud, world, t, drawn, camState.rect, now, #api.state.selection, if p then `{p.defId} ({if p.valid then "ok" else p.reason})` else nil)
end)

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
local Bars = require("./Core/Bars")
local Effects = require("./Core/Effects")
local Icons = require("./Core/Icons")
local IconLayer = require("./Render/IconLayer")
local MinimapUI = require("./UI/Minimap")
local ResourceBar = require("./UI/ResourceBar")
local ModelPool = require("./Render/ModelPool")
local RenderEffects = require("./Render/Effects")
local Ground = require("./Render/Ground")
local HealthBars = require("./Render/HealthBars")
local Overlay = require("./Render/Overlay")
local PlacementGhost = require("./Render/PlacementGhost")
local QueuedBuilds = require("./Render/QueuedBuilds")
local RangeOverlay = require("./Render/RangeOverlay")
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
local queued = QueuedBuilds.new()
local ranges = RangeOverlay.new()
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == RangeOverlay.TOGGLE_KEY then
		RangeOverlay.setEnabled(ranges, not ranges.enabled)
	end
end)
local fx = Effects.new()
local fxRenderer = RenderEffects.new()
local iconTable = Icons.table(defs)
local iconLayer = IconLayer.new()
local healthBars = HealthBars.new()
local strategic = false
local tiers: { [number]: string } = {}
local minimap = MinimapUI.new(api) -- placeholder UI (task 9)
local resourceBar = ResourceBar.new() -- placeholder UI (task 9)

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
-- Per-frame cost of each part of the client (guide 18.2), for Invoke("perf").
local perf: { [string]: { sum: number, n: number, max: number } } = {}
local function mark(name: string, t0: number)
	local ms = (os.clock() - t0) * 1000
	local s = perf[name]
	if s == nil then
		s = { sum = 0, n = 0, max = 0 }
		perf[name] = s
	end
	s.sum += ms
	s.n += 1
	s.max = math.max(s.max, ms)
end
local warned = false

-- Studio inspection through execute_luau (its VM doesn't share `shared`):
-- game.ReplicatedStorage.FtggClientDebug:Invoke(query?) returns a summary.
if RunService:IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "FtggClientDebug"
	debugFn.OnInvoke = function(query: string?, ...: any)
		if query == "scene" then
			return require("./Debug/SceneDump")(world.grid, if ranges.enabled then ranges.arcs else nil)
		elseif query == "fx" then
			-- combat effects diagnostics: events received, applied, drawn
			local received = {}
			for kind, n in world.eventCounts do
				received[tostring(kind)] = n
			end
			local live = 0
			for _ in fx.projectiles do
				live += 1
			end
			return { received = received, applied = fx.applied, skipped = fx.skipped, live = live, bursts = #fx.bursts, tracers = #fx.tracers, fxTick = fx.tick, renderTick = clock.tick, queued = #world.events, render = fxRenderer.stats, late = { avg = fx.late.sum / math.max(fx.late.n, 1), max = fx.late.max, n = fx.late.n }, launches = { n = fx.launches.n, fromBarrel = fx.launches.fromBarrel, avgOffset = fx.launches.sumOffset / math.max(fx.launches.fromBarrel, 1) } }
		elseif query == "ranges" then
			return { enabled = ranges.enabled, stats = ranges.stats, selected = #api.state.selection }
		elseif query == "perf" then
			-- average and worst ms per frame since the last call, per part
			local out = {}
			for name, s in perf do
				out[name] = { avg = s.sum / math.max(s.n, 1), max = s.max, frames = s.n }
			end
			table.clear(perf)
			return out
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
				MinimapUI.setMap(minimap, world.layers)
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
	local frameT0 = os.clock()
	local t = Interp.advance(clock, world, now, dt)
	local t0 = os.clock()
	UnitRenderer.step(renderer, world, t, dt, strategic)
	mark("units", t0)
	t0 = os.clock()
	Effects.update(fx, world, t, now, camState.x, camState.z, muzzleOf)
	RenderEffects.step(fxRenderer, fx, t, now)
	mark("effects", t0)
	Api.frame(api, now)
	if api.state.placement then
		local hover = Controls.hover()
		if hover then
			api.actions.updatePlacement(hover.X, hover.Z)
		end
	end
	PlacementGhost.step(ghost, api)
	QueuedBuilds.step(queued, api)
	t0 = os.clock()
	RangeOverlay.step(ranges, api, now)
	mark("ranges", t0)
	t0 = os.clock()
	Overlay.step(overlay, api, now, controls.lineFrom, controls.lineTo)
	mark("overlay", t0)
	t0 = os.clock()

	-- strategic zoom (guide 15.4): icons for everything, models hidden; icons
	-- for units without a model at any zoom
	local nowStrategic = Icons.strategic(strategic, camState.distance)
	if nowStrategic ~= strategic then
		strategic = nowStrategic
		ModelPool.setVisible(not strategic)
	end
	api.state.camera.strategic = strategic
	table.clear(tiers)
	for id, u in world.units do
		tiers[id] = u.tier
	end
	local cam = workspace.CurrentCamera
	local view = cam.ViewportSize
	local draws = Icons.draws(iconTable, world, Controls.projector(cam), view.X, view.Y, api.selection.set)
	IconLayer.step(iconLayer, draws, tiers, strategic)
	mark("icons", t0)
	t0 = os.clock()
	-- health and build bars (C-24): selected, damaged and unfinished units
	local right = cam.CFrame.RightVector
	local barDraws = if strategic then {} else Bars.draws(world, Bars.list(world, api.selection.set), Controls.projector(cam), view.X, view.Y, right.X, right.Z)
	HealthBars.step(healthBars, barDraws, not strategic)
	mark("bars", t0)
	t0 = os.clock()
	MinimapUI.step(minimap, api, now)
	ResourceBar.step(resourceBar, api, now)
	mark("ui", t0)
	mark("frame", frameT0)
	table.clear(world.died) -- the renderer and Effects have taken what they need
	local drawn = 0
	for _ in renderer.drawn do
		drawn += 1
	end
	local p = api.state.placement
	Hud.update(hud, world, t, drawn, camState.rect, now, #api.state.selection, if p then `{p.defId} ({if p.valid then "ok" else p.reason})` else nil)
end)

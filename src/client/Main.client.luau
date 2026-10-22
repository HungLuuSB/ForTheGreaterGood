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
local Normandy = require("@shared/Grid/Normandy")
local Api = require("./Api")
local Camera = require("./Camera")
local Interp = require("./Core/Interp")
local NetIn = require("./Core/NetIn")
local PieceAnim = require("./Core/PieceAnim")
local World = require("./Core/World")
local Hud = require("./Debug/Hud")
local Controls = require("./Input/Controls")
local Bars = require("./Core/Bars")
local Effects = require("./Core/Effects")
local Follow = require("./Core/Follow")
local Icons = require("./Core/Icons")
local IconLayer = require("./Render/IconLayer")
local FollowButton = require("./UI/FollowButton")
local MinimapUI = require("./UI/Minimap")
local ResourceBar = require("./UI/ResourceBar")
local ModelPool = require("./Render/ModelPool")
local RenderDeaths = require("./Render/Deaths")
local RenderEffects = require("./Render/Effects")
local Contacts = require("./Render/Contacts")
local FogOfWar = require("./Render/FogOfWar")
local Ground = require("./Render/Ground")
local HealthBars = require("./Render/HealthBars")
local Overlay = require("./Render/Overlay")
local PlacementGhost = require("./Render/PlacementGhost")
local MissileViewRender = require("./Render/MissileView")
local NukeWarning = require("./Render/NukeWarning")
local RadarRings = require("./Render/RadarRings")
local AlertFeed = require("./UI/AlertFeed")
local BuildMenuUI = require("./UI/BuildMenu")
local CommandCard = require("./UI/CommandCard")
local UnitPanel = require("./UI/UnitPanel")
local LobbyUI = require("./UI/Lobby")
local ReplayBar = require("./UI/ReplayBar")
local SettingsMenu = require("./UI/SettingsMenu")
local Crater = require("./Render/Crater")
local ReplayPlayer = require("./Core/ReplayPlayer")
local PlayerReplay = require("@shared/Net/PlayerReplay")
local AttackPreviewRender = require("./Render/AttackPreview")
local QueuedBuilds = require("./Render/QueuedBuilds")
local RangeOverlay = require("./Render/RangeOverlay")
local UnitRenderer = require("./Render/UnitRenderer")

local defs = Defs.load()
local world = World.new(defs)
local clock = Interp.newClock()
local anim = PieceAnim.new(defs.weaponByIndex)
local renderer = UnitRenderer.new(anim)
local camState = Camera.new(0, 0, 220)
local cmd = remotes:WaitForChild("Cmd") :: RemoteEvent
-- a replay playing (C-79): it feeds the world instead of the live stream,
-- and orders go nowhere
local replay: ReplayPlayer.Player? = nil
local api = Api.new(world, function(payload: buffer)
	if replay == nil then
		cmd:FireServer(payload)
	end
end)

-- bytes received per channel since the client started (Invoke("net"): bandwidth checks, C-69)
local received: { [string]: number } = {}
for name in Schema.Channel do
	if name == "Cmd" then
		continue
	end
	local remote = remotes:WaitForChild(name) :: any
	remote.OnClientEvent:Connect(function(msg: any)
		if typeof(msg) == "buffer" then
			received[name] = (received[name] or 0) + buffer.len(msg)
			if replay == nil then
				NetIn.apply(world, name, msg, os.clock())
			end
		end
	end)
end

Camera.bind(camState)
-- A hand-made map's cell features, for its drawn materials and houses (C-66).
local function mapFeature(mapId: string?): ((number, number) -> string)?
	return if mapId == "map:normandy" then Normandy.feature else nil
end

local controls = Controls.bind(api)
-- clicks select a unit by its model too, wherever it is drawn (an aircraft
-- high above its ground point, a big model's body; C-38)
local pickParams = RaycastParams.new()
pickParams.FilterType = Enum.RaycastFilterType.Include
Controls.pickModel = function(px: number, py: number): number?
	local cam = workspace.CurrentCamera
	local ray = cam:ViewportPointToRay(px, py)
	pickParams.FilterDescendantsInstances = { ModelPool.folder() }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 5000, pickParams)
	local inst: Instance? = hit and hit.Instance
	while inst and inst.Parent and inst.Parent ~= ModelPool.folder() do
		inst = inst.Parent
	end
	return if inst then UnitRenderer.unitOfModel(renderer, inst) else nil
end
local overlay = Overlay.new()
local ghost = PlacementGhost.new()
local queued = QueuedBuilds.new()
local ranges = RangeOverlay.new()
local missileView = MissileViewRender.new() -- missile sensor view (C-39), N
local nukeWarning = NukeWarning.new() -- strategic launch warnings (C-57)
local radarRings = RadarRings.new() -- own radar facilities' rings, always on top (C-63, C-64)
local attackPreview = AttackPreviewRender.new() -- attack mode's arc preview (C-58)
-- Camera follow (C-43), T or the placeholder button: the first selected
-- unit, else the homing missile drawn nearest the screen centre.
local FOLLOW_KEY = Enum.KeyCode.T
local lastVisibleFx: { { any } } = {} -- Effects.visible's list from the last frame
local function toggleFollow()
	if camState.follow then
		camState.follow = nil
		return
	end
	local cam = workspace.CurrentCamera
	local view = cam.ViewportSize
	camState.follow = Follow.pick(world, api.state.selection, lastVisibleFx, Controls.projector(cam), view.X / 2, view.Y / 2)
end
local followButton = FollowButton.new(toggleFollow)
-- Global sim speed (C-35, Studio only): - slower, = faster, P pause / resume.
-- The server publishes the speed as the Remotes folder's SimSpeed attribute.
local SPEEDS = { 0.1, 0.25, 0.5, 1, 2, 4 }
local resumeSpeed = 1
local function simSpeed(): number
	if replay then
		return if replay.paused or ReplayPlayer.done(replay) then 0 else replay.speed
	end
	return (remotes:GetAttribute("SimSpeed") :: number?) or 1
end
local function requestSpeed(value: number)
	local remote = remotes:FindFirstChild("SimSpeed")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer(value)
	end
end
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if key == RangeOverlay.TOGGLE_KEY then
		RangeOverlay.setEnabled(ranges, not ranges.enabled)
	elseif key == MissileViewRender.TOGGLE_KEY then
		MissileViewRender.setEnabled(missileView, not missileView.enabled)
	elseif key == FOLLOW_KEY then
		toggleFollow()
	elseif key == Enum.KeyCode.Minus or key == Enum.KeyCode.Equals then
		local now = if simSpeed() == 0 then resumeSpeed else simSpeed()
		local i = table.find(SPEEDS, now) or 4
		i = math.clamp(i + (if key == Enum.KeyCode.Minus then -1 else 1), 1, #SPEEDS)
		requestSpeed(SPEEDS[i])
	elseif key == Enum.KeyCode.P then
		if simSpeed() == 0 then
			requestSpeed(resumeSpeed)
		else
			resumeSpeed = simSpeed()
			requestSpeed(0)
		end
	end
end)
local fx = Effects.new()
local fxRenderer = RenderEffects.new()
local iconTable = Icons.table(defs)
local iconLayer = IconLayer.new()
local healthBars = HealthBars.new()
local fog = FogOfWar.new()
local contacts = Contacts.new()
-- enemy structures seen before (kept by Contacts) and icon sample defs: enemy defense rings (C-41)
local knownEnemy = { memory = contacts.memory.memory, sample = iconTable.sample }
local strategic = false
local tiers: { [number]: string } = {}
local minimap = MinimapUI.new(api) -- placeholder UI (task 9)
local resourceBar = ResourceBar.new() -- placeholder UI (task 9)
-- playable placeholder UI (C-68): build menu, command card, unit panel, alerts
local buildMenu = BuildMenuUI.new(api)
local commandCard = CommandCard.new(api)
local unitPanel = UnitPanel.new(api)
local alertFeed = AlertFeed.new(api)
local _lobbyUI = LobbyUI.new(remotes) -- the lobby and results screens (C-70; profiles with a lobby only)
Controls.capture = function(input: InputObject): boolean
	return BuildMenuUI.capture(buildMenu, api, input)
end
api.changed.alert:Connect(function(alert: any)
	MinimapUI.ping(minimap, world.grid, alert.x, alert.z, AlertFeed.COLOR[alert.kind] or Color3.new(1, 1, 1))
end)

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
	camState.follow = nil -- a jump (minimap, group double tap) is a manual move
end)

-- Join: HELLO now; the WELCOME (or a REJECT) comes back on the Snapshot channel.
local snapshot = remotes:WaitForChild("Snapshot") :: RemoteEvent
snapshot:FireServer(NetIn.hello(defs.hash))

-- Replays (C-79): the results screen asks the server for one (UI/Lobby);
-- it arrives in chunks on the Replay remote, plays through NetIn like the
-- live stream, and Exit rejoins the live match with a new HELLO.
local function deliverReplay(_tick: number, outbox: { [string]: { buffer } })
	NetIn.applyOutbox(world, outbox, os.clock())
end
local replayBar = ReplayBar.new({
	toggle = function()
		if replay then
			if ReplayPlayer.done(replay) then
				ReplayPlayer.seek(replay, replay.replay.firstTick, deliverReplay)
			end
			replay.paused = not replay.paused
		end
	end,
	faster = function(up: boolean)
		if replay then
			ReplayPlayer.faster(replay, up)
		end
	end,
	seek = function(fraction: number)
		if replay then
			local r = replay.replay
			ReplayPlayer.seek(replay, r.firstTick + fraction * (r.lastTick - r.firstTick), deliverReplay)
			clock = Interp.newClock() -- the render clock starts over at the new spot
		end
	end,
	exit = function()
		replay = nil
		snapshot:FireServer(NetIn.hello(defs.hash)) -- back to the live match: a fresh WELCOME
	end,
})
local _settingsMenu = SettingsMenu.new() -- O: keys, camera, graphics, UI scale (C-81); after the other screens so the scale reaches them
local replayChunks: { buffer } = {}
local replayRemote = remotes:WaitForChild("Replay") :: RemoteEvent
replayRemote.OnClientEvent:Connect(function(msg: any)
	if type(msg) ~= "table" or msg.op ~= "chunk" or typeof(msg.data) ~= "buffer" then
		return
	end
	replayChunks[msg.index] = msg.data
	if #replayChunks < msg.count then
		return
	end
	local size = 0
	for _, part in replayChunks do
		size += buffer.len(part)
	end
	local file = buffer.create(size)
	local at = 0
	for _, part in replayChunks do
		buffer.copy(file, at, part)
		at += buffer.len(part)
	end
	table.clear(replayChunks)
	local ok, rep = pcall(PlayerReplay.parse, file)
	if not ok then
		warn(`[Client] replay unreadable: {rep}`)
		return
	end
	if rep.header.protocol ~= Schema.PROTOCOL_VERSION or rep.header.defsHash ~= defs.hash then
		warn(`[Client] replay from protocol {rep.header.protocol} / defs {rep.header.defsHash}; this client plays {Schema.PROTOCOL_VERSION} / {defs.hash}`)
		return
	end
	replay = ReplayPlayer.new(rep)
	print(`[Client] replay: {rep.header.mapId}, player {rep.header.viewer}, {(rep.lastTick - rep.firstTick + 1) // 15} s`)
end)

local seenJoins, seenMap = 0, 0
local nextHover = 0 -- when the hovered unit is picked next (C-76)
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
			return { received = received, applied = fx.applied, skipped = fx.skipped, live = live, bursts = #fx.bursts, tracers = #fx.tracers, fxTick = fx.tick, renderTick = clock.tick, queued = #world.events, render = fxRenderer.stats, vfx = fxRenderer.vfx.stats, late = { avg = fx.late.sum / math.max(fx.late.n, 1), max = fx.late.max, n = fx.late.n }, launches = { n = fx.launches.n, fromBarrel = fx.launches.fromBarrel, avgOffset = fx.launches.sumOffset / math.max(fx.launches.fromBarrel, 1) } }
		elseif query == "ranges" then
			local kinds = {}
			for _, line in ranges.lines do
				kinds[line.kind] = (kinds[line.kind] or 0) + 1
			end
			return { enabled = ranges.enabled, stats = ranges.stats, selected = #api.state.selection, lines = kinds, radarRingSegments = radarRings.used }
		elseif query == "missiles" then
			-- Invoke("missiles", on?): the missile sensor view (C-39), turned on or off if `on` is given
			local on = ...
			if type(on) == "boolean" then
				MissileViewRender.setEnabled(missileView, on)
			end
			local entries = {}
			for _, e in missileView.entries do
				table.insert(entries, { id = e.id, label = e.label, locked = e.locked, target = e.targetId, distance = e.distance, tgo = e.tgo, miss = e.miss, fuse = e.fuse, hit = e.hit, path = #e.path // 3, seekerAngle = e.seekerAngle, offNose = e.offNose, inSeeker = e.inSeeker, pos = { e.x, e.y, e.z } })
			end
			local marks = {}
			for _, m in fx.marks do
				marks[m.kind] = (marks[m.kind] or 0) + 1
			end
			return { enabled = missileView.enabled, entries = entries, marks = marks, stats = missileView.stats }
		elseif query == "shield" then
			-- Invoke("shield", seconds?): the shield dome prototype (C-87) under the camera's focus
			local seconds = ...
			local focus = workspace.CurrentCamera.Focus.Position
			local ground = workspace:Raycast(focus + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0))
			local y = if ground then ground.Position.Y else focus.Y
			require("./Render/ShieldFx").demo(Vector3.new(focus.X, y, focus.Z), 60, if type(seconds) == "number" then seconds else 30)
			return { center = { focus.X, y, focus.Z } }
		elseif query == "perf" then
			-- average and worst ms per frame since the last call, per part
			local out = {}
			for name, s in perf do
				out[name] = { avg = s.sum / math.max(s.n, 1), max = s.max, frames = s.n }
			end
			table.clear(perf)
			return out
		elseif query == "follow" then
			-- Invoke("follow", "toggle" | "stop"?): camera follow (C-43); returns what it follows and the camera's focus
			local action = ...
			if action == "toggle" then
				toggleFollow()
			elseif action == "stop" then
				camState.follow = nil
			end
			local f = camState.follow
			local x, y, z
			if f then
				x, y, z = Follow.position(world, fx, lastVisibleFx, f, clock.tick)
			end
			return { kind = f and f.kind, id = f and f.id, at = x and { x, y, z }, focus = { camState.x, camState.z }, distance = camState.distance, yaw = camState.yaw }
		elseif query == "camera" then
			-- Invoke("camera", x, z, distance?, pitchDegrees?): move the RTS camera (close-ups
			-- for proof screenshots); returns the camera rectangle last computed
			local x, z, distance, pitch = ...
			if x then
				camState.x, camState.z = x, z
			end
			if distance then
				camState.distance = distance
			end
			if pitch then
				camState.pitch = math.rad(pitch)
			end
			return { rect = camState.rect, pitch = math.deg(camState.pitch), distance = camState.distance }
		elseif query == "net" then
			-- Invoke("net"): bytes received per channel since the client started (C-69)
			return received
		elseif query == "fog" then
			-- fog of war: mode, plates, lights (made / lit), last rebuild; contacts and ghosts
			-- the server's ally-team sight (C-65): records applied, cells seen
			local sight = world.sight
			local seenCells = 0
			if sight then
				for i = 0, sight.width * sight.depth - 1 do
					seenCells += buffer.readu8(sight.cells, i)
				end
			end
			return { mode = fog.mode, stats = fog.stats, contacts = contacts.stats, version = fog.vision and fog.vision.version, sightVersion = sight and sight.version, seenCells = seenCells, wrecks = renderer.deaths.stats.wrecks }
		elseif query == "deaths" then
			-- deaths played (shakes, flings), wrecks standing
			return renderer.deaths.stats
		elseif query == "anim" then
			-- piece scripts: units by LOD, live threads and moving tracks, hooks run
			local lods = { near = 0, mid = 0, far = 0 }
			for _, u in anim.units do
				lods[u.lod] += 1
			end
			return { lods = lods, stats = anim.stats }
		elseif query == "ground" then
			-- Invoke("ground", "terrain" | "parts"?): rebuild the ground that way; Invoke("ground") the last build's stats
			local mode = ...
			if mode and world.layers then
				Ground.build(world.layers, mode, mapFeature(world.mapId))
			end
			return Ground.last
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
	if replay then
		ReplayPlayer.advance(replay, dt, deliverReplay)
	end
	_lobbyUI.gui.Enabled = replay == nil
	ReplayBar.step(replayBar, replay, if replay then `REPLAY: player {replay.replay.header.viewer}'s view` elseif world.joined and world.me.player == 0 then "SPECTATING: every player, no fog" else nil)
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
		Crater.clear() -- the last match's nuke craters (C-82)
		clock = Interp.newClock()
		camState.lastRect = nil -- resend the camera so the tactical tier is rebuilt
		if world.mapVersion ~= seenMap then
			seenMap = world.mapVersion
			if world.layers then
				Ground.build(world.layers, nil, mapFeature(world.mapId))
				MinimapUI.setMap(minimap, world.layers)
				FogOfWar.setMap(fog, world.layers)
			end
		end
		print(`[Client] joined: sim player {world.me.player}, team {world.me.team}, map {world.mapId}`)
	end
	if Camera.input(camState, workspace.CurrentCamera, dt) then
		camState.follow = nil -- a manual pan stops a follow (zooming doesn't)
	end
	local frameT0 = os.clock()
	-- sim time this frame: units, shells, piece scripts and banking slow down
	-- or pause with the sim; camera and UI stay in real time (C-35)
	local speed = simSpeed()
	local simDt = dt * speed
	local t = Interp.advance(clock, world, now, dt, speed)
	World.settle(world, t) -- health bars show changes with the hits that caused them (C-49)
	local t0 = os.clock()
	UnitRenderer.step(renderer, world, t, simDt, strategic, workspace.CurrentCamera.CFrame.Position, speed)
	mark("units", t0)
	t0 = os.clock()
	Effects.update(fx, world, t, now, camState.x, camState.z, muzzleOf)
	local visibleFx = RenderEffects.step(fxRenderer, fx, t, now, speed)
	lastVisibleFx = visibleFx
	mark("effects", t0)
	-- the camera goes on after units and missiles have their drawn positions
	-- this frame, so a followed one sits still in the middle of the screen
	local following = camState.follow
	if following then
		local x, y, z = Follow.position(world, fx, visibleFx, following, t)
		if x then
			camState.x, camState.z, camState.minDistance = Follow.focus(x, y :: number, z :: number, camState.pitch, camState.yaw, function(gx, gz)
				return World.groundY(world, gx, gz)
			end)
		else
			camState.follow = nil -- it ended: the camera stays where it is
		end
	end
	if camState.follow == nil and camState.minDistance then
		-- after a follow the camera keeps the distance it had
		camState.distance = math.min(math.max(camState.distance, camState.minDistance), Camera.MAX_DISTANCE)
		camState.minDistance = nil
	end
	local payload = Camera.apply(camState, world, workspace.CurrentCamera, now)
	if payload then
		cmd:FireServer(payload)
	end
	api.state.camera.x, api.state.camera.z, api.state.camera.zoom = camState.x, camState.z, camState.distance
	api.state.camera.rect = camState.rect
	local followed = camState.follow
	local followDef = followed and followed.kind == "unit" and world.units[followed.id] and World.def(world, world.units[followed.id])
	FollowButton.step(followButton, if followed == nil then nil elseif followed.kind == "missile" then "missile" elseif followDef then followDef.name else `unit #{followed.id}`)
	t0 = os.clock()
	MissileViewRender.step(missileView, fx, world, t, now, visibleFx, workspace.CurrentCamera)
	NukeWarning.step(nukeWarning, fx, world, now, workspace.CurrentCamera)
	AttackPreviewRender.step(attackPreview, world, api.state.selection, if api.state.commandMode == "attack" then Controls.hover() else nil, workspace.CurrentCamera)
	mark("missileView", t0)
	t0 = os.clock()
	-- piece scripts (guide 14): not for models hidden at strategic zoom
	if not strategic then
		PieceAnim.drive(anim, world, fx.shots)
		PieceAnim.step(anim, simDt)
		UnitRenderer.applyPieces(renderer)
	end
	table.clear(fx.shots)
	mark("anim", t0)
	Api.frame(api, now)
	-- the unit under the mouse, ten times a second (the unit panel shows a hovered enemy, C-76)
	if now >= nextHover then
		nextHover = now + 0.1
		local id = Controls.hoverUnit(world)
		local hu = id and world.units[id]
		api.state.hover = if hu then { unit = id, x = hu.x, z = hu.z } else nil
	end
	if api.state.placement then
		local hover = Controls.hover()
		if hover then
			api.actions.updatePlacement(hover.X, hover.Z)
		end
	end
	PlacementGhost.step(ghost, api)
	QueuedBuilds.step(queued, api)
	t0 = os.clock()
	RangeOverlay.step(ranges, api, now, knownEnemy)
	RadarRings.step(radarRings, world, now)
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
		RenderDeaths.setVisible(renderer.deaths, not strategic)
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
	-- fog of war, radar / sonar contacts and ghosts (C-32); before `died` is cleared
	FogOfWar.step(fog, world, now, dt, camState.distance)
	Contacts.step(contacts, world, now, strategic)
	mark("fog", t0)
	t0 = os.clock()
	MinimapUI.step(minimap, api, now)
	ResourceBar.step(resourceBar, api, now)
	BuildMenuUI.step(buildMenu, api)
	CommandCard.step(commandCard, api)
	UnitPanel.step(unitPanel, api)
	AlertFeed.step(alertFeed)
	mark("ui", t0)
	mark("frame", frameT0)
	table.clear(world.died) -- the renderer and Effects have taken what they need
	local drawn = 0
	for _ in renderer.drawn do
		drawn += 1
	end
	local p = api.state.placement
	Hud.update(hud, world, t, drawn, camState.rect, now, #api.state.selection, if p then `{p.defId} ({if p.valid then "ok" else p.reason})` else nil, speed)
end)

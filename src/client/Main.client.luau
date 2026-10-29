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
local Canyon = require("@shared/Grid/Canyon")
local SupremeStrait = require("@shared/Grid/SupremeStrait")
local MapLook = require("./Core/MapLook")
local Atmosphere = require("./Render/Atmosphere")
local Idle = require("./Core/Idle")
local GroundMeshes = require("./Core/GroundMeshes")
local MatchLoading = require("./UI/MatchLoading")
local Preload = require("./Render/Preload")
local IdleStrip = require("./UI/IdleStrip")
local IdleMarks = require("./Render/IdleMarks")
local Api = require("./Api")
local Camera = require("./Camera")
local Interp = require("./Core/Interp")
local NetIn = require("./Core/NetIn")
local PieceAnim = require("./Core/PieceAnim")
local World = require("./Core/World")
local RadarFill = require("./Core/RadarFill")
local Hud = require("./Debug/Hud")
local Controls = require("./Input/Controls")
local ReclaimZones = require("./Core/ReclaimZones")
local Bars = require("./Core/Bars")
local Effects = require("./Core/Effects")
local Follow = require("./Core/Follow")
local Icons = require("./Core/Icons")
local IconLayer = require("./Render/IconLayer")
local MinimapUI = require("./UI/Minimap")
local ResourceBar = require("./UI/ResourceBar")
local ModelPool = require("./Render/ModelPool")
local RenderDeaths = require("./Render/Deaths")
local RenderEffects = require("./Render/Effects")
local ShieldDomes = require("./Render/ShieldDomes")
local FactoryFrames = require("./Render/FactoryFrames")
local BuildSpray = require("./Render/BuildSpray")
local ShieldFx = require("./Render/ShieldFx")
local Contacts = require("./Render/Contacts")
local FogBlanket = require("./Render/FogBlanket")
local Environment = require("./Render/Environment")
local Grade = require("./Render/Grade")
local Glow = require("./Render/Glow")
local MeshModels = require("./Render/MeshModels")
local Models = require("./Render/Models")
local Vfx = require("./Render/Vfx")
local Ground = require("./Render/Ground")
local HealthBars = require("./Render/HealthBars")
local SensorFxRender = require("./Render/SensorFx")
local WreckInfo = require("./Render/WreckInfo")
local Overlay = require("./Render/Overlay")
local Placement = require("./Core/Placement")
local PlacementGhost = require("./Render/PlacementGhost")
local DepositsRender = require("./Render/Deposits")
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
local CheatConsole = require("./UI/CheatConsole")
local CheatInput = require("./Core/CheatInput")
local CheatText = require("@shared/Net/CheatText")
local Commands = require("./Core/Commands")
local Kit = require("./UI/Kit")
local Crater = require("./Render/Crater")
local ReplayPlayer = require("./Core/ReplayPlayer")
local PlayerReplay = require("@shared/Net/PlayerReplay")
local AttackPreviewRender = require("./Render/AttackPreview")
local QueuedBuilds = require("./Render/QueuedBuilds")
local RangeOverlay = require("./Render/RangeOverlay")
local UnitRenderer = require("./Render/UnitRenderer")
local Pregame = require("./Core/Pregame")
local PregameMarks = require("./Render/PregameMarks")
local PregamePanel = require("./UI/PregamePanel")
local Landing = require("./Render/Landing")
local CommanderNames = require("./Render/CommanderNames")
local TeamPanel = require("./UI/TeamPanel")
local TeamColors = require("./Render/TeamColors")

local defs = Defs.load()
-- no Roblox HUD (C-109, the user): chat, player list, backpack, health and
-- emotes off, and the top bar's items hidden where Roblox allows it (its
-- menu button stays: the game's screens keep clear of TopbarInset)
do
	local StarterGui = game:GetService("StarterGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	end)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", false)
	end)
end
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
	return if mapId == "map:normandy" then Normandy.feature elseif mapId == "map:canyon" then Canyon.feature elseif mapId == "map:supreme_strait" then SupremeStrait.feature else nil
end

local controls = Controls.bind(api)
-- clicks select a unit by its model too, wherever it is drawn (an aircraft
-- high above its ground point, a big model's body; C-38)
local pickParams = RaycastParams.new()
pickParams.FilterType = Enum.RaycastFilterType.Include
Controls.heightAt = function(x: number, z: number): number
	return World.groundY(world, x, z, true) -- the water's surface over water (C-209)
end
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
local deposits = DepositsRender.new() -- supply deposits and their overlay (C-123)
local queued = QueuedBuilds.new()
local ranges = RangeOverlay.new()
local missileView = MissileViewRender.new() -- missile sensor view (C-39), N
local nukeWarning = NukeWarning.new() -- strategic launch warnings (C-57)
local radarRings = RadarRings.new() -- own radar facilities' rings, always on top (C-63, C-64)
local attackPreview = AttackPreviewRender.new() -- attack mode's arc preview (C-58)
-- Camera follow (C-43), T in developer mode (C-124; the on-screen button is
-- gone; rebindable, C-159): the first selected unit, else the homing
-- missile drawn nearest the screen centre.
local lastVisibleFx: { { any } } = {} -- Effects.visible's list from the last frame
local shieldDomes = ShieldDomes.new() -- shield generators' domes (C-91)
local factoryFrames = FactoryFrames.new() -- units in production on their factory's pad (C-152)
local buildSpray = BuildSpray.new() -- builders' nano spray at what they build (C-193)
local function toggleFollow()
	if camState.follow then
		camState.follow = nil
		return
	end
	local cam = workspace.CurrentCamera
	local view = cam.ViewportSize
	camState.follow = Follow.pick(world, api.state.selection, lastVisibleFx, Controls.projector(cam), view.X / 2, view.Y / 2)
end
-- Idle builders and factories (C-158): counts in the top strip, I jumps to
-- the next idle builder (selected, the camera follows it), a tag over each.
local idle = Idle.new()
local idleMarks = IdleMarks.new()
local nextIdleCount = 0
local function pickIdle(kind: string)
	local id = Idle.next(idle, kind :: any)
	if id then
		api.actions.select({ id })
		camState.follow = { kind = "unit", id = id }
	end
end
local idleStrip = IdleStrip.new(pickIdle)
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
	if processed or SettingsMenu.capturing then
		return
	end
	local key = input.KeyCode
	if BuildMenuUI.active and BuildMenuUI.takes(BuildMenuUI.active, key) then
		return -- a build tab's key while a builder's menu shows (C-203)
	elseif key == RangeOverlay.TOGGLE_KEY then
		RangeOverlay.setEnabled(ranges, not ranges.enabled)
	elseif key == DepositsRender.TOGGLE_KEY then
		DepositsRender.setEnabled(deposits, not deposits.enabled)
	elseif key == MissileViewRender.TOGGLE_KEY then
		MissileViewRender.setEnabled(missileView, not missileView.enabled)
	elseif key == SettingsMenu.key("idle") then
		pickIdle("builder")
	elseif key == SettingsMenu.key("follow") then
		local settings = SettingsMenu.state
		if settings and settings.devMode then
			toggleFollow()
		end
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
local sensorFx = SensorFxRender.new()
local wreckInfo = WreckInfo.new()
local fog = FogBlanket.new()
local workOf: { [number]: { number } } = {} -- builder → where its work stands (the nano spray's targets; the Commander's torso, G4)
local fogGround: any = nil -- the Ground.last whose finished mesh ground the blanket was rebuilt over (C-213)
local radarCircles: { RadarFill.Circle }? = nil -- the radar layer's circles, nil while hidden (C-207)
local radarAt = 0
local environment = Environment.new() -- ground beyond the map, ambient particles (C-102)
local grade = Grade.new() -- colour grade: zoom easing, blast flashes, vignette (C-102)
local glow = Glow.new() -- unit glow states and headlights (C-103)
-- BAR mesh models from the manifest (C-103): built in the background; each
-- one replaces its blockout when ready
local meshReady: { string } = {}
MeshModels.onReady(function(id: string)
	table.insert(meshReady, id)
end)
local seenModels = Models.version
local nextMeshWant = 0
local joinedAt: number? = nil
-- Mesh models load once a match is joined and detailed models are on:
-- types drawn on screen first, then every type in the match (known units,
-- icons included), then the player's faction, then the rest (C-106).
local function wantMeshes(now: number)
	if not Models.DETAILED or not world.joined then
		return
	end
	joinedAt = joinedAt or now
	if not MeshModels.started() then
		-- wait for the first units (their types go first), 2 s at most
		if next(world.units) == nil and now < (joinedAt :: number) + 2 then
			return
		end
		MeshModels.start(defs)
	end
	if now < nextMeshWant then
		return
	end
	nextMeshWant = now + 0.5
	local faction
	for _, u in world.units do
		-- strategic records name their type by the icon (the def index, S-58)
		local def = World.def(world, u) or (if u.icon and u.icon > 0 then defs.unitByIndex[u.icon] else nil)
		if def then
			MeshModels.want(def.id, if u.tier == "tactical" then 3 else 2)
			if u.team == world.me.team then
				faction = def.faction
			end
		end
	end
	if faction then
		for id, def in defs.units do
			if def.faction == faction then
				MeshModels.want(id, 1)
			end
		end
	end
end
Vfx.onSpawn = function(kind: string, x: number, _y: number, z: number, scale: number)
	Grade.burst(grade, kind, x, z, scale)
end
local contacts = Contacts.new()
-- enemy structures seen before (kept by Contacts) and icon sample defs: enemy defense rings (C-41)
local knownEnemy = { memory = contacts.memory.memory, sample = iconTable.sample }
local strategic = false
local tiers: { [number]: string } = {}
local minimap = MinimapUI.new(api) -- placeholder UI (task 9)
local resourceBar = ResourceBar.new() -- placeholder UI (task 9)
-- playable placeholder UI (C-68): build menu, command card, unit panel, alerts
local buildMenu = BuildMenuUI.new(api)
Camera.keyTaken = function(key: Enum.KeyCode): boolean
	return BuildMenuUI.takes(buildMenu, key) -- C is the Utility tab's while a builder's menu shows (C-203)
end
local commandCard = CommandCard.new(api)
local unitPanel = UnitPanel.new(api)
local alertFeed = AlertFeed.new(api)
local _lobbyUI = LobbyUI.new(remotes) -- the lobby and results screens (C-70; profiles with a lobby only)
-- a lobby match's loading screen while everyone caches (C-173): it reports
-- this client's progress (Render/Preload) and hides once the match starts
local matchLoading = MatchLoading.new(remotes)
local preload = Preload.new()
local LOAD_HOLD = 115 -- seconds at most the first CAMERA waits for the preload (the sim's Pregame.LOAD_WAIT is 120)
local holdSince: number? = nil
local loadedAt: number? = nil
Controls.capture = function(input: InputObject): boolean
	if SettingsMenu.capturing and input.UserInputType == Enum.UserInputType.Keyboard then
		return true -- Settings > Keys is taking this key (C-159)
	end
	return BuildMenuUI.capture(buildMenu, api, input)
end
api.changed.alert:Connect(function(alert: any)
	MinimapUI.ping(minimap, world.grid, alert.x, alert.z, AlertFeed.COLOR[alert.kind] or Color3.new(1, 1, 1))
end)

-- Drawn muzzle of a unit's weapon slot (tracers start there), if it has a
-- model. A slot with several `muzzles` (S-157: Overwatch, Twin Guard,
-- Geryon, Bulwark's laser) fires from each in turn (C-198), in step with
-- the piece script's recoil (it counts the same shots).
local muzzleShots: { [number]: number } = {}
local function muzzleOf(id: number, slot: number): (number?, number?, number?)
	local model = UnitRenderer.modelOf(renderer, id)
	local u = world.units[id]
	local def = u and World.def(world, u)
	local slotDef = def and def.weapons[slot]
	local name = slotDef and slotDef.muzzle
	local list = slotDef and slotDef.muzzles
	if list and #list > 0 then
		local key = id * 16 + slot
		local n = muzzleShots[key] or 0
		muzzleShots[key] = n + 1
		name = list[n % #list + 1]
	end
	local att = model and name and model:FindFirstChild(name, true)
	if att and att:IsA("Attachment") then
		local p = att.WorldPosition
		return p.X, p.Y, p.Z
	end
	return nil, nil, nil
end
-- the pre-game (C-218, net.md 9b): spawn boxes and picks on the map; the
-- panel with the countdown and Ready; a left click places the Commander
local pregameMarks = PregameMarks.new()
local pregamePanel = PregamePanel.new({
	ready = function(on: boolean)
		api.send(Pregame.ready(on))
	end,
	faction = function(faction: string)
		if not Pregame.isReady(world, world.me.player) then
			api.send(Pregame.faction(faction))
		end
	end,
	start = function()
		if Pregame.allReady(world) then
			api.send(Pregame.start(false))
		end
	end,
})
local pregameSeen = { active = false, started = false, homed = false } -- for the camera's jumps
local commanderNames = CommanderNames.new() -- each Commander's player name over it
local teamPanel = TeamPanel.new(api) -- players by team, sharing with allies (F23)
local landing = Landing.new() -- the Commanders drop in with a star flare as the match starts (S-174)
UnitRenderer.lift = Landing.lift(world)
Controls.pregameClick = function(ground: Vector3?): boolean
	local pg = world.pregame
	if not pg.active or world.me.player == 0 then
		return pg.active
	end
	local areas = Pregame.areas(world)
	if ground and areas and Pregame.canPick(world, areas, ground.X, ground.Z) then
		api.send(Pregame.startPos(world.grid, ground.X, ground.Z))
		PregamePanel.sent(pregamePanel, ground.X, ground.Z, os.clock())
	else
		PregamePanel.refuse(pregamePanel, "Pick a spot inside your area, away from the other starts.", os.clock())
	end
	return true
end
-- a hitscan hit on a drawn unit: the line from the muzzle toward the middle
-- of the nearest model's box at the hit, ended where it first meets that
-- model (Core/Effects.bodyAt)
local bodyParams = RaycastParams.new()
bodyParams.FilterType = Enum.RaycastFilterType.Include
Effects.bodyAt = function(x0: number, y0: number, z0: number, x: number, _y: number, z: number): (number?, number?, number?)
	local best, bestD = nil, math.huge
	for id, u in world.units do
		if u.tier == "tactical" and u.rx and u.rz then
			local d = (u.rx - x) ^ 2 + (u.rz - z) ^ 2
			local def = World.def(world, u)
			local reach = ((def and def.footprint) or 1) * 4 + 3
			if d < bestD and d <= reach * reach then
				best, bestD = id, d
			end
		end
	end
	local model = best and UnitRenderer.modelOf(renderer, best)
	if model == nil then
		return nil, nil, nil
	end
	local centre = model:GetBoundingBox().Position
	local from = Vector3.new(x0, y0, z0)
	local dir = centre - from
	if dir.Magnitude < 1e-3 then
		return centre.X, centre.Y, centre.Z
	end
	bodyParams.FilterDescendantsInstances = { model }
	local hit = workspace:Raycast(from, dir.Unit * (dir.Magnitude + 4), bodyParams)
	local at = if hit then hit.Position else centre
	return at.X, at.Y, at.Z
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

-- the cheat command line (C-119): Enter or "/" opens it. The commands are
-- the sim's (Shared/Net/CheatText, net.md 9a); until that lands this is a
-- stub that echoes what it would send. "/cheat on|off" is the lobby's
-- Cheats toggle (host only).
local cheatConsole: CheatConsole.UI
local function submitCheat(text: string)
	local cursor = Controls.hover() -- "at" defaults to the cursor ground position
	local line = CheatInput.prepare(text, defs, cursor and cursor.X, cursor and cursor.Z)
	local lower = string.lower(line)
	if lower == "cheat on" or lower == "cheat off" then
		local lobbyRemote = remotes:FindFirstChild("Lobby") :: RemoteEvent?
		if lobbyRemote then
			lobbyRemote:FireServer({ op = "set", key = "cheats", value = lower == "cheat on" })
			CheatConsole.print(cheatConsole, `lobby: Cheats {if lower == "cheat on" then "on" else "off"} (host only; takes effect at the next match)`)
		else
			CheatConsole.print(cheatConsole, "cheat on|off: no lobby here (Studio profiles always allow cheats)")
		end
		return
	end
	if lower == "forcestart" then
		-- the host starts the match now, ready or not (S-174)
		if world.pregame.active and Pregame.isHost(world, world.me.player) then
			api.send(Pregame.start(true))
			CheatConsole.print(cheatConsole, "forcing the start")
		else
			CheatConsole.print(cheatConsole, "forcestart: only the host, during the pre-game", Kit.COLOR.defeat)
		end
		return
	end
	local command, why = CheatText.parse(line, defs, api.state.selection)
	if command == nil then
		CheatConsole.print(cheatConsole, why or "not a cheat command (/help)", Kit.COLOR.defeat)
		return
	end
	if replay then
		CheatConsole.print(cheatConsole, "not while watching a replay", Kit.COLOR.defeat)
		return
	end
	if line ~= CheatInput.strip(text) then
		CheatConsole.print(cheatConsole, "  → " .. line, Kit.COLOR.dim) -- the id and cursor position filled in
	end
	cmd:FireServer(Commands.encode(command)) -- the sim answers with CHEAT_RESULT
end
cheatConsole = CheatConsole.new(defs, submitCheat)
-- the same commands for Roblox's chat, if it is ever turned back on
do
	local TextChatService = game:GetService("TextChatService")
	local folder = TextChatService:FindFirstChild("TextChatCommands")
	if folder then
		for _, c in CheatInput.COMMANDS do
			local command = Instance.new("TextChatCommand")
			command.Name = "Ftgg_" .. c[1]
			command.PrimaryAlias = "/" .. c[1]
			command.Parent = folder
			command.Triggered:Connect(function(_source: TextSource, text: string)
				if c[1] == "help" then
					for _, h in CheatInput.help() do
						CheatConsole.print(cheatConsole, h, Kit.COLOR.dim)
					end
				else
					submitCheat(text)
				end
			end)
		end
	end
end
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
	local function groundY(x: number, z: number): number
		return World.groundY(world, x, z)
	end
	-- the rendered terrain's surface (can sit above the sim's ground height), for place content
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	local function surfaceY(x: number, z: number): number
		local hit = workspace:Raycast(Vector3.new(x, 2000, z), Vector3.new(0, -4000, 0), terrainOnly)
		return if hit then hit.Position.Y else groundY(x, z)
	end
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
			-- Invoke("shield", seconds?, radius?): the shield mechanic demo (C-87) under the camera's focus
			local seconds, radius = ...
			local y = surfaceY(camState.x, camState.z)
			require("./Render/ShieldDemo").run(Vector3.new(camState.x, y, camState.z), if type(radius) == "number" then radius else 120, if type(seconds) == "number" then seconds else 30)
			return { center = { camState.x, y, camState.z } }
		elseif query == "shieldfx" then
			-- Invoke("shieldfx", op, ...): the shield domes (C-90):
			--   "review": the placeholder generators in ReplicatedStorage.ShieldFxReview
			--     (place content: an Emitter attachment, Radius and Offset attributes)
			--     copied round the camera's focus onto the ground, each with its dome
			--   "spawn", x, z, radius   "bench", n, radius (a grid round the camera's focus)
			--   "deploy" | "collapse" | "hit", intensity? | "strength", f | "drain", to?, seconds?
			--   "slow", timeScale | "stats" (the render loop's ms and Roblox's render times) | "clear"
			local op, a, b = ...
			local ShieldFx = require("./Render/ShieldFx")
			local all = ShieldFx.all()
			if op == "review" then
				local made = {}
				local source = game:GetService("ReplicatedStorage"):FindFirstChild("ShieldFxReview")
				local live = workspace:FindFirstChild("ShieldFxReviewLive") or Instance.new("Folder")
				live.Name = "ShieldFxReviewLive"
				live.Parent = workspace
				for _, original in (if source then source:GetChildren() else {}) do
					local radius = original:GetAttribute("Radius")
					local offset = original:GetAttribute("Offset")
					if original:IsA("Model") and type(radius) == "number" then
						local gen = original:Clone()
						local x = camState.x + (if typeof(offset) == "Vector3" then offset.X else 0)
						local z = camState.z + (if typeof(offset) == "Vector3" then offset.Z else 0)
						gen:PivotTo(CFrame.new(x, surfaceY(x, z), z)) -- the pivot is the bottom centre, upright
						gen.Parent = live
						local emitter = gen:FindFirstChild("Emitter", true)
						if emitter and emitter:IsA("Attachment") then
							ShieldFx.new(emitter, radius, nil, Vector3.new(x, surfaceY(x, z), z)):deploy()
							table.insert(made, { gen.Name, radius })
						end
					end
				end
				return made
			elseif op == "spawn" then
				local x, z = a or camState.x, b or camState.z
				local radius = select(4, ...) or 48
				ShieldFx.new(Vector3.new(x, surfaceY(x, z), z), radius):deploy()
			elseif op == "bench" then
				local n, radius = a or 20, b or 24
				local cols = math.ceil(math.sqrt(n))
				local gap = radius * 2.2
				for i = 0, n - 1 do
					local x = camState.x + (i % cols - (cols - 1) / 2) * gap
					local z = camState.z + (i // cols - (math.ceil(n / cols) - 1) / 2) * gap
					ShieldFx.new(Vector3.new(x, surfaceY(x, z), z), radius):deploy()
				end
			elseif op == "deploy" or op == "collapse" then
				for _, s in all do
					(s :: any)[op](s)
				end
			elseif op == "hit" then
				-- a hit on the camera's side of every dome, a little off its centre
				for _, s in all do
					local toCam = (workspace.CurrentCamera.CFrame.Position - s.position).Unit
					local jitter = Vector3.new(math.random() - 0.5, math.random() * 0.5, math.random() - 0.5)
					s:hit(s.position + (toCam + jitter).Unit * s.radius, a or 1)
				end
			elseif op == "strength" then
				for _, s in all do
					s:setStrength(a or 1)
				end
			elseif op == "drain" then
				-- strength runs down to `a` (default 0) over `b` seconds (default 4)
				local to, seconds = a or 0, b or 4
				local from = {}
				for i, s in all do
					from[i] = s.strength
				end
				local t0 = os.clock()
				local conn: RBXScriptConnection
				conn = RunService.Heartbeat:Connect(function()
					local k = math.min(1, (os.clock() - t0) / seconds)
					for i, s in all do
						s:setStrength((from[i] or 1) + (to - (from[i] or 1)) * k)
					end
					if k >= 1 then
						conn:Disconnect()
					end
				end)
			elseif op == "slow" then
				ShieldFx.timeScale = a or 1 -- slow motion for screenshots (1 = normal)
			elseif op == "clear" then
				for i = #all, 1, -1 do
					all[i]:destroy()
				end
				local live = workspace:FindFirstChild("ShieldFxReviewLive")
				if live then
					live:Destroy()
				end
			end
			local stats = game:GetService("Stats") :: any
			local st = table.clone(ShieldFx.stats)
			st.renderCPU = stats.RenderCPUFrameTime
			st.renderGPU = stats.RenderGPUFrameTime
			return st
		elseif query == "shielddomes" then
			-- the match's shield domes (C-91): generator id → state, and the SHIELD records
			local domes, records = {}, {}
			for id, d in shieldDomes.domes do
				domes[tostring(id)] = { up = d.up, x = d.x, z = d.z, state = d.fx.state, strength = d.fx.strength }
			end
			for id, r in world.shields do
				records[tostring(id)] = r
			end
			local st = shieldDomes.stats
			return { domes = domes, records = records, hits = { hits = st.hits, breaches = st.breaches, enters = st.enters, lit = st.lit, lagTicks = st.lagSum / math.max(st.lagN, 1), lastBreaches = st.lastBreaches } }
		elseif query == "fogshow" then
			-- debug: the fog blanket on or off (as the settings menu does), for before / after views
			local on = ...
			FogBlanket.ENABLED = on ~= false
			return FogBlanket.ENABLED
		elseif query == "fogreach" then
			-- debug: rebuild the blanket with FogBlanket.REACH = reach (C-213: how far round a vertex its height looks)
			FogBlanket.REACH = (...) or FogBlanket.REACH
			if world.layers then
				FogBlanket.setMap(fog, world, world.layers)
			end
			return FogBlanket.REACH
		elseif query == "fogstress" then
			-- debug: for a few seconds (default 4), every sensor cell of the team sight
			-- flips at the sim rate (worse than any battle), through the real path;
			-- the fog step's average and worst ms per update, the client's memory
			local seconds = ... or 4
			local sight = world.sight
			if sight == nil then
				return false
			end
			local n = sight.width * sight.depth
			local on = 0
			local sum, worst, count, lastUploads = 0, 0, 0, fog.stats.uploads
			local t0 = os.clock()
			local nextFlip = 0
			while os.clock() - t0 < seconds do
				if os.clock() >= nextFlip then
					nextFlip = os.clock() + 1 / 15
					on = 1 - on
					for i = 0, n - 1 do
						buffer.writeu8(sight.cells, i, if (i + on) % 2 == 0 then 1 else 0)
					end
					sight.full = true
					sight.version += 1
				end
				RunService.Heartbeat:Wait()
				if fog.stats.uploads ~= lastUploads then
					lastUploads = fog.stats.uploads
					sum += fog.stats.ms
					worst = math.max(worst, fog.stats.ms)
					count += 1
				end
			end
			local stats = game:GetService("Stats") :: any
			return { avgMs = sum / math.max(count, 1), worstMs = worst, updates = count, memoryMb = stats:GetTotalMemoryUsageMb() }
		elseif query == "fogpattern" then
			-- debug: a test pattern in the fog image (west half clear, a dark notch at
			-- its north-west corner), frozen until the next real update of those pixels
			local img = fog.image
			if img == nil then
				return false
			end
			local w, h = img.Size.X, img.Size.Y
			local b = buffer.create(w * h * 4)
			for y = 0, h - 1 do
				for x = 0, w - 1 do
					local a = if x < w / 2 then 0 else 150
					if x < w / 8 and y < h / 8 then
						a = 255
					end
					buffer.writeu32(b, (y * w + x) * 4, bit32.lshift(a, 24))
				end
			end
			FogBlanket.frozen = true -- the step stops overwriting it
			img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), b)
			return true
		elseif query == "camera" then
			-- Invoke("camera", x?, z?, distance?, pitchDegrees?, yawDegrees?): put the camera there (screenshots)
			local x, z, distance, pitch, yaw = ...
			camState.follow = nil
			camState.x = x or camState.x
			camState.z = z or camState.z
			camState.distance = distance or camState.distance
			camState.pitch = if pitch then math.rad(pitch) else camState.pitch
			camState.yaw = if yaw then math.rad(yaw) else camState.yaw
			return { x = camState.x, z = camState.z, distance = camState.distance, pitch = math.deg(camState.pitch) }
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
		elseif query == "cheatline" then
			-- Invoke("cheatline", text): the cheat command line as if typed and entered (C-119)
			CheatConsole.enter(cheatConsole, (...))
			return true
		elseif query == "wrecksanyway" then
			-- Invoke("wrecksanyway", on): use review wreck meshes too (for the user's review, C-115)
			MeshModels.WRECKS_ANYWAY = (...) == true
			return true
		elseif query == "shellanyway" then
			-- Invoke("shellanyway", on): models-C's review honeycomb shell on shield domes (C-138)
			require("./Render/ShieldFx").SHELL_ANYWAY = (...) == true
			return true
		elseif query == "beamsanyway" then
			-- Invoke("beamsanyway", on): models-C's review beam shot effect (for the user's review, C-133)
			require("./Render/BeamShots").ANYWAY = (...) == true
			return true
		elseif query == "featuresanyway" then
			-- Invoke("featuresanyway", on): draw C's review tree and rock meshes (S-197)
			MeshModels.FEATURES_ANYWAY = (...) == true
			return true
		elseif query == "depositsanyway" then
			-- Invoke("depositsanyway", on): draw C's review deposit models (for the user's review, C-123)
			MeshModels.DEPOSITS_ANYWAY = (...) == true
			return true
		elseif query == "groundanyway" then
			-- Invoke("groundanyway", on): draw the map's review mesh ground (C-167) and rebuild it
			GroundMeshes.ANYWAY = (...) == true
			if world.layers then
				Ground.build(world.layers, nil, mapFeature(world.mapId), world.mapId)
			end
			return Ground.last
		elseif query == "reviewmesh" then
			-- Invoke("reviewmesh", defId): build and draw one review unit mesh (C-160)
			local id = ...
			if type(id) == "string" then
				MeshModels.REVIEW[id] = true
				MeshModels.start(defs)
			end
			return true
		elseif query == "meshes" then
			-- BAR mesh models (C-103): built, failed, seconds, errors
			return MeshModels.stats
		elseif query == "glow" then
			-- unit glow (C-103): models with glow parts, parts, writes and ms last frame, headlights lit
			return glow.stats
		elseif query == "glowratio" then
			-- Invoke("glowratio", r?): pretend the team's power ratio is r (an energy stall), nil: the real one
			Glow.RATIO_OVERRIDE = (...)
			return true
		elseif query == "fog" then
			-- fog of war (the blanket, C-100): its stats; contacts and ghosts
			-- the server's ally-team sight (C-65): records applied, cells seen
			local sight = world.sight
			local seenCells = 0
			if sight then
				for i = 0, sight.width * sight.depth - 1 do
					seenCells += buffer.readu8(sight.cells, i)
				end
			end
			return { stats = fog.stats, fading = fog.core and fog.core.stats.fading, contacts = contacts.stats, version = fog.vision and fog.vision.version, sightVersion = sight and sight.version, seenCells = seenCells, wrecks = renderer.deaths.stats.wrecks }
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
		elseif query == "unit" then
			-- Invoke("unit", id): what the client knows of a unit (tier, headings, aims, weapon states; G9)
			local u = world.units[(...) :: number]
			if u == nil then
				return nil
			end
			local aims = {}
			for slot, a in u.aim or {} do
				aims[tostring(slot)] = { yaw = math.deg(a.yaw), pitch = math.deg(a.pitch), state = Schema.weaponStateAt(u.weapon or 0, slot) }
			end
			local au = anim.units[(...) :: number]
			return { tier = u.tier, heading = math.deg(u.heading), drawn = u.rheading and math.deg(u.rheading), aim = aims, lod = au and au.lod, lag = au and au.aimLag[1] and math.deg(au.aimLag[1]) }
		elseif query == "water" then
			-- Invoke("water", "mesh" | "terrain"): draw the water that way and rebuild the ground (C-236)
			local mode = ...
			if mode == "mesh" or mode == "terrain" then
				Ground.WATER = mode
				if world.layers then
					Ground.build(world.layers, nil, mapFeature(world.mapId), world.mapId)
				end
			end
			return Ground.last
		elseif query == "ground" then
			-- Invoke("ground", "terrain" | "parts"?): rebuild the ground that way; Invoke("ground") the last build's stats
			local mode = ...
			if mode and world.layers then
				Ground.build(world.layers, mode, mapFeature(world.mapId), world.mapId)
				DepositsRender.build(deposits, world.layers, mapFeature(world.mapId))
			end
			return Ground.last
		elseif query == "hint" then
			-- Invoke("hint", x, z): the deposit hint's steps there (C-244 checks)
			local x, z = ...
			local def = api.actions.hintExtractor()
			if def == nil then
				return { extractor = "none", selected = #api.state.selection }
			end
			local r = Placement.check(world, def, x, z, Placement.planned(world, api.waypoints.byUnit))
			local spots = Placement.area(world, def, x, z, 12, x, z, Placement.planned(world, api.waypoints.byUnit))
			local g = Controls.hover()
			local atMouse = if g then api.actions.depositHintAt(g.X, g.Z) else nil
			return { extractor = def.id, ok = r.ok, reason = r.reason, spots = #spots, replaces = spots[1] and spots[1].replaces, hint = api.state.depositHint, mouseGround = g and { g.X, g.Z }, hoverUnit = Controls.hoverUnit(world), atMouse = atMouse, placing = api.state.placement ~= nil, mode = api.state.commandMode }
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
	MatchLoading.step(matchLoading, now, Preload.progress(preload, world))
	-- twice the meshes building at once behind the loading screen (nothing to draw)
	MeshModels.AT_ONCE = if matchLoading.gui.Enabled then 16 else 8
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
		TeamColors.setViewer(world.me.player, world.me.team, world.teamAllies) -- you Blue, allies cold, enemies warm (C-217)
		pregameSeen.active, pregameSeen.started, pregameSeen.homed = false, false, false
		FactoryFrames.clear(factoryFrames)
		UnitRenderer.clear(renderer)
		Effects.clear(fx)
		Crater.clear() -- the last match's nuke craters (C-82)
		clock = Interp.newClock()
		camState.lastRect = nil -- resend the camera so the tactical tier is rebuilt
		if world.mapVersion ~= seenMap then
			seenMap = world.mapVersion
			if world.layers then
				Ground.build(world.layers, nil, mapFeature(world.mapId), world.mapId)
				DepositsRender.build(deposits, world.layers, mapFeature(world.mapId))
				MinimapUI.setMap(minimap, world.layers)
				FogBlanket.setMap(fog, world, world.layers)
				Environment.setMap(environment, world.layers, MapLook.of(world.mapId))
				Atmosphere.setMap(world.mapId) -- its lighting and time of day, unless Settings picked another (C-155)
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
	World.smoothStrategic(world, dt, now) -- radar blips glide, not jump, and circle their spot (C-151, C-154)
	local t0 = os.clock()
	UnitRenderer.step(renderer, world, t, simDt, strategic, workspace.CurrentCamera.CFrame.Position, speed)
	Landing.step(landing, world, t, now)
	if strategic then
		FactoryFrames.clear(factoryFrames)
	else
		FactoryFrames.step(factoryFrames, world, renderer, now)
	end
	BuildSpray.step(buildSpray, world, renderer, api.waypoints.byUnit, now, strategic)
	mark("units", t0)
	t0 = os.clock()
	Effects.update(fx, world, t, now, camState.x, camState.z, muzzleOf)
	local visibleFx = RenderEffects.step(fxRenderer, fx, t, now, speed)
	lastVisibleFx = visibleFx
	ShieldFx.simSpeed = speed
	ShieldDomes.step(shieldDomes, world, fx, renderer)
	ShieldDomes.forces(shieldDomes, visibleFx)
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
	-- the pre-game opens over the own area; the match starts over the own Commander
	local pg = world.pregame
	if (pg.active and not pregameSeen.active) or (pg.started and not pregameSeen.started and world.me.player ~= 0) then
		camState.x, camState.z = Pregame.focus(world, Pregame.areas(world))
		camState.follow = nil
		local fit = pg.active and Pregame.fitDistance(world, Pregame.areas(world))
		if fit then
			camState.distance = math.clamp(fit, camState.distance, Camera.MAX_DISTANCE) -- the whole area in view
		end
	end
	pregameSeen.active, pregameSeen.started = pg.active, pg.started
	-- every match opens over the own Commander, the first time it's there
	-- after a join (the user; fixed starts too, not only the pre-game's)
	if not pregameSeen.homed and not pg.active and world.me.player ~= 0 then
		for _, u in world.units do
			local def = u.team == world.me.team and World.def(world, u)
			if def and table.find(def.categories or {}, "COMMANDER") then
				camState.x, camState.z = u.x, u.z
				camState.follow = nil
				pregameSeen.homed = true
				break
			end
		end
	end
	local payload = Camera.apply(camState, world, workspace.CurrentCamera, now)
	-- a lobby match's first CAMERA waits until this client has loaded
	-- everything (or LOAD_HOLD seconds): the pre-game's clocks start on every
	-- human's first command (S-182), so nobody's pick time runs while they
	-- still load (the user: every model ready before the match)
	if payload and loadedAt == nil then
		holdSince = holdSince or now
		local progress = Preload.progress(preload, world)
		if not MatchLoading.isMatch(matchLoading) then
			loadedAt = now -- not a lobby match: nothing to wait for
		elseif progress >= 0.999 or now - holdSince >= LOAD_HOLD then
			loadedAt = now
			print(string.format("[Client] loaded in %.1f s (%s)", now - holdSince, if progress >= 0.999 then "everything ready" else "gave up waiting"))
		else
			camState.lastRect = nil -- sent again once loaded
			payload = nil
		end
	end
	if payload then
		cmd:FireServer(payload)
	end
	api.state.camera.x, api.state.camera.z, api.state.camera.zoom = camState.x, camState.z, camState.distance
	api.state.camera.rect = camState.rect
	api.state.camera.corners = camState.corners
	Environment.update(environment, camState.x, camState.z, camState.distance, World.groundY(world, camState.x, camState.z))
	Grade.update(grade, camState.x, camState.z, camState.distance, dt)
	t0 = os.clock()
	MissileViewRender.step(missileView, fx, world, t, now, visibleFx, workspace.CurrentCamera)
	NukeWarning.step(nukeWarning, fx, world, now, workspace.CurrentCamera)
	AttackPreviewRender.step(attackPreview, world, api.state.selection, if api.state.commandMode == "attack" then Controls.hover() else nil, workspace.CurrentCamera)
	CheatConsole.step(cheatConsole)
	-- the sim's answers to cheat commands (S-102)
	for _, e in world.cheatResults do
		local ok = e.cheatResult == Schema.CheatResult.OK
		CheatConsole.print(cheatConsole, CheatText.describe(e), if ok then Kit.COLOR.on else Kit.COLOR.defeat)
	end
	table.clear(world.cheatResults)
	mark("missileView", t0)
	t0 = os.clock()
	-- piece scripts (guide 14): not for models hidden at strategic zoom
	wantMeshes(now)
	if Models.version ~= seenModels then
		seenModels = Models.version
		FactoryFrames.clear(factoryFrames)
		ModelPool.flushAll()
		UnitRenderer.reshowAll(renderer, world)
		table.clear(meshReady)
	end
	for _, id in meshReady do
		FactoryFrames.clear(factoryFrames)
		Models.forget(id)
		ModelPool.flush(id)
		UnitRenderer.reshow(renderer, world, id)
	end
	table.clear(meshReady)
	Glow.shots(glow, fx.shots, now)
	if not strategic then
		table.clear(workOf)
		for _, sp in buildSpray.list do
			local t = if sp.wreck then world.wrecks[sp.target] else world.units[sp.target]
			if t then
				workOf[sp.builder] = { t.x, t.z }
			end
		end
		PieceAnim.drive(anim, world, fx.shots, workOf)
		PieceAnim.step(anim, simDt)
		UnitRenderer.applyPieces(renderer)
		Glow.step(glow, renderer, world, now, workspace.CurrentCamera, camState.x, camState.z, camState.distance)
	elseif glow.stats.headlights > 0 then
		Glow.hide(glow)
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
		local ground = if hu then nil else Controls.hover()
		local w = if ground then ReclaimZones.wreckAt(world, ground.X, ground.Z) else nil
		api.state.hoverWreck = if w then w.id else nil
		-- a free deposit under the mouse with builders selected: its extractor's ghost (C-244)
		api.state.depositHint = if ground and api.state.placement == nil and api.state.commandMode == nil then api.actions.depositHintAt(ground.X, ground.Z) else nil
	end
	if api.state.placement then
		local hover = Controls.hover()
		if hover then
			api.actions.updatePlacement(hover.X, hover.Z)
		end
	end
	PlacementGhost.step(ghost, api, now, controls.areaFrom, controls.areaTo, if controls.placeTo then controls.placeFrom else nil, controls.placeTo, Controls.alt())
	QueuedBuilds.step(queued, api)
	t0 = os.clock()
	RangeOverlay.step(ranges, api, now, knownEnemy)
	DepositsRender.step(deposits, api, now)
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
	local barList = Bars.list(world, api.selection.set)
	local wreckBars = Bars.wreckList(world) -- wrecks' supply and resurrect bars (C-216)
	table.move(wreckBars, 1, #wreckBars, #barList + 1, barList)
	local barDraws = if strategic then {} else Bars.draws(world, barList, Controls.projector(cam), view.X, view.Y, right.X, right.Z)
	HealthBars.step(healthBars, barDraws, not strategic)
	-- sonar pings and jammer domes (C-211)
	SensorFxRender.step(sensorFx, world, now, not strategic)
	-- reclaim zones for workers and the wreck under the mouse (C-216)
	WreckInfo.step(wreckInfo, world, api.state.selection, cam, now, Controls.hover(), game:GetService("UserInputService"):GetMouseLocation())
	mark("bars", t0)
	t0 = os.clock()
	-- fog of war (the blanket, C-100), radar / sonar contacts and ghosts (C-32); before `died` is cleared
	-- the radar layer (C-207): looked up a few times a second
	radarAt += dt
	if radarAt >= 0.25 then
		radarAt = 0
		radarCircles = if RadarFill.ENABLED and world.joined and world.me.player ~= 0 then RadarFill.circles(world, api.state.placement, api.state.selection, missileView.enabled) else nil
	end
	-- a baked map's mesh ground finished loading: the blanket again, over its rock details (C-213)
	local groundNow = Ground.last
	if groundNow and groundNow.mesh and fogGround ~= groundNow and world.layers then
		fogGround = groundNow
		FogBlanket.setMap(fog, world, world.layers)
	end
	FogBlanket.step(fog, world, dt, not (world.joined and world.me.player == 0), radarCircles)
	Contacts.step(contacts, world, now, strategic)
	mark("fog", t0)
	t0 = os.clock()
	MinimapUI.setFog(minimap, FogBlanket.content(fog), (FogBlanket.ENABLED or radarCircles ~= nil) and not (world.joined and world.me.player == 0))
	MinimapUI.step(minimap, api, now)
	ResourceBar.step(resourceBar, api, now)
	if now >= nextIdleCount then
		nextIdleCount = now + 0.25
		Idle.update(idle, world)
	end
	IdleStrip.step(idleStrip, #idle.builders, #idle.factories, SettingsMenu.binds.idle or "")
	IdleMarks.step(idleMarks, world, idle.builders, strategic, workspace.CurrentCamera)
	IdleMarks.countdowns(idleMarks, world, world.shownTick or world.latestTick, strategic, workspace.CurrentCamera)
	CommanderNames.step(commanderNames, world, strategic, workspace.CurrentCamera)
	TeamPanel.step(teamPanel, api, now)
	PregameMarks.step(pregameMarks, world, Pregame.areas(world), if pg.active then Controls.hover() else nil, workspace.CurrentCamera)
	PregamePanel.step(pregamePanel, world, now)
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

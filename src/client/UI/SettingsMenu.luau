--!strict
-- Settings menu (C-81; on the UI kit in C-105; BAR's layout in C-202,
-- references 4–5): O or the "Settings" button (top right) opens a panel
-- built by Kit.options: a search box across the top, "Unfold all" and
-- "Advanced" switches, a sidebar of sections with the chosen one's
-- sub-sections (amber bar on the one in view), amber sub-section headers,
-- right-aligned controls, child rows indented under a fold arrow, and the
-- hovered option's help in the footer.
--   Graphics   Quality (dropdown; unfold for what it caps) · Models
--              (detailed models, glow) · Lighting (fog of war
--              shading, headlights)
--   Interface  Scale (UI scale) · Building (build grid) · Developer
--              (Advanced: developer mode and its keys, dimmed while off)
--   Control    Camera (pan speed, zoom step (Advanced), edge scroll)
--   Keys       every single-key action with a button to rebind it (C-159:
--              click, press the new key; Escape cancels), a warning on keys
--              two actions share, Reset to defaults, then the fixed keys
--              (mouse, groups, modifiers) as tables; saved per player on
--              the server (the Keybinds remote)
--   Audio      nothing yet (the game has no sound)
-- Built once and shown or hidden; modal (a dark scrim behind, a click on
-- it closes the panel). Values come from Core/Settings; `apply` writes
-- them into the modules that use them, live. Settings last for this
-- session, as before.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Camera = require("../Camera")
local Effects = require("../Core/Effects")
local PieceAnim = require("../Core/PieceAnim")
local Keybinds = require("../Core/Keybinds")
local Settings = require("../Core/Settings")
local Controls = require("../Input/Controls")
local Deposits = require("../Render/Deposits")
local RenderMissileView = require("../Render/MissileView")
local RangeOverlay = require("../Render/RangeOverlay")
local BuildMenuUI = require("./BuildMenu")
local Atmosphere = require("../Render/Atmosphere")
local FogBlanket = require("../Render/FogBlanket")
local Environment = require("../Render/Environment")
local Glow = require("../Render/Glow")
local Models = require("../Render/Models")
local PlacementGhost = require("../Render/PlacementGhost")
local Vfx = require("../Render/Vfx")
local Kit = require("./Kit")

local SettingsMenu = {}
SettingsMenu.state = nil :: Settings.State? -- the live settings once the menu exists (developer mode keys, C-124)

SettingsMenu.binds = Keybinds.defaults() -- the player's keys (C-159)
SettingsMenu.capturing = false -- waiting for a key to bind: the game ignores keys
SettingsMenu.openButton = nil :: TextButton? -- its label names the key
SettingsMenu.menu = nil :: Frame? -- the top-right text menu (C-203)

-- Adds a flat text item to the top-right menu (left to right by `order`).
function SettingsMenu.addMenuItem(text: string, order: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 26)
	b.FontFace = Kit.font(Enum.FontWeight.Medium)
	b.TextSize = 13
	b.TextColor3 = Kit.COLOR.dim
	b.Text = text
	b.LayoutOrder = order
	b.Parent = SettingsMenu.menu
	b.MouseEnter:Connect(function()
		b.TextColor3 = Kit.COLOR.text
	end)
	b.MouseLeave:Connect(function()
		b.TextColor3 = Kit.COLOR.dim
	end)
	b.MouseButton1Click:Connect(onClick)
	return b
end

-- The KeyCode bound to action `id` (Core/Keybinds).
function SettingsMenu.key(id: string): Enum.KeyCode
	local name = SettingsMenu.binds[id]
	local ok, code = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok and code then code else Enum.KeyCode.Unknown
end

-- Writes the bindings into the modules that read keys.
function SettingsMenu.applyKeys()
	local k = SettingsMenu.key
	Controls.COMMAND_KEYS = {
		[k("attack")] = "attack",
		[k("fight")] = "fight",
		[k("move")] = "move",
		[k("patrol")] = "patrol",
		[k("guard")] = "guard",
		[k("reclaim")] = "reclaim",
		[k("resurrect")] = "resurrect",
	}
	Controls.STOP_KEY = k("stop")
	Controls.ROTATE_KEY = k("rotate")
	Controls.FIRE_STATE_KEY = k("fireState")
	Controls.MOVE_STATE_KEY = k("moveState")
	Controls.REPEAT_KEY = k("repeat")
	Controls.TOGGLE_KEY = k("toggle")
	Controls.CANCEL_KEY = k("cancel")
	Controls.ALERT_KEY = k("lastAlert")
	BuildMenuUI.KEY = k("build")
	BuildMenuUI.TAB_KEYS = { Economy = k("tabEconomy"), Combat = k("tabCombat"), Utility = k("tabUtility"), Build = k("tabBuild") }
	Camera.ROTATE_LEFT = k("rotateLeft")
	Camera.ROTATE_RIGHT = k("rotateRight")
	RangeOverlay.TOGGLE_KEY = k("ranges")
	RenderMissileView.TOGGLE_KEY = k("missileView")
	Deposits.TOGGLE_KEY = k("deposits")
	local open = SettingsMenu.openButton
	if open then
		open.Text = `Settings ({SettingsMenu.binds.settings})`
	end
end

local function remote(): RemoteFunction?
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local r = remotes and remotes:FindFirstChild("Keybinds")
	return if r and r:IsA("RemoteFunction") then r else nil
end

local function saveKeys()
	local r = remote()
	if r then
		local text = Keybinds.encode(SettingsMenu.binds)
		task.spawn(function()
			pcall(function()
				r:InvokeServer("set", text)
			end)
		end)
	end
end
-- the screens the UI scale applies to: the panels; overlays drawn at world
-- positions (icons, health bars, the selection box, missile labels) and
-- Roblox's own screens keep screen pixels
local SCALED = { SettingsButton = true, BuildTooltip = true, CheatConsole = true, Minimap = true, ResourceBar = true, BuildMenu = true, CommandCard = true, UnitPanel = true, Alerts = true, Lobby = true, Replay = true, Settings = true, NukeWarning = true, DebugHud = true }
export type UI = { gui: ScreenGui, panel: Kit.Panel, options: Kit.Options, state: Settings.State, refreshKeys: (() -> ())? }

-- Writes the settings into the modules that read them.
function SettingsMenu.apply(s: Settings.State)
	Camera.PAN_SPEED = s.panSpeed
	Camera.ZOOM_STEP = s.zoomStep
	Camera.EDGE_SCROLL = s.edgeScroll
	local g = Settings.graphics(s)
	Effects.MAX_EXPLOSIONS = g.explosions
	Effects.MAX_TRACERS = g.tracers
	Effects.MAX_PROJECTILES = g.projectiles
	Vfx.MAX_LIGHTS = g.lights
	Glow.MAX_HEADLIGHTS = g.lights
	Vfx.TEMPLATE_CAP = g.copies
	PieceAnim.NEAR = g.detailNear
	PieceAnim.MID = g.detailMid
	FogBlanket.ENABLED = s.fog
	Environment.AMBIENT = s.quality ~= "low"
	Glow.LEVEL = s.glow
	Glow.HEADLIGHTS = s.headlights
	Models.setDetailed(s.detailedModels)
	PlacementGhost.GRID = s.buildGrid
	Atmosphere.apply("map") -- every map's own lighting and time of day (Core/MapLook; no choice since C-243)
	local playerGui = (Players.LocalPlayer :: Player):FindFirstChild("PlayerGui")
	for _, gui in (if playerGui then playerGui:GetChildren() else {}) do
		if gui:IsA("ScreenGui") and SCALED[gui.Name] then
			local scale = gui:FindFirstChild("SettingsScale") :: UIScale?
			if scale == nil then
				local made = Instance.new("UIScale")
				made.Name = "SettingsScale"
				made.Parent = gui
				scale = made
			end
			local sc = scale :: UIScale
			sc.Scale = s.uiScale
		end
	end
end

local function cap(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

-- Dropdown choices: each value with its capitalised label.
local function choices(values: { string }): { { string } }
	local out = {}
	for _, v in values do
		table.insert(out, { v, cap(v) })
	end
	return out
end

-- A read-only value on the right of a row (the quality's caps).
local function readout(control: Frame, text: string): TextLabel
	local l = Kit.text(control, text, "label", Kit.COLOR.dim)
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.Size = UDim2.fromScale(1, 1)
	return l
end

-- The settings as a Kit.options spec (C-202: BAR references 4–5).
local function sections(ui: UI, changed: () -> ()): { Kit.OptionSection }
	local s = ui.state
	local function set(key: string, value: any)
		Settings.set(s, key, value)
		SettingsMenu.apply(s)
		changed()
	end
	local caps: { [string]: TextLabel } = {}
	local function showCaps()
		local g = Settings.graphics(s)
		if caps.effects then
			caps.effects.Text = `{g.explosions} explosions · {g.tracers} tracers · {g.projectiles} projectiles`
			caps.lights.Text = `{g.lights} lights · {g.copies} copies of one effect`
			caps.detail.Text = `full within {g.detailNear} studs, reduced to {g.detailMid}`
		end
	end
	local panL, zoomL, scaleL = Settings.LIMITS.panSpeed, Settings.LIMITS.zoomStep, Settings.LIMITS.uiScale

	local graphics: Kit.OptionSection = { name = "Graphics", subs = {
		{ name = "Quality", options = {
			{ id = "quality", label = "Quality", folded = true, keywords = "low medium high performance",
				help = "How many effects are drawn at once and how far units animate in full. Unfold it to see what each level caps.",
				build = function(c)
					Kit.dropdown(c, choices(Settings.QUALITIES), s.quality, function(q)
						set("quality", q)
						showCaps()
					end, 170)
				end },
			{ id = "qualityEffects", label = "Effects", parent = "quality", help = "Explosions, tracers and shells drawn at the same time; the oldest give way.",
				build = function(c)
					caps.effects = readout(c, "")
				end },
			{ id = "qualityLights", label = "Lights", parent = "quality", help = "Point lights from effects and headlights, and copies of one effect template.",
				build = function(c)
					caps.lights = readout(c, "")
				end },
			{ id = "qualityDetail", label = "Animation", parent = "quality", help = "Turrets, treads and pieces animate in full near the camera, less farther out, not at all beyond.",
				build = function(c)
					caps.detail = readout(c, "")
				end },
		} },
		{ name = "Models", options = {
			{ id = "detailedModels", label = "Detailed models", keywords = "mesh blockout", help = "The detailed unit models. Off: simple blockouts, nothing to load.",
				build = function(c)
					Kit.toggle(c, s.detailedModels, function(on)
						set("detailedModels", on)
					end)
				end },
			{ id = "glow", label = "Glow", keywords = "neon lights", help = "Off; Low: resting glow and stall dimming; High: also factory pulses and weapon flashes.",
				build = function(c)
					Kit.dropdown(c, choices(Settings.GLOWS), s.glow, function(g)
						set("glow", g)
					end, 170)
				end },
		} },
		{ name = "Lighting", options = {
			{ id = "fog", label = "Fog of war shading", keywords = "fog vision", help = "Darkens ground you can't see. What is hidden stays hidden either way.",
				build = function(c)
					Kit.toggle(c, s.fog, function(on)
						set("fog", on)
					end)
				end },
			{ id = "headlights", label = "Headlights", help = "Vehicle headlights near the camera, and at night or dusk.",
				build = function(c)
					Kit.toggle(c, s.headlights, function(on)
						set("headlights", on)
					end)
				end },
		} },
	} }

	local interface: Kit.OptionSection = { name = "Interface", subs = {
		{ name = "Scale", options = {
			{ id = "uiScale", label = "UI scale", keywords = "size", help = "The size of every panel and the HUD. Icons and health bars over units keep their size.",
				build = function(c)
					Kit.slider(c, scaleL[1], scaleL[2], scaleL[3], s.uiScale, "%.1f", function(v)
						set("uiScale", v)
					end)
				end },
		} },
		{ name = "Building", options = {
			{ id = "buildGrid", label = "Build grid", keywords = "placement ghost", help = "A fine grid round the placement ghost while you place a building.",
				build = function(c)
					Kit.toggle(c, s.buildGrid, function(on)
						set("buildGrid", on)
					end)
				end },
		} },
		{ name = "Developer", options = {
			{ id = "devMode", label = "Developer mode", advanced = true, keywords = "debug", help = "Debug keys for testing. On in Studio.",
				isOn = function()
					return s.devMode
				end,
				build = function(c)
					Kit.toggle(c, s.devMode, function(on)
						set("devMode", on)
					end)
				end },
			{ id = "devFollow", label = "T", parent = "devMode", advanced = true, help = "Developer mode: the camera follows the selected unit.",
				build = function(c)
					readout(c, "camera follows the selected unit")
				end },
			{ id = "devReadout", label = "F3", parent = "devMode", advanced = true, help = "Developer mode: the debug readout (frame times, counts).",
				build = function(c)
					readout(c, "debug readout")
				end },
		} },
	} }

	local control: Kit.OptionSection = { name = "Control", subs = {
		{ name = "Camera", options = {
			{ id = "panSpeed", label = "Pan speed", keywords = "scroll camera", help = "Screen heights per second with the arrow keys or the screen edge.",
				build = function(c)
					Kit.slider(c, panL[1], panL[2], panL[3], s.panSpeed, "%.1f", function(v)
						set("panSpeed", v)
					end)
				end },
			{ id = "zoomStep", label = "Zoom step", advanced = true, keywords = "wheel camera", help = "How far one wheel notch zooms.",
				build = function(c)
					Kit.slider(c, zoomL[1], zoomL[2], zoomL[3], s.zoomStep, "%.2f", function(v)
						set("zoomStep", v)
					end)
				end },
			{ id = "edgeScroll", label = "Edge scroll", keywords = "mouse camera", help = "Pan when the mouse rests on the screen edge. Off in Studio, where the mouse often sits on the window edge.",
				build = function(c)
					Kit.toggle(c, s.edgeScroll, function(on)
						set("edgeScroll", on)
					end)
				end },
		} },
	} }

	-- keys (C-159): every single-key action, then the fixed keys
	local keys: Kit.OptionSection = { name = "Keys", subs = {} }
	local buttons: { [string]: TextButton } = {}
	local warnings: { [string]: TextLabel } = {}
	local waiting: string? = nil
	local function refresh()
		local clashes = Keybinds.conflicts(SettingsMenu.binds)
		for id, b in buttons do
			b.Text = if waiting == id then "Press a key…" else SettingsMenu.binds[id]
			local others = clashes[id]
			local w = warnings[id]
			if others then
				local names = {}
				for _, o in others do
					table.insert(names, Keybinds.label(o))
				end
				w.Text = "also: " .. table.concat(names, ", ")
				w.Visible = true
			else
				w.Visible = false
			end
		end
	end
	ui.refreshKeys = refresh
	local KEY_HELP = "Click, then press the new key (Escape cancels). Saved for your account."
	local current: { name: string, options: { Kit.OptionDef } }? = nil
	for _, a in Keybinds.ACTIONS do
		if current == nil or current.name ~= a.group then
			current = { name = a.group, options = {} }
			table.insert(keys.subs, current :: any)
		end
		table.insert((current :: any).options, {
			id = "key_" .. a.id,
			label = a.label,
			keywords = a.default .. " key bind",
			help = KEY_HELP,
			hint = `default {a.default}`,
			build = function(c)
				local warn = Kit.text(c, "", "small", Kit.COLOR.defeat)
				warn.Size = UDim2.new(1, -104, 1, 0)
				warn.TextXAlignment = Enum.TextXAlignment.Right
				warn.TextTruncate = Enum.TextTruncate.AtEnd
				warn.LayoutOrder = 1
				warn.Visible = false
				warnings[a.id] = warn
				local b = Kit.button(c, a.default, nil, function()
					waiting = if waiting == a.id then nil else a.id
					SettingsMenu.capturing = waiting ~= nil
					refresh()
				end, 96)
				b.LayoutOrder = 2
				buttons[a.id] = b
			end,
		})
	end
	table.insert(keys.subs, { name = "Reset", options = {
		{ id = "keysReset", label = "Every key", keywords = "default", help = "Puts every key back to its default.",
			build = function(c)
				Kit.button(c, "Reset to defaults", nil, function()
					SettingsMenu.binds = Keybinds.defaults()
					waiting = nil
					SettingsMenu.applyKeys()
					saveKeys()
					refresh()
				end, 160)
			end },
	} })
	for i, g in Settings.KEYS do
		local rows = {}
		local words = {}
		for _, k in g[2] do
			table.insert(rows, { k[1], k[2] })
			table.insert(words, k[1] .. " " .. k[2])
		end
		table.insert(keys.subs, { name = g[1], options = {
			{ id = `fixedKeys{i}`, label = g[1], wide = true, height = (#rows + 1) * 28, keywords = table.concat(words, " "), help = "Fixed keys: mouse, groups and modifiers.",
				build = function(c)
					local t = Kit.table(c, { { title = "Key", width = 0.36 }, { title = "Action", width = 0.64 } }, rows, 28)
					t.Size = UDim2.fromScale(1, 1)
				end },
		} })
	end
	UserInputService.InputBegan:Connect(function(input: InputObject)
		local id = waiting
		if id == nil or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		waiting = nil
		if input.KeyCode ~= Enum.KeyCode.Escape and Keybinds.set(SettingsMenu.binds, id, input.KeyCode.Name) then
			SettingsMenu.applyKeys()
			saveKeys()
		end
		refresh()
		-- the other key handlers see this press as captured too
		task.defer(function()
			SettingsMenu.capturing = waiting ~= nil
		end)
	end)

	local audio: Kit.OptionSection = { name = "Audio", subs = {
		{ name = "Volume", options = {
			{ id = "noSound", label = "Sound", wide = true, help = "Volume controls come with the game's sound.",
				build = function(c)
					local l = Kit.text(c, "The game has no sound yet; volume controls come with it.", "small")
					l.Size = UDim2.fromScale(1, 1)
				end },
		} },
	} }

	task.defer(function()
		showCaps()
		refresh()
	end)
	return { graphics, interface, control, keys, audio }
end

function SettingsMenu.new(): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Settings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 110 -- modal: over every HUD screen and the debug overlay (C-106)
	gui.IgnoreGuiInset = true
	-- the open button lives with the HUD (under other modal panels); the panel's gui is on top
	local buttonGui = Instance.new("ScreenGui")
	buttonGui.Name = "SettingsButton"
	buttonGui.ResetOnSpawn = false
	buttonGui.DisplayOrder = 6
	buttonGui.IgnoreGuiInset = true
	buttonGui.IgnoreGuiInset = true
	-- BAR's flat text menu in the upper right corner (reference 3, C-203;
	-- a Settings button there since C-124)
	local strip = Instance.new("Frame")
	strip.Name = "Menu"
	strip.AnchorPoint = Vector2.new(1, 0)
	strip.Position = UDim2.new(1, -8, 0, 6)
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Size = UDim2.fromOffset(0, 26)
	strip.BackgroundColor3 = Kit.COLOR.panel
	strip.BackgroundTransparency = 0.35
	strip.BorderSizePixel = 0
	strip.Parent = buttonGui
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, 4)
	sc.Parent = strip
	Kit.pad(strip, Kit.SPACE.s, 0, Kit.SPACE.s, 0)
	Kit.list(strip, Kit.SPACE.m, true)
	SettingsMenu.menu = strip
	local open = SettingsMenu.addMenuItem("Settings (O)", 100, function() end)
	open.Name = "Open"
	SettingsMenu.openButton = open
	local panel = Kit.panel(gui, "Settings", Vector2.new(940, 620))
	panel.root.Visible = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	buttonGui.Parent = gui.Parent
	local ui: UI = { gui = gui, panel = panel, options = nil :: any, state = Settings.new(RunService:IsStudio()) }
	SettingsMenu.state = ui.state -- read by key handlers made before the menu (developer mode)
	ui.options = Kit.options(panel, sections(ui, function()
		ui.options.refresh() -- a parent switched off dims its children
	end))
	local function toggle()
		panel.root.Visible = not panel.root.Visible
	end
	open.MouseButton1Click:Connect(toggle)
	SettingsMenu.addMenuItem("Keys", 90, function()
		ui.options.search.Text = ""
		ui.options.select("Keys")
		panel.root.Visible = true
	end)
	panel.scrim.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			panel.root.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and not SettingsMenu.capturing and input.KeyCode == SettingsMenu.key("settings") then
			toggle()
		end
	end)
	SettingsMenu.apply(ui.state)
	SettingsMenu.applyKeys()
	-- the player's saved keys (C-159), once the server answers
	task.spawn(function()
		local r = remote()
		local wait = 0
		while r == nil and wait < 10 do
			task.wait(0.5)
			wait += 0.5
			r = remote()
		end
		if r then
			local ok, text = pcall(function()
				return r:InvokeServer("get")
			end)
			if ok and type(text) == "string" and text ~= "" then
				SettingsMenu.binds = Keybinds.decode(text)
				SettingsMenu.applyKeys()
				if ui.refreshKeys then
					ui.refreshKeys()
				end
			end
		end
	end)
	-- screens made later (the replay bar, a lobby) get the scale too
	gui.Parent.ChildAdded:Connect(function(child: Instance)
		if child:IsA("ScreenGui") then
			SettingsMenu.apply(ui.state)
		end
	end)
	return ui
end

return SettingsMenu

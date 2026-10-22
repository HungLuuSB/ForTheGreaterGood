--!strict
-- Settings menu (C-81; rebuilt on the UI kit in C-105): O or the
-- "Settings" button (bottom right) opens a panel with a sidebar:
--   Camera     pan speed and zoom step sliders, edge scroll toggle
--   Graphics   quality (segmented Low / Medium / High, with what it caps),
--              fog of war toggle, atmosphere dropdown, detailed models
--              toggle, glow (Off / Low / High), headlights toggle (C-106)
--   Interface  UI scale slider
--   Audio      nothing yet (the game has no sound)
--   Keys       the key bindings as a two-column table per group
-- Built once and shown or hidden; modal (a dark scrim behind, a click on
-- it closes the panel), and the panel's height follows the page (C-106). Values come from Core/Settings; `apply`
-- writes them into the modules that use them, live. Settings last for
-- this session, as before.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Camera = require("../Camera")
local Effects = require("../Core/Effects")
local PieceAnim = require("../Core/PieceAnim")
local Settings = require("../Core/Settings")
local Atmosphere = require("../Render/Atmosphere")
local FogBlanket = require("../Render/FogBlanket")
local Environment = require("../Render/Environment")
local Glow = require("../Render/Glow")
local Models = require("../Render/Models")
local Vfx = require("../Render/Vfx")
local Kit = require("./Kit")

local SettingsMenu = {}
SettingsMenu.state = nil :: Settings.State? -- the live settings once the menu exists (developer mode keys, C-124)

local KEY = Enum.KeyCode.O
-- the screens the UI scale applies to: the panels; overlays drawn at world
-- positions (icons, health bars, the selection box, missile labels) and
-- Roblox's own screens keep screen pixels
local SCALED = { SettingsButton = true, BuildTooltip = true, CheatConsole = true, Minimap = true, ResourceBar = true, BuildMenu = true, CommandCard = true, UnitPanel = true, Alerts = true, Lobby = true, Replay = true, Settings = true, NukeWarning = true, DebugHud = true }
local PAGES = { "Camera", "Graphics", "Interface", "Audio", "Keys" }

export type UI = { gui: ScreenGui, panel: Kit.Panel, pages: { [string]: ScrollingFrame }, layouts: { [string]: UIListLayout }, state: Settings.State }

local SIDEBAR_HEIGHT = 280 -- the sidebar's five sections need this much panel

-- The panel's height for page `name`: its content, at least the sidebar.
local function fitPage(ui: UI, name: string)
	local layout = ui.layouts[name]
	if layout then
		ui.panel.setHeight(math.max(SIDEBAR_HEIGHT, layout.AbsoluteContentSize.Y + 2 * Kit.SPACE.l + Kit.SPACE.s))
	end
end

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
	Atmosphere.apply(s.atmosphere)
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

local function capsText(s: Settings.State): string
	local g = Settings.graphics(s)
	return string.format("Up to %d explosions, %d tracers, %d projectiles and %d lights; full animation within %d studs.", g.explosions, g.tracers, g.projectiles, g.lights, g.detailNear)
end

-- Builds every page once.
local function build(ui: UI)
	local s = ui.state
	local function set(key: string, value: any)
		Settings.set(s, key, value)
		SettingsMenu.apply(s)
	end
	local function page(name: string): ScrollingFrame
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Visible = false
		holder.Parent = ui.panel.content
		local sc = Kit.scroll(holder)
		local layout = Kit.list(sc, Kit.SPACE.xs)
		ui.layouts[name] = layout
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if ui.panel.selected == name then
				fitPage(ui, name)
			end
		end)
		Kit.pad(sc, 0, 0, Kit.SPACE.m, 0)
		ui.pages[name] = sc
		Kit.section(sc, name, 0)
		return sc
	end

	local cam = page("Camera")
	local panL = Settings.LIMITS.panSpeed
	Kit.slider(Kit.row(cam, "Pan speed", 1), panL[1], panL[2], panL[3], s.panSpeed, "%.1f", function(v)
		set("panSpeed", v)
	end)
	local zoomL = Settings.LIMITS.zoomStep
	Kit.slider(Kit.row(cam, "Zoom step", 2), zoomL[1], zoomL[2], zoomL[3], s.zoomStep, "%.2f", function(v)
		set("zoomStep", v)
	end)
	Kit.toggle(Kit.row(cam, "Edge scroll", 3), s.edgeScroll, function(on)
		set("edgeScroll", on)
	end)

	local gfx = page("Graphics")
	local info: TextLabel
	local qualities = {}
	for _, q in Settings.QUALITIES do
		table.insert(qualities, { q, cap(q) })
	end
	Kit.segmented(Kit.row(gfx, "Quality", 1), qualities, s.quality, function(q)
		set("quality", q)
		info.Text = capsText(s)
	end)
	info = Kit.text(gfx, capsText(s), "small")
	info.LayoutOrder = 2
	info.TextWrapped = true
	info.Size = UDim2.new(1, 0, 0, 22)
	Kit.toggle(Kit.row(gfx, "Fog of war", 3), s.fog, function(on)
		set("fog", on)
	end)
	local atmospheres = {}
	for _, name in Settings.ATMOSPHERES do
		table.insert(atmospheres, { name, Atmosphere.NAMES[name] or name })
	end
	Kit.dropdown(Kit.row(gfx, "Atmosphere", 4), atmospheres, s.atmosphere, function(name)
		set("atmosphere", name)
	end, 190)
	Kit.toggle(Kit.row(gfx, "Detailed models", 5), s.detailedModels, function(on)
		set("detailedModels", on)
	end)
	local glows = {}
	for _, g in Settings.GLOWS do
		table.insert(glows, { g, cap(g) })
	end
	Kit.segmented(Kit.row(gfx, "Glow", 6), glows, s.glow, function(g)
		set("glow", g)
	end, 70)
	Kit.toggle(Kit.row(gfx, "Headlights", 7), s.headlights, function(on)
		set("headlights", on)
	end)

	local ifc = page("Interface")
	local scaleL = Settings.LIMITS.uiScale
	Kit.slider(Kit.row(ifc, "UI scale", 1), scaleL[1], scaleL[2], scaleL[3], s.uiScale, "%.1f", function(v)
		set("uiScale", v)
	end)
	-- developer mode (C-124): debug keys such as T (camera follow)
	Kit.toggle(Kit.row(ifc, "Developer mode", 2), s.devMode, function(on)
		set("devMode", on)
	end)
	local note = Kit.text(ifc, "Settings last for this session.", "small")
	note.LayoutOrder = 3

	local audio = page("Audio")
	local none = Kit.text(audio, "The game has no sound yet; volume controls come with it.", "small")
	none.LayoutOrder = 1

	local keys = page("Keys")
	for i, group in Settings.KEYS do
		local head = Kit.text(keys, group[1], "label", Kit.COLOR.accent)
		head.LayoutOrder = i * 2 - 1
		head.Size = UDim2.new(1, 0, 0, 26)
		local rows = {}
		for _, k in group[2] do
			table.insert(rows, { k[1], k[2] })
		end
		Kit.table(keys, { { title = "Key", width = 0.36 }, { title = "Action", width = 0.64 } }, rows, 28, i * 2)
	end
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
	local open = Kit.button(buttonGui, "Settings (O)", "ghost", function() end, 116)
	open.Name = "Open"
	open.Size = UDim2.fromOffset(116, 28)
	-- the upper right corner (C-124, the user; the upper left until then, C-109)
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -8, 0, 6)
	open.TextSize = 13
	local ui: UI
	local panel = Kit.panel(gui, "Settings", Vector2.new(780, 500), PAGES, function(name)
		for n, p in ui.pages do
			(p.Parent :: Frame).Visible = n == name
		end
		fitPage(ui, name)
	end)
	panel.root.Visible = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	buttonGui.Parent = gui.Parent
	ui = { gui = gui, panel = panel, pages = {}, layouts = {}, state = Settings.new(RunService:IsStudio()) }
	SettingsMenu.state = ui.state -- read by key handlers made before the menu (developer mode)
	build(ui)
	panel.select("Camera")
	local function toggle()
		panel.root.Visible = not panel.root.Visible
	end
	open.MouseButton1Click:Connect(toggle)
	panel.scrim.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			panel.root.Visible = false
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == KEY then
			toggle()
		end
	end)
	SettingsMenu.apply(ui.state)
	-- screens made later (the replay bar, a lobby) get the scale too
	gui.Parent.ChildAdded:Connect(function(child: Instance)
		if child:IsA("ScreenGui") then
			SettingsMenu.apply(ui.state)
		end
	end)
	return ui
end

return SettingsMenu

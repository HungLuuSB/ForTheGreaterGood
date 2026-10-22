--!strict
-- Settings menu (C-81; rebuilt on the UI kit in C-105): O or the
-- "Settings" button (bottom right) opens a panel with a sidebar:
--   Camera     pan speed and zoom step sliders, edge scroll toggle
--   Graphics   quality (segmented Low / Medium / High, with what it caps),
--              fog of war toggle, atmosphere dropdown
--   Interface  UI scale slider
--   Audio      nothing yet (the game has no sound)
--   Keys       the key bindings as a two-column table per group
-- Built once and shown or hidden. Values come from Core/Settings; `apply`
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
local Vfx = require("../Render/Vfx")
local Kit = require("./Kit")

local SettingsMenu = {}

local KEY = Enum.KeyCode.O
-- the screens the UI scale applies to: the panels; overlays drawn at world
-- positions (icons, health bars, the selection box, missile labels) and
-- Roblox's own screens keep screen pixels
local SCALED = { Minimap = true, ResourceBar = true, BuildMenu = true, CommandCard = true, UnitPanel = true, Alerts = true, Lobby = true, Replay = true, Settings = true, FollowButton = true, NukeWarning = true, DebugHud = true }
local PAGES = { "Camera", "Graphics", "Interface", "Audio", "Keys" }

export type UI = { gui: ScreenGui, panel: Kit.Panel, pages: { [string]: ScrollingFrame }, state: Settings.State }

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
		Kit.list(sc, Kit.SPACE.xs)
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

	local ifc = page("Interface")
	local scaleL = Settings.LIMITS.uiScale
	Kit.slider(Kit.row(ifc, "UI scale", 1), scaleL[1], scaleL[2], scaleL[3], s.uiScale, "%.1f", function(v)
		set("uiScale", v)
	end)
	local note = Kit.text(ifc, "Settings last for this session.", "small")
	note.LayoutOrder = 2

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
	gui.DisplayOrder = 40
	gui.IgnoreGuiInset = true
	local open = Kit.button(gui, "Settings (O)", "ghost", function() end, 116)
	open.Name = "Open"
	open.AnchorPoint = Vector2.new(1, 1)
	open.Position = UDim2.new(1, -8, 1, -40) -- above the follow button
	open.Size = UDim2.fromOffset(116, 26)
	open.TextSize = 13
	local ui: UI
	local panel = Kit.panel(gui, "Settings", Vector2.new(780, 500), PAGES, function(name)
		for n, p in ui.pages do
			(p.Parent :: Frame).Visible = n == name
		end
	end)
	panel.root.Visible = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	ui = { gui = gui, panel = panel, pages = {}, state = Settings.new(RunService:IsStudio()) }
	build(ui)
	panel.select("Camera")
	local function toggle()
		panel.root.Visible = not panel.root.Visible
	end
	open.MouseButton1Click:Connect(toggle)
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

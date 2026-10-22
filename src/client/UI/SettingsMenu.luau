--!strict
-- Settings menu (C-81), a functional PLACEHOLDER: O or the "Settings"
-- button (bottom right) opens a panel with the key bindings reference,
-- camera (pan speed, zoom step, edge scroll), graphics (quality Low /
-- Medium / High, fog of war, atmosphere preset) and the UI scale. Values come from
-- Core/Settings; `apply` writes them into the modules that use them, live.

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
local Vfx = require("../Render/Vfx")

local SettingsMenu = {}

local BG = Color3.fromRGB(16, 18, 22)
local BTN = Color3.fromRGB(44, 50, 60)
local ON = Color3.fromRGB(70, 110, 160)
local KEY = Enum.KeyCode.O
-- the screens the UI scale applies to: the panels; overlays drawn at world
-- positions (icons, health bars, the selection box, missile labels) and
-- Roblox's own screens keep screen pixels
local SCALED = { Minimap = true, ResourceBar = true, BuildMenu = true, CommandCard = true, UnitPanel = true, Alerts = true, Lobby = true, Replay = true, Settings = true, FollowButton = true, NukeWarning = true, DebugHud = true }

export type UI = { gui: ScreenGui, panel: Frame, body: ScrollingFrame, state: Settings.State }

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

local function label(parent: Instance, text: string, size: number, w: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = if w then UDim2.fromOffset(w, size + 10) else UDim2.new(1, 0, 0, size + 8)
	l.Font = if size >= 14 then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.LayoutOrder = #parent:GetChildren()
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, w: number, on: boolean, click: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 24)
	b.BackgroundColor3 = if on then ON else BTN
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = #parent:GetChildren()
	b.Parent = parent
	b.MouseButton1Click:Connect(click)
	return b
end

local function row(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 26)
	f.LayoutOrder = #parent:GetChildren()
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	label(f, name, 12, 130).TextColor3 = Color3.fromRGB(200, 200, 200)
	return f
end

local render: (ui: UI) -> ()

local function stepper(ui: UI, parent: Instance, key: string, fmt: string)
	local s = ui.state :: any
	button(parent, "−", 26, false, function()
		Settings.nudge(ui.state, key, false)
		SettingsMenu.apply(ui.state)
		render(ui)
	end)
	label(parent, string.format(fmt, s[key]), 12, 60).TextXAlignment = Enum.TextXAlignment.Center
	button(parent, "+", 26, false, function()
		Settings.nudge(ui.state, key, true)
		SettingsMenu.apply(ui.state)
		render(ui)
	end)
end

render = function(ui: UI)
	for _, c in ui.body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local s = ui.state
	label(ui.body, "SETTINGS", 18)
	label(ui.body, "Camera", 14)
	stepper(ui, row(ui.body, "Pan speed"), "panSpeed", "%.1f")
	stepper(ui, row(ui.body, "Zoom step"), "zoomStep", "%.2f")
	local edge = row(ui.body, "Edge scroll")
	for _, v in { true, false } do
		button(edge, if v then "On" else "Off", 56, s.edgeScroll == v, function()
			Settings.set(ui.state, "edgeScroll", v)
			SettingsMenu.apply(ui.state)
			render(ui)
		end)
	end
	label(ui.body, "Graphics", 14)
	local q = row(ui.body, "Quality")
	for _, name in Settings.QUALITIES do
		button(q, string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2), 70, s.quality == name, function()
			Settings.set(ui.state, "quality", name)
			SettingsMenu.apply(ui.state)
			render(ui)
		end)
	end
	local g = Settings.graphics(s)
	label(ui.body, string.format("  up to %d explosions, %d tracers, %d projectiles, %d lights; full animation within %d studs", g.explosions, g.tracers, g.projectiles, g.lights, g.detailNear), 11).TextColor3 = Color3.fromRGB(170, 170, 170)
	local fog = row(ui.body, "Fog of war")
	for _, v in { true, false } do
		button(fog, if v then "On" else "Off", 56, s.fog == v, function()
			Settings.set(ui.state, "fog", v)
			SettingsMenu.apply(ui.state)
			render(ui)
		end)
	end
	local atm = row(ui.body, "Atmosphere")
	for _, name in Settings.ATMOSPHERES do
		button(atm, Atmosphere.NAMES[name] or name, 80, s.atmosphere == name, function() -- five fit in the row (C-102)
			Settings.set(ui.state, "atmosphere", name)
			SettingsMenu.apply(ui.state)
			render(ui)
		end)
	end
	label(ui.body, "Interface", 14)
	stepper(ui, row(ui.body, "UI scale"), "uiScale", "%.1f")
	label(ui.body, "Keys", 14)
	for _, group in Settings.KEYS do
		label(ui.body, group[1], 12).TextColor3 = Color3.fromRGB(255, 220, 120)
		for _, k in group[2] do
			local r = row(ui.body, k[1])
			label(r, k[2], 12, 380)
		end
	end
	label(ui.body, "Settings last for this session.", 11).TextColor3 = Color3.fromRGB(150, 150, 150)
end

function SettingsMenu.new(): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Settings"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.AnchorPoint = Vector2.new(1, 1)
	open.Position = UDim2.new(1, -8, 1, -40) -- above the follow button
	open.Size = UDim2.fromOffset(110, 24)
	open.BackgroundColor3 = BG
	open.BackgroundTransparency = 0.15
	open.BorderSizePixel = 0
	open.Font = Enum.Font.Gotham
	open.TextSize = 13
	open.TextColor3 = Color3.fromRGB(220, 220, 220)
	open.Text = "Settings (O)"
	open.Parent = gui
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(600, 440)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(14, 10)
	body.Size = UDim2.new(1, -20, 1, -16)
	body.ScrollBarThickness = 6
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local ui: UI = { gui = gui, panel = panel, body = body, state = Settings.new(RunService:IsStudio()) }
	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			render(ui)
		end
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

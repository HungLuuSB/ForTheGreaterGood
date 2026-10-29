--!strict
-- Resource bar (guide 15.7), BAR style (C-71): top center, a block per
-- resource: its symbol, demand (red) over income (green), the amount
-- stored (large), a thin fill bar of stored / storage with a stall tint,
-- and the storage. Then, as in BAR, the wind (what a wind turbine makes
-- now in the middle over a see-through turning fan, the map's min top
-- right and max bottom right: the user's sketch; S-177's layers.wind, no randomness) and the tidal (what a tidal generator makes). From
-- Api.state.economy (the Eco channel) and the map; reads only the client
-- API (C-5). A placeholder look for the UI session.
-- The levels (S-198, the user): on each bar a white marker, the share
-- level: stored above it is shared fairly with the allies, so dragging it
-- down gives the rest away; on the power bar an orange one, the converters'
-- level: power stored above it is what converters may use. Drag a marker
-- along its bar; letting go sends ECO_LEVEL. Hovering one says what it does.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Api = require("../Api")
local Schema = require("@shared/Net/Schema")
local UnitFlow = require("../Core/UnitFlow")
local Kit = require("./Kit")
local UiIcon = require("./UiIcon")

local ResourceBar = {}

local BG = Kit.COLOR.panel
local FILL = { Supply = Color3.fromRGB(200, 205, 215), Power = Color3.fromRGB(240, 210, 60) }
local SYMBOL = { Supply = "■", Power = "ϟ" } -- until the UI icon atlas is uploaded (C-259)
local ICON = { Supply = "supply", Power = "power" }
local STALL = Color3.fromRGB(230, 70, 60)

export type Marker = { handle: TextButton, level: number, block: string, help: string, dragging: number?, shown: number }
type Block = { demand: TextLabel, income: TextLabel, stored: TextLabel, storage: TextLabel, fill: Frame, back: Frame, markers: { [number]: Marker } }
export type Bar = { gui: ScreenGui, blocks: { [string]: Block }, markers: { Marker }, wind: TextLabel, windMin: TextLabel, windMax: TextLabel, fan: Frame, tidal: TextLabel, nextUpdate: number, spin: number, spinAt: number }

ResourceBar.WIND_W = 56 -- the wind box (the user: the current in the middle over a see-through fan, min top right, max bottom right)
ResourceBar.WIDTH = 2 * 270 + ResourceBar.WIND_W + 64 + 3 * 6 -- supply, power, wind, tidal (UI/IdleStrip sits right of it)
ResourceBar.FAN_RPM = 40 -- the fan's turns per minute at a turbine's max
local function short(n: number): string
	if n >= 10000 then
		return string.format("%.0fk", n / 1000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return string.format("%d", math.floor(n + 0.5))
end

local function text(parent: Instance, size: number, color: Color3, align: Enum.TextXAlignment, pos: UDim2, dim: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = align
	l.Position = pos
	l.Size = dim
	l.Text = ""
	l.Parent = parent
	return l
end

function ResourceBar.new(): Bar
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResourceBar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = true -- up in Roblox's top strip (C-109)
	local root = Instance.new("Frame")
	root.Name = "Bar"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 6)
	root.Size = UDim2.fromOffset(ResourceBar.WIDTH, 40)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root
	local blocks = {}
	for i, name in { "Supply", "Power" } do
		local b = Instance.new("Frame")
		b.Name = name
		b.LayoutOrder = i
		b.Size = UDim2.fromOffset(270, 40)
		b.BackgroundColor3 = BG
		b.BackgroundTransparency = 0.2
		b.BorderSizePixel = 0
		b.Parent = root
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = b
		local mark = text(b, 22, FILL[name], Enum.TextXAlignment.Center, UDim2.fromOffset(4, 6), UDim2.fromOffset(26, 26))
		local icon = UiIcon.make(ICON[name], 24, FILL[name])
		if icon then
			icon.Position = UDim2.fromOffset(5, 7)
			icon.Parent = b
		else
			mark.Text = SYMBOL[name]
		end
		local demand = text(b, 12, Color3.fromRGB(240, 90, 80), Enum.TextXAlignment.Left, UDim2.fromOffset(34, 4), UDim2.fromOffset(60, 14))
		local income = text(b, 12, Color3.fromRGB(110, 220, 110), Enum.TextXAlignment.Left, UDim2.fromOffset(34, 20), UDim2.fromOffset(60, 14))
		local stored = text(b, 17, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, UDim2.fromOffset(96, 2), UDim2.fromOffset(100, 20))
		local storage = text(b, 12, Color3.fromRGB(190, 190, 190), Enum.TextXAlignment.Right, UDim2.fromOffset(196, 4), UDim2.fromOffset(68, 14))
		local back = Instance.new("Frame")
		back.Name = "Back"
		back.Position = UDim2.fromOffset(96, 27)
		back.Size = UDim2.fromOffset(168, 6)
		back.BackgroundColor3 = Color3.fromRGB(45, 48, 54)
		back.BorderSizePixel = 0
		back.Parent = b
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = FILL[name]
		fill.BorderSizePixel = 0
		fill.Parent = back
		blocks[name] = { demand = demand, income = income, stored = stored, storage = storage, fill = fill, back = back, markers = {} }
	end
	-- the level markers: a thin bar across the fill, a wider invisible handle
	-- (the tip hangs off the screen, not the bar's row: in the row's list it
	-- pushed the blocks right while it showed)
	local tip = text(gui, 11, Color3.new(1, 1, 1), Enum.TextXAlignment.Center, UDim2.new(), UDim2.fromOffset(300, 16))
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.BackgroundColor3 = BG
	tip.BackgroundTransparency = 0.15
	tip.Visible = false
	tip.ZIndex = 5
	local function showTip(m: Marker, line: string)
		local h = m.handle
		local scale = gui:FindFirstChild("SettingsScale")
		local k = if scale and scale:IsA("UIScale") then scale.Scale else 1 -- (screen pixels → the scaled gui's)
		tip.Text = line
		-- AbsolutePosition counts from below Roblox's top bar, this gui from the
		-- screen's top (IgnoreGuiInset): add the inset back, or the tip sat a
		-- top bar's height too high, over the box (the user, C-263)
		local inset = game:GetService("GuiService"):GetGuiInset()
		tip.Position = UDim2.fromOffset((h.AbsolutePosition.X + inset.X + h.AbsoluteSize.X / 2) / k, (root.AbsolutePosition.Y + inset.Y + root.AbsoluteSize.Y) / k + 4)
		tip.Visible = true
	end
	local markers: { Marker } = {}
	local function marker(block: string, level: number, color: Color3, help: string)
		local b = blocks[block]
		local handle = Instance.new("TextButton")
		handle.Name = `Level{level}`
		handle.Text = ""
		handle.AutoButtonColor = false
		handle.BackgroundTransparency = 1
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
		handle.Size = UDim2.fromOffset(10, 16)
		handle.ZIndex = 4
		handle.Parent = b.back
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromOffset(3, 12)
		line.BackgroundColor3 = color
		line.BorderSizePixel = 0
		line.ZIndex = 4
		line.Parent = handle
		local m: Marker = { handle = handle, level = level, block = block, help = help, dragging = nil, shown = -1 }
		table.insert(markers, m)
		b.markers[level] = m
		handle.MouseButton1Down:Connect(function()
			m.dragging = m.shown
		end)
		handle.MouseEnter:Connect(function()
			showTip(m, help)
		end)
		handle.MouseLeave:Connect(function()
			tip.Visible = false
		end)
	end
	marker("Supply", Schema.EcoLevel.SUPPLY_SHARE, Color3.fromRGB(240, 240, 240), "Share level: supply stored above it goes to your allies")
	marker("Power", Schema.EcoLevel.POWER_SHARE, Color3.fromRGB(240, 240, 240), "Share level: power stored above it goes to your allies")
	marker("Power", Schema.EcoLevel.CONVERT, Color3.fromRGB(255, 150, 40), "Converter level: power stored above it runs your converters")
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		for _, m in markers do
			if m.dragging then
				local back = m.handle.Parent :: Frame
				local x = UserInputService:GetMouseLocation().X - back.AbsolutePosition.X
				m.dragging = math.clamp(math.floor(x / back.AbsoluteSize.X * 100 + 0.5), 0, 100)
				showTip(m, `{m.help}: {m.dragging}%`)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		for _, m in markers do
			if m.dragging then
				local api = ResourceBar.api
				if api then
					api.actions.setEcoLevel(m.level, m.dragging)
				end
				m.shown = m.dragging -- (held until the server's level comes back)
				m.dragging = nil
				tip.Visible = false
			end
		end
	end)
	local function small(name: string, order: number, width: number): Frame
		local b = Instance.new("Frame")
		b.Name = name
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(width, 40)
		b.BackgroundColor3 = BG
		b.BackgroundTransparency = 0.2
		b.BorderSizePixel = 0
		b.Parent = root
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = b
		return b
	end
	local windBlock = small("Wind", 3, ResourceBar.WIND_W)
	-- a faint three-bladed fan, turning with the wind
	local fan = Instance.new("Frame")
	fan.Name = "Fan"
	fan.AnchorPoint = Vector2.new(0.5, 0.5)
	fan.Position = UDim2.fromScale(0.5, 0.5) -- behind the value, the whole box's middle
	fan.Size = UDim2.fromOffset(32, 32)
	fan.BackgroundTransparency = 1
	fan.Parent = windBlock
	for k = 0, 2 do
		-- a GUI turns about its own centre: each blade in a fan-sized holder
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.Rotation = k * 120
		holder.BackgroundTransparency = 1
		holder.Parent = fan
		local blade = Instance.new("Frame")
		blade.AnchorPoint = Vector2.new(0.5, 1)
		blade.Position = UDim2.fromScale(0.5, 0.5)
		blade.Size = UDim2.fromOffset(8, 15)
		blade.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
		blade.BackgroundTransparency = 0.85 -- a watermark under the number
		blade.BorderSizePixel = 0
		blade.Parent = holder
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = blade
	end
	local hub = Instance.new("Frame")
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(4, 4)
	hub.BackgroundColor3 = Color3.fromRGB(220, 225, 235)
	hub.BackgroundTransparency = 0.85
	hub.BorderSizePixel = 0
	hub.Parent = fan
	local wind = text(windBlock, 16, Color3.fromRGB(240, 210, 60), Enum.TextXAlignment.Center, UDim2.fromOffset(0, 11), UDim2.new(1, 0, 0, 18))
	local windMin = text(windBlock, 9, Color3.fromRGB(170, 175, 185), Enum.TextXAlignment.Right, UDim2.fromOffset(30, 2), UDim2.fromOffset(22, 11))
	local windMax = text(windBlock, 9, Color3.fromRGB(170, 175, 185), Enum.TextXAlignment.Right, UDim2.fromOffset(30, 27), UDim2.fromOffset(22, 11))
	local tidalBlock = small("Tidal", 4, 64)
	text(tidalBlock, 10, Color3.fromRGB(170, 175, 185), Enum.TextXAlignment.Left, UDim2.fromOffset(6, 3), UDim2.fromOffset(52, 12)).Text = "TIDAL"
	local tidal = text(tidalBlock, 17, Color3.fromRGB(240, 210, 60), Enum.TextXAlignment.Right, UDim2.fromOffset(6, 17), UDim2.fromOffset(52, 20))
	Kit.skin(gui) -- the UI kit's look (C-105)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, blocks = blocks, markers = markers, wind = wind, windMin = windMin, windMax = windMax, fan = fan, tidal = tidal, nextUpdate = 0, spin = 0, spinAt = 0 }
end

ResourceBar.api = nil :: Api.Api? -- (the markers send through it)

-- Each marker at its level: the one being dragged where the mouse is, the
-- others at the server's.
local function placeMarkers(bar: Bar, api: Api.Api)
	local eco = api.state.economy
	for _, m in bar.markers do
		local level = m.dragging
		if level == nil and eco then
			level = if m.level == Schema.EcoLevel.SUPPLY_SHARE then eco.supplyShare elseif m.level == Schema.EcoLevel.POWER_SHARE then eco.powerShare else eco.convertAt
			m.shown = level :: number
		end
		m.handle.Visible = level ~= nil
		m.handle.Position = UDim2.fromScale((level or 0) / 100, 0.5)
	end
end

function ResourceBar.step(bar: Bar, api: Api.Api, now: number)
	ResourceBar.api = api
	placeMarkers(bar, api)
	-- the fan turns every frame, faster in a stronger wind
	local eco0 = api.state.economy
	local dt = if bar.spinAt > 0 then math.clamp(now - bar.spinAt, 0, 0.1) else 0
	bar.spinAt = now
	bar.spin = (bar.spin + dt * ResourceBar.FAN_RPM * 6 * (if eco0 then eco0.wind else 0)) % 360
	bar.fan.Rotation = bar.spin
	if now < bar.nextUpdate then
		return
	end
	bar.nextUpdate = now + 0.25
	local eco = api.state.economy
	for name, b in bar.blocks do
		local r = if eco then (if name == "Supply" then eco.supply else eco.power) else nil
		if r == nil then
			b.stored.Text = "…"
			continue
		end
		local stalling = r.ratio < 0.999
		b.demand.Text = string.format("-%s", short(r.demand))
		b.income.Text = string.format("+%s", short(r.income))
		b.stored.Text = short(r.stored)
		b.stored.TextColor3 = if stalling then Color3.fromRGB(255, 160, 150) else Color3.new(1, 1, 1)
		b.storage.Text = short(r.storage)
		b.fill.Size = UDim2.fromScale(if r.storage > 0 then math.clamp(r.stored / r.storage, 0, 1) else 0, 1)
		b.fill.BackgroundColor3 = if stalling then STALL else FILL[name]
	end
	-- wind and tidal, in power per second for one generator
	-- the player's faction: its Commander's (any own unit's), else Order
	local world = api.world
	local faction = "order"
	for _, u in world.units do
		local def = u.team == world.me.team and u.defIndex and world.defs.unitByIndex[u.defIndex]
		if def and def.faction then
			faction = def.faction
			if table.find(def.categories or {}, "COMMANDER") then
				break
			end
		end
	end
	local windMax, tidal = UnitFlow.generatorOutputs(world.defs, faction)
	local layers = api.world.layers
	local range = (layers and layers.wind) or UnitFlow.WIND_DEFAULT
	bar.wind.Text = if eco then string.format("%.0f", windMax * eco.wind) else "…"
	bar.windMin.Text = string.format("%.0f", windMax * range[1])
	bar.windMax.Text = string.format("%.0f", windMax * range[2])
	bar.tidal.Text = string.format("%.0f", tidal)
end

return ResourceBar

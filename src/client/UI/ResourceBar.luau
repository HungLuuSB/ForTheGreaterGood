--!strict
-- Resource bar (guide 15.7), BAR style (C-71): top center, a block per
-- resource: its symbol, demand (red) over income (green), the amount
-- stored (large), a thin fill bar of stored / storage with a stall tint,
-- and the storage. Then, as in BAR, the wind (what a wind turbine makes
-- now, large, and the map's range under it: S-177's layers.wind, no
-- randomness) and the tidal (what a tidal generator makes). From
-- Api.state.economy (the Eco channel) and the map; reads only the client
-- API (C-5). A placeholder look for the UI session.

local Players = game:GetService("Players")

local Api = require("../Api")
local UnitFlow = require("../Core/UnitFlow")
local Kit = require("./Kit")

local ResourceBar = {}

local BG = Kit.COLOR.panel
local FILL = { Supply = Color3.fromRGB(200, 205, 215), Power = Color3.fromRGB(240, 210, 60) }
local SYMBOL = { Supply = "■", Power = "ϟ" }
local STALL = Color3.fromRGB(230, 70, 60)

type Block = { demand: TextLabel, income: TextLabel, stored: TextLabel, storage: TextLabel, fill: Frame }
export type Bar = { gui: ScreenGui, blocks: { [string]: Block }, wind: TextLabel, windRange: TextLabel, tidal: TextLabel, nextUpdate: number }

ResourceBar.WIDTH = 2 * 270 + 100 + 64 + 3 * 6 -- supply, power, wind, tidal (UI/IdleStrip sits right of it)
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
		text(b, 22, FILL[name], Enum.TextXAlignment.Center, UDim2.fromOffset(4, 6), UDim2.fromOffset(26, 26)).Text = SYMBOL[name]
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
		blocks[name] = { demand = demand, income = income, stored = stored, storage = storage, fill = fill }
	end
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
	local windBlock = small("Wind", 3, 100)
	text(windBlock, 10, Color3.fromRGB(170, 175, 185), Enum.TextXAlignment.Left, UDim2.fromOffset(6, 3), UDim2.fromOffset(40, 12)).Text = "WIND"
	local wind = text(windBlock, 17, Color3.fromRGB(240, 210, 60), Enum.TextXAlignment.Right, UDim2.fromOffset(40, 2), UDim2.fromOffset(54, 20))
	local windRange = text(windBlock, 11, Color3.fromRGB(170, 175, 185), Enum.TextXAlignment.Right, UDim2.fromOffset(6, 23), UDim2.fromOffset(88, 13))
	local tidalBlock = small("Tidal", 4, 64)
	text(tidalBlock, 10, Color3.fromRGB(170, 175, 185), Enum.TextXAlignment.Left, UDim2.fromOffset(6, 3), UDim2.fromOffset(52, 12)).Text = "TIDAL"
	local tidal = text(tidalBlock, 17, Color3.fromRGB(240, 210, 60), Enum.TextXAlignment.Right, UDim2.fromOffset(6, 17), UDim2.fromOffset(52, 20))
	Kit.skin(gui) -- the UI kit's look (C-105)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, blocks = blocks, wind = wind, windRange = windRange, tidal = tidal, nextUpdate = 0 }
end

function ResourceBar.step(bar: Bar, api: Api.Api, now: number)
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
	bar.windRange.Text = string.format("%.0f – %.0f", windMax * range[1], windMax * range[2])
	bar.tidal.Text = string.format("%.0f", tidal)
end

return ResourceBar

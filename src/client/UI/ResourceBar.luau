--!strict
-- Resource bar (guide 15.7), BAR style (C-71): top center, a block per
-- resource: its symbol, demand (red) over income (green), the amount
-- stored (large), a thin fill bar of stored / storage with a stall tint,
-- and the storage. From Api.state.economy (the Eco channel); reads only
-- the client API (C-5). A placeholder look for the UI session.

local Players = game:GetService("Players")

local Api = require("../Api")
local Kit = require("./Kit")

local ResourceBar = {}

local BG = Kit.COLOR.panel
local FILL = { Supply = Color3.fromRGB(200, 205, 215), Power = Color3.fromRGB(240, 210, 60) }
local SYMBOL = { Supply = "■", Power = "ϟ" }
local STALL = Color3.fromRGB(230, 70, 60)

type Block = { demand: TextLabel, income: TextLabel, stored: TextLabel, storage: TextLabel, fill: Frame }
export type Bar = { gui: ScreenGui, blocks: { [string]: Block }, nextUpdate: number }

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
	local root = Instance.new("Frame")
	root.Name = "Bar"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 0)
	root.Size = UDim2.fromOffset(2 * 270 + 6, 40)
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
	Kit.skin(gui) -- the UI kit's look (C-105)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, blocks = blocks, nextUpdate = 0 }
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
end

return ResourceBar

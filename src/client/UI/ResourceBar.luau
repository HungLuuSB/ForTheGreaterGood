--!strict
-- PLACEHOLDER resource bar (guide 15.7), top center: supply and power,
-- stored / storage as a fill, +income -demand, and a stall warning, from
-- Api.state.economy (the Eco channel). Reads only the client API (C-5).

local Players = game:GetService("Players")

local Api = require("../Api")
local Minimap = require("../Core/Minimap")

local ResourceBar = {}

local FILL = {
	Supply = Color3.fromRGB(110, 190, 230),
	Power = Color3.fromRGB(240, 210, 90),
}
local STALL = Color3.fromRGB(230, 70, 60)

type Row = { fill: Frame, text: TextLabel }
export type Bar = { gui: ScreenGui, rows: { [string]: Row }, nextUpdate: number }

function ResourceBar.new(): Bar
	local gui = Instance.new("ScreenGui")
	gui.Name = "ResourceBar"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local root = Instance.new("Frame")
	root.Name = "Bar"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 6)
	root.Size = UDim2.fromOffset(440, 48)
	root.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	root.BackgroundTransparency = 0.25
	root.BorderSizePixel = 0
	root.Parent = gui
	local label = Instance.new("TextLabel")
	label.Name = "Placeholder"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.new(1, -4, 1, 2)
	label.Size = UDim2.fromOffset(200, 12)
	label.Font = Enum.Font.Code
	label.TextSize = 11
	label.TextColor3 = Color3.fromRGB(230, 200, 90)
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.Text = "PLACEHOLDER RESOURCE BAR"
	label.Parent = root
	local rows = {}
	for i, name in { "Supply", "Power" } do
		local back = Instance.new("Frame")
		back.Name = name
		back.Position = UDim2.fromOffset(6, 4 + (i - 1) * 22)
		back.Size = UDim2.new(1, -12, 0, 18)
		back.BackgroundColor3 = Color3.fromRGB(45, 48, 54)
		back.BorderSizePixel = 0
		back.Parent = root
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.Size = UDim2.fromScale(0, 1)
		fill.BackgroundColor3 = FILL[name]
		fill.BackgroundTransparency = 0.35
		fill.BorderSizePixel = 0
		fill.Parent = back
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Position = UDim2.fromOffset(6, 0)
		text.Font = Enum.Font.Code
		text.TextSize = 14
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.ZIndex = 2
		text.Parent = back
		rows[name] = { fill = fill, text = text }
	end
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, rows = rows, nextUpdate = 0 }
end

function ResourceBar.step(bar: Bar, api: Api.Api, now: number)
	if now < bar.nextUpdate then
		return
	end
	bar.nextUpdate = now + 0.25
	local eco = api.state.economy
	for name, row in bar.rows do
		local r = if eco then (if name == "Supply" then eco.supply else eco.power) else nil
		local line = Minimap.resLine(name, r)
		row.text.Text = line.text
		row.fill.Size = UDim2.fromScale(line.fill, 1)
		row.fill.BackgroundColor3 = if line.stalling then STALL else FILL[name]
		row.text.TextColor3 = if line.stalling then Color3.fromRGB(255, 200, 190) else Color3.new(1, 1, 1)
	end
end

return ResourceBar

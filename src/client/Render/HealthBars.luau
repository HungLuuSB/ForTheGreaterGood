--!strict
-- Health and build bars on screen (guide 15.7, C-24): a pooled
-- screen-space layer like IconLayer (no BillboardGuis). Which units get
-- bars and where comes from Core/Bars; this only draws them. Hidden at
-- strategic zoom. Looks are placeholders: listed under "Needs my review".

local Players = game:GetService("Players")

local Bars = require("../Core/Bars")

local HealthBars = {}

local HEALTH_H = 4 -- pixels
local BUILD_H = 3
local BUILD_COLOR = Color3.fromRGB(150, 205, 255)
local PRODUCTION_COLOR = Color3.fromRGB(238, 186, 92) -- a factory's item in production (C-168)
local BACK_COLOR = Color3.fromRGB(20, 20, 20)
-- missile stock (S-47, C-56): one pip per missile above the health bar,
-- filled while in stock; past MAX_PIPS a single bar instead
local PIP_H = 3
local MAX_PIPS = 10
local STOCK_COLOR = Color3.fromRGB(255, 200, 70)
local EMPTY_COLOR = Color3.fromRGB(70, 60, 45)

type Slot = { root: Frame, healthFill: Frame, buildBack: Frame, buildFill: Frame, stockRow: Frame, pips: { Frame } }

export type Layer = { gui: ScreenGui, slots: { Slot }, used: number }

function HealthBars.new(): Layer
	local gui = Instance.new("ScreenGui")
	gui.Name = "HealthBars"
	gui.IgnoreGuiInset = true -- viewport pixels, like WorldToViewportPoint
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 0 -- under the icons and the UI
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, slots = {}, used = 0 }
end

local function bar(parent: Instance, name: string, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Parent = parent
	return f
end

local function newSlot(parent: ScreenGui): Slot
	-- root = the health bar's dark back; the build bar hangs under it
	local root = bar(parent, "Bar", BACK_COLOR)
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundTransparency = 0.25
	local healthFill = bar(root, "Health", Color3.new(0, 1, 0))
	local buildBack = bar(root, "BuildBack", BACK_COLOR)
	buildBack.BackgroundTransparency = 0.25
	buildBack.Position = UDim2.new(0, 0, 1, 1)
	local buildFill = bar(buildBack, "Build", BUILD_COLOR)
	local stockRow = Instance.new("Frame")
	stockRow.Name = "Stock"
	stockRow.BackgroundTransparency = 1
	stockRow.AnchorPoint = Vector2.new(0, 1)
	stockRow.Position = UDim2.new(0, 0, 0, -1)
	stockRow.Parent = root
	return { root = root, healthFill = healthFill, buildBack = buildBack, buildFill = buildFill, stockRow = stockRow, pips = {} }
end

-- The stock row: `count` of `capacity` pips lit (or one bar past MAX_PIPS),
-- the next one filling with `progress` (S-49, C-59).
local function drawStock(slot: Slot, width: number, count: number?, capacity: number?, progress: number?)
	local row = slot.stockRow
	if count == nil or capacity == nil then
		row.Visible = false
		return
	end
	row.Visible = true
	row.Size = UDim2.fromOffset(width, PIP_H)
	local n = if capacity <= MAX_PIPS then capacity else 1
	for i = 1, math.max(n, #slot.pips) do
		local pip = slot.pips[i]
		if i > n then
			if pip then
				pip.Visible = false
			end
			continue
		end
		if pip == nil then
			pip = bar(row, "Pip", STOCK_COLOR)
			slot.pips[i] = pip
		end
		pip.Visible = true
		if capacity <= MAX_PIPS then
			local gap = 1
			local w = math.max(1, (width - gap * (capacity - 1)) / capacity)
			pip.Position = UDim2.fromOffset(math.floor((i - 1) * (w + gap) + 0.5), 0)
			pip.Size = UDim2.fromOffset(math.max(1, math.floor(w + 0.5)), PIP_H)
			pip.BackgroundColor3 = if i <= count then STOCK_COLOR else EMPTY_COLOR
			-- the missile being built fills its pip from the left
			local fill = pip:FindFirstChild("Fill") :: Frame?
			local building = i == count + 1 and progress ~= nil and progress > 0
			if building and fill == nil then
				local f = bar(pip, "Fill", STOCK_COLOR)
				f.BackgroundTransparency = 0.35
				fill = f
			end
			if fill then
				fill.Visible = building
				if building then
					fill.Position = UDim2.fromOffset(0, 0)
					fill.Size = UDim2.new(progress :: number, 0, 1, 0)
				end
			end
		else
			pip.Position = UDim2.fromOffset(0, 0)
			pip.Size = UDim2.fromOffset(math.max(1, math.floor(width * (count + (progress or 0)) / capacity + 0.5)), PIP_H)
			pip.BackgroundColor3 = STOCK_COLOR
		end
	end
end

function HealthBars.step(layer: Layer, draws: { Bars.Draw }, visible: boolean)
	local n = 0
	if visible then
		for _, d in draws do
			n += 1
			local slot = layer.slots[n]
			if slot == nil then
				slot = newSlot(layer.gui)
				layer.slots[n] = slot
			end
			local w = math.floor(d.width + 0.5)
			local b = d.bar
			local building = b.build ~= nil or b.production ~= nil
			-- the pair is anchored by its bottom edge, so the health bar stays put when the build bar goes
			slot.root.Position = UDim2.fromOffset(math.floor(d.x + 0.5), math.floor(d.y + 0.5) - if building then BUILD_H + 1 else 0)
			slot.root.Size = UDim2.fromOffset(w, HEALTH_H)
			slot.healthFill.Size = UDim2.new(math.clamp(b.health, 0, 1), 0, 1, 0)
			local r, g, bl = Bars.healthColor(b.health)
			slot.healthFill.BackgroundColor3 = Color3.fromRGB(r, g, bl)
			slot.buildBack.Visible = building
			if building then
				slot.buildBack.Size = UDim2.new(1, 0, 0, BUILD_H)
				slot.buildFill.Size = UDim2.new(math.clamp((b.build or b.production) :: number, 0, 1), 0, 1, 0)
				slot.buildFill.BackgroundColor3 = if b.build ~= nil then BUILD_COLOR else PRODUCTION_COLOR
			end
			drawStock(slot, w, b.stock, b.stockMax, b.stockProgress)
			slot.root.Visible = true
		end
	end
	for i = n + 1, layer.used do
		layer.slots[i].root.Visible = false
	end
	layer.used = n
end

return HealthBars

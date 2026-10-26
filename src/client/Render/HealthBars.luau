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
local RELOAD_COLOR = Color3.fromRGB(205, 235, 255) -- a long-reload weapon recharging (C-170)
local RELOAD_H = 2
local BACK_COLOR = Color3.fromRGB(20, 20, 20)
local WRECK_SUPPLY_COLOR = Color3.fromRGB(40, 120, 55) -- a wreck's supply left (dark green, S-168; C-216)
local REZ_COLOR = Color3.fromRGB(170, 90, 230) -- resurrect progress (purple)
-- missile stock (S-47, C-56) above the health bar: the count as a number
-- and a bar for the missile being made (F10, the user; full when stocked up)
local PIP_H = 3
local COUNT_W = 14 -- pixels for the count
local STOCK_COLOR = Color3.fromRGB(255, 200, 70)
local EMPTY_COLOR = Color3.fromRGB(70, 60, 45)

type Slot = { root: Frame, healthFill: Frame, buildBack: Frame, buildFill: Frame, reloadBack: Frame, reloadFill: Frame, stockRow: Frame, pips: { Frame } }

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
	-- root = the health bar's dark back, its top at the draw's y (under the
	-- unit, C-208); the build and reload bars hang under it
	local root = bar(parent, "Bar", BACK_COLOR)
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundTransparency = 0.25
	local healthFill = bar(root, "Health", Color3.new(0, 1, 0))
	local buildBack = bar(root, "BuildBack", BACK_COLOR)
	buildBack.BackgroundTransparency = 0.25
	buildBack.Position = UDim2.new(0, 0, 1, 1)
	local buildFill = bar(buildBack, "Build", BUILD_COLOR)
	local reloadBack = bar(root, "ReloadBack", BACK_COLOR)
	reloadBack.BackgroundTransparency = 0.25
	local reloadFill = bar(reloadBack, "Reload", RELOAD_COLOR)
	local stockRow = Instance.new("Frame")
	stockRow.Name = "Stock"
	stockRow.BackgroundTransparency = 1
	stockRow.AnchorPoint = Vector2.new(0, 1)
	stockRow.Position = UDim2.new(0, 0, 0, -1)
	stockRow.Parent = root
	return { root = root, healthFill = healthFill, buildBack = buildBack, buildFill = buildFill, reloadBack = reloadBack, reloadFill = reloadFill, stockRow = stockRow, pips = {} }
end

-- The stock row: `count` as a number, then a bar filling with the next
-- missile's `progress` (S-49, C-59), full once at `capacity` (F10).
local function drawStock(slot: Slot, width: number, count: number?, capacity: number?, progress: number?)
	local row = slot.stockRow
	if count == nil or capacity == nil then
		row.Visible = false
		return
	end
	row.Visible = true
	row.Size = UDim2.fromOffset(width, PIP_H)
	local label = row:FindFirstChild("Count") :: TextLabel?
	if label == nil then
		local t = Instance.new("TextLabel")
		t.Name = "Count"
		t.AnchorPoint = Vector2.new(1, 0.5)
		t.Position = UDim2.new(0, -2, 0.5, 0)
		t.Size = UDim2.fromOffset(COUNT_W, 10)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 10
		t.TextColor3 = STOCK_COLOR
		t.TextStrokeTransparency = 0.4
		t.TextXAlignment = Enum.TextXAlignment.Right
		t.Parent = row
		label = t
	end
	(label :: TextLabel).Text = tostring(count)
	local back = slot.pips[1]
	if back == nil then
		back = bar(row, "Next", EMPTY_COLOR)
		bar(back, "Fill", STOCK_COLOR)
		slot.pips[1] = back
	end
	back.Position = UDim2.fromOffset(0, 0)
	back.Size = UDim2.fromOffset(width, PIP_H)
	local fill = back:FindFirstChild("Fill") :: Frame
	local k = if count >= capacity then 1 else math.clamp(progress or 0, 0, 1)
	fill.Size = UDim2.new(k, 0, 1, 0)
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
			-- anchored by its top edge under the unit: the health bar stays put when the build bar goes
			local reloading = b.reload ~= nil
			slot.root.Position = UDim2.fromOffset(math.floor(d.x + 0.5), math.floor(d.y + 0.5))
			slot.root.Size = UDim2.fromOffset(w, HEALTH_H)
			slot.healthFill.Size = UDim2.new(math.clamp(b.health, 0, 1), 0, 1, 0)
			if b.wreck then
				-- a wreck: supply left (dark green) over resurrect progress (purple); either alone
				slot.healthFill.BackgroundColor3 = if b.supplyShare ~= nil then WRECK_SUPPLY_COLOR else REZ_COLOR
				local both = b.supplyShare ~= nil and b.rez ~= nil
				slot.buildBack.Visible = both
				if both then
					slot.buildBack.Size = UDim2.new(1, 0, 0, BUILD_H)
					slot.buildFill.Size = UDim2.new(math.clamp(b.rez :: number, 0, 1), 0, 1, 0)
					slot.buildFill.BackgroundColor3 = REZ_COLOR
				end
			else
				local r, g, bl = Bars.healthColor(b.health)
				slot.healthFill.BackgroundColor3 = Color3.fromRGB(r, g, bl)
				slot.buildBack.Visible = building
				if building then
					slot.buildBack.Size = UDim2.new(1, 0, 0, BUILD_H)
					slot.buildFill.Size = UDim2.new(math.clamp((b.build or b.production) :: number, 0, 1), 0, 1, 0)
					slot.buildFill.BackgroundColor3 = if b.build ~= nil then BUILD_COLOR else PRODUCTION_COLOR
				end
			end
			-- the recharge bar: under the health (and build) bar (C-170)
			slot.reloadBack.Visible = reloading
			if reloading then
				slot.reloadBack.Position = UDim2.new(0, 0, 1, 1 + (if building then BUILD_H + 1 else 0))
				slot.reloadBack.Size = UDim2.new(1, 0, 0, RELOAD_H)
				slot.reloadFill.Size = UDim2.new(math.clamp(b.reload :: number, 0, 1), 0, 1, 0)
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

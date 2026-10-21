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
local BACK_COLOR = Color3.fromRGB(20, 20, 20)

type Slot = { root: Frame, healthFill: Frame, buildBack: Frame, buildFill: Frame }

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
	return { root = root, healthFill = healthFill, buildBack = buildBack, buildFill = buildFill }
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
			local building = b.build ~= nil
			-- the pair is anchored by its bottom edge, so the health bar stays put when the build bar goes
			slot.root.Position = UDim2.fromOffset(math.floor(d.x + 0.5), math.floor(d.y + 0.5) - if building then BUILD_H + 1 else 0)
			slot.root.Size = UDim2.fromOffset(w, HEALTH_H)
			slot.healthFill.Size = UDim2.new(math.clamp(b.health, 0, 1), 0, 1, 0)
			local r, g, bl = Bars.healthColor(b.health)
			slot.healthFill.BackgroundColor3 = Color3.fromRGB(r, g, bl)
			slot.buildBack.Visible = building
			if building then
				slot.buildBack.Size = UDim2.new(1, 0, 0, BUILD_H)
				slot.buildFill.Size = UDim2.new(math.clamp(b.build :: number, 0, 1), 0, 1, 0)
			end
			slot.root.Visible = true
		end
	end
	for i = n + 1, layer.used do
		layer.slots[i].root.Visible = false
	end
	layer.used = n
end

return HealthBars

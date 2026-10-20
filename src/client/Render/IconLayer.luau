--!strict
-- Icons on screen (guide 15.4): a pooled screen-space layer of small
-- shapes in team colors, no image assets. Units without a model (radar
-- blips, ghosts, strategic records in view) always get an icon; at
-- strategic zoom every unit does and the models are hidden.
-- Looks are placeholders: listed under "Needs my review".

local Players = game:GetService("Players")

local Icons = require("../Core/Icons")
local TeamColors = require("./TeamColors")

local IconLayer = {}

type Slot = { root: Frame, body: Frame, stroke: UIStroke, corner: UICorner, tri: TextLabel, shape: string? }

export type Layer = { gui: ScreenGui, slots: { Slot }, used: number }

function IconLayer.new(): Layer
	local gui = Instance.new("ScreenGui")
	gui.Name = "Icons"
	gui.IgnoreGuiInset = true -- viewport pixels, like WorldToViewportPoint
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, slots = {}, used = 0 }
end

local function newSlot(parent: ScreenGui): Slot
	local root = Instance.new("Frame")
	root.Name = "Icon"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.BorderSizePixel = 0
	body.Parent = root
	local corner = Instance.new("UICorner")
	corner.Parent = body
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = body
	local tri = Instance.new("TextLabel")
	tri.Name = "Triangle"
	tri.BackgroundTransparency = 1
	tri.Size = UDim2.fromScale(1, 1)
	tri.Font = Enum.Font.Arial
	tri.Text = "▲" -- aircraft
	tri.TextScaled = true
	tri.TextStrokeTransparency = 0.3
	tri.Parent = root
	root.Parent = parent
	return { root = root, body = body, stroke = stroke, corner = corner, tri = tri, shape = nil }
end

local function apply(slot: Slot, style: Icons.Style)
	local color = TeamColors(style.team)
	local shape = style.shape
	local s = style.size
	slot.root.Size = UDim2.fromOffset(s, s)
	local isTri = shape == "triangle"
	slot.tri.Visible = isTri
	slot.body.Visible = not isTri
	if isTri then
		slot.tri.TextColor3 = color
		slot.tri.TextTransparency = 1 - style.alpha
		slot.tri.TextStrokeColor3 = if style.selected then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		return
	end
	local body = slot.body
	body.Rotation = if shape == "diamond" then 45 else 0
	local k = if shape == "diamond" then 0.75 elseif shape == "blip" then 0.6 else 1
	body.Size = UDim2.fromScale(k, k)
	slot.corner.CornerRadius = if shape == "circle" or shape == "blip" then UDim.new(1, 0) else UDim.new(0, 2)
	local hollow = shape == "ghost"
	body.BackgroundColor3 = if shape == "frame" then color:Lerp(Color3.new(0, 0, 0), 0.45) else color
	body.BackgroundTransparency = if hollow then 1 else 1 - style.alpha
	slot.stroke.Color = if style.selected then Color3.new(1, 1, 1) elseif shape == "frame" or hollow then color else Color3.new(0, 0, 0)
	slot.stroke.Thickness = if style.selected then 2 elseif shape == "frame" then 2 else 1
	slot.stroke.Transparency = if hollow then 1 - style.alpha else 0.2
end

-- Draws this frame's icons. With `everything` false only units without a
-- model (not tactical) get one.
function IconLayer.step(layer: Layer, draws: { Icons.Draw }, tiers: { [number]: string }, everything: boolean)
	local n = 0
	for _, d in draws do
		if not everything and tiers[d.id] == "tactical" then
			continue
		end
		n += 1
		local slot = layer.slots[n]
		if slot == nil then
			slot = newSlot(layer.gui)
			layer.slots[n] = slot
		end
		slot.root.Visible = true
		slot.root.Position = UDim2.fromOffset(d.x, d.y)
		apply(slot, d.style)
	end
	for i = n + 1, layer.used do
		layer.slots[i].root.Visible = false
	end
	layer.used = n
end

return IconLayer

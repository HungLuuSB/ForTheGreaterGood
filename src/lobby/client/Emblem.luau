--!strict
-- The faction emblems (2d-E's D-E2: Order's Bastion, Chaos's Maw; B's
-- UI/FactionEmblems, read-only): a tinted emblem label, the faction picker
-- with big emblems (Skirmish, the seat and AI editors), and small emblems in
-- a faction switch (the Units tab). Before the atlas is uploaded, the names
-- show alone.

local FactionEmblems = require("@client/UI/FactionEmblems")
local Ui = require("./Ui")

local Kit = Ui.Kit

local Emblem = {}

-- `faction`'s tint (its emblem's), else the lobby's faction colors
function Emblem.tint(faction: string): Color3
	local key = FactionEmblems.keyOf(faction)
	local t = key and FactionEmblems.emblems[key].tint
	if t then
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	return if faction == "order" then Color3.fromRGB(64, 132, 230) else Color3.fromRGB(222, 70, 62)
end

-- An ImageLabel of `faction`'s emblem, `px` square, tinted (white when
-- `color` says so); nil while there's no emblem (callers keep their text).
function Emblem.label(parent: Instance, faction: string, px: number, color: Color3?): ImageLabel?
	local image, offset, size = FactionEmblems.of(faction, px)
	if image == nil or offset == nil or size == nil then
		return nil
	end
	local l = Instance.new("ImageLabel")
	l.Name = "Emblem"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(px, px)
	l.Image = image
	l.ImageRectOffset = Vector2.new(offset[1], offset[2])
	l.ImageRectSize = Vector2.new(offset[3], offset[4])
	l.ImageColor3 = color or Emblem.tint(faction)
	l.ScaleType = Enum.ScaleType.Fit
	l.Parent = parent
	return l
end

export type Picker = { frame: Frame, set: (faction: string) -> () }

-- A card per faction, its emblem (`px`, 64 by default) over its name; the
-- chosen one lit in its tint, the other dimmed. Without emblems the cards
-- show the names alone.
function Emblem.picker(parent: Instance, factions: { string }, value: string, onChange: (string) -> (), px: number?): Picker
	local size = px or 64
	local cardW, cardH = size + 36, size + 30
	local f = Ui.frame(parent, "Factions", UDim2.fromOffset(#factions * (cardW + Kit.SPACE.s), cardH))
	local fl = Kit.list(f, Kit.SPACE.s, true)
	fl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local cards: { [string]: { button: TextButton, emblem: ImageLabel?, name: TextLabel } } = {}
	local picker: Picker
	picker = {
		frame = f,
		set = function(v: string)
			for faction, c in cards do
				local on = faction == v
				c.button.BackgroundTransparency = if on then 0.82 else 0.94
				local stroke = c.button:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if on then Emblem.tint(faction) else Color3.new(1, 1, 1)
					stroke.Transparency = if on then 0.2 else 0.88
				end
				if c.emblem then
					c.emblem.ImageColor3 = if on then Emblem.tint(faction) else Kit.COLOR.dim
					c.emblem.ImageTransparency = if on then 0 else 0.35
				end
				c.name.TextColor3 = if on then Kit.COLOR.text else Kit.COLOR.dim
			end
		end,
	}
	for i, faction in factions do
		local b = Instance.new("TextButton")
		b.Name = faction
		b.AutoButtonColor = false
		b.Text = ""
		b.Size = UDim2.fromOffset(cardW, cardH)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.LayoutOrder = i
		b.Parent = f
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, Kit.CONTROL_RADIUS)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		local emblem = Emblem.label(b, faction, size)
		local name = Kit.text(b, Ui.label2(faction), "label")
		name.TextXAlignment = Enum.TextXAlignment.Center
		if emblem then
			emblem.AnchorPoint = Vector2.new(0.5, 0)
			emblem.Position = UDim2.new(0.5, 0, 0, 4)
			name.Size = UDim2.new(1, 0, 0, 20)
			name.Position = UDim2.new(0, 0, 1, -24)
		else
			name.Size = UDim2.fromScale(1, 1)
			name.TextSize = 18
		end
		cards[faction] = { button = b, emblem = emblem, name = name }
		b.MouseButton1Click:Connect(function()
			picker.set(faction)
			onChange(faction)
		end)
	end
	picker.set(value)
	return picker
end

-- Puts a `px` emblem (16 by default) before the name on each faction button
-- of a Kit.segmented built from `options` ({ value, text } pairs, in order).
function Emblem.decorate(frame: Frame, options: { { string } }, px: number?)
	local size = px or 16
	for _, b in frame:GetChildren() do
		local o = b:IsA("TextButton") and options[b.LayoutOrder]
		if o then
			local emblem = Emblem.label(b, o[1], size)
			if emblem then
				-- padding the left by the emblem's width centres emblem and
				-- name together; the emblem sits just before the name
				local button = b :: TextButton
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, size + 4)
				pad.Parent = button
				emblem.AnchorPoint = Vector2.new(1, 0.5)
				local function place()
					emblem.Position = UDim2.new(0.5, -button.TextBounds.X / 2 - 4, 0.5, 0)
				end
				place()
				button:GetPropertyChangedSignal("TextBounds"):Connect(place)
			end
		end
	end
end

return Emblem

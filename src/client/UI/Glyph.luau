--!strict
-- A unit type's icon as a screen-space glyph (C-71, BAR style): the shape
-- in team color (square, circle, diamond, triangle, structure frame,
-- commander star; blips, ghosts and sonar rings for contacts), the type's
-- white role mark, tier pips under it, a dark corner notch on Chaos types
-- and variant dots. Used by the icon layer, the build grid and the unit
-- panel; no image assets.

local Icons = require("../Core/Icons")

local Glyph = {}

export type G = {
	root: Frame,
	body: Frame,
	stroke: UIStroke,
	corner: UICorner,
	big: TextLabel, -- ▲ for aircraft, ★ for commanders
	mark: TextLabel,
	pips: { Frame },
	notch: Frame,
	dots: { Frame },
}

local function dot(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.ZIndex = 3
	f.Visible = false
	f.Parent = parent
	return f
end

function Glyph.new(parent: Instance): G
	local root = Instance.new("Frame")
	root.Name = "Glyph"
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
	local big = Instance.new("TextLabel")
	big.Name = "Big"
	big.BackgroundTransparency = 1
	big.Size = UDim2.fromScale(1.15, 1.15)
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.5)
	big.Font = Enum.Font.GothamBold
	big.TextScaled = true
	big.TextStrokeTransparency = 0.25
	big.Parent = root
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Font = Enum.Font.GothamBold
	mark.TextScaled = true
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.TextStrokeColor3 = Color3.new(0, 0, 0)
	mark.TextStrokeTransparency = 0.5
	mark.ZIndex = 2
	mark.Parent = root
	local notch = Instance.new("Frame")
	notch.Name = "Notch"
	notch.BorderSizePixel = 0
	notch.AnchorPoint = Vector2.new(1, 0)
	notch.Position = UDim2.fromScale(1, 0)
	notch.Size = UDim2.fromScale(0.3, 0.3)
	notch.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notch.Rotation = 45
	notch.ZIndex = 3
	notch.Parent = root
	local pips, dots = {}, {}
	for i = 1, 3 do
		pips[i] = dot(root, "Pip")
		dots[i] = dot(root, "Variant")
	end
	root.Parent = parent
	return { root = root, body = body, stroke = stroke, corner = corner, big = big, mark = mark, pips = pips, notch = notch, dots = dots }
end

-- Shows `style` (Core/Icons.Style) in `color` at `size` pixels.
function Glyph.apply(g: G, style: Icons.Style, color: Color3)
	local shape = style.shape
	local s = style.size
	g.root.Size = UDim2.fromOffset(s, s)
	local text = shape == "triangle" or shape == "star"
	g.big.Visible = text
	g.body.Visible = not text
	if text then
		g.big.Text = if shape == "star" then "★" else "▲"
		g.big.TextColor3 = color
		g.big.TextTransparency = 1 - style.alpha
		g.big.TextStrokeColor3 = if style.selected then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	else
		local body = g.body
		body.Rotation = if shape == "diamond" then 45 else 0
		local k = if shape == "diamond" then 0.72 elseif shape == "blip" then 0.6 else 1
		body.Size = UDim2.fromScale(k, k)
		g.corner.CornerRadius = if shape == "circle" or shape == "blip" or shape == "sonar" then UDim.new(1, 0) else UDim.new(0, 2)
		local hollow = shape == "ghost" or shape == "sonar"
		body.BackgroundColor3 = if shape == "frame" then color:Lerp(Color3.new(0, 0, 0), 0.45) else color
		body.BackgroundTransparency = if hollow then 1 else 1 - style.alpha
		g.stroke.Color = if style.selected then Color3.new(1, 1, 1) elseif shape == "frame" or hollow then color else Color3.new(0, 0, 0)
		g.stroke.Thickness = if style.selected then 2 elseif shape == "frame" or shape == "sonar" then 2 else 1
		g.stroke.Transparency = if hollow then 1 - style.alpha else 0.2
	end
	local glyph = style.glyph
	local mark = if glyph then glyph.mark else ""
	g.mark.Visible = mark ~= "" and s >= 11
	if g.mark.Visible then
		g.mark.Text = mark
		g.mark.TextTransparency = 1 - style.alpha
		local k = if shape == "diamond" then 0.5 elseif shape == "triangle" then 0.42 else 0.62
		g.mark.Size = UDim2.fromScale(k, k)
		g.mark.Position = UDim2.fromScale(0.5, if shape == "triangle" then 0.62 else 0.47)
	end
	g.notch.Visible = glyph ~= nil and glyph.chaos and s >= 12 and shape ~= "triangle" and shape ~= "star"
	-- tier pips along the bottom, variant dots along the top left
	local tier = if glyph then glyph.tier else 0
	local px = math.max(2, math.floor(s / 9))
	for i = 1, 3 do
		local p = g.pips[i]
		p.Visible = i <= tier and s >= 12
		if p.Visible then
			p.Size = UDim2.fromOffset(px, px)
			p.Position = UDim2.new(0.5, (i - (tier + 1) / 2) * (px + 2), 1, -px)
		end
		local d = g.dots[i]
		d.Visible = glyph ~= nil and i <= glyph.variant and s >= 12
		if d.Visible then
			d.Size = UDim2.fromOffset(px, px)
			d.Position = UDim2.new(0, px + (i - 1) * (px + 2), 0, px)
			d.BackgroundColor3 = Color3.fromRGB(255, 230, 120)
		end
	end
end

return Glyph

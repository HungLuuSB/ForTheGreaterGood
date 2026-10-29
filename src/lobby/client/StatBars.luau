--!strict
-- The Units article's numbers in the look of BAR's unit wiki (L-24, the
-- user's reference): a stat row is an uppercase label, an icon cell and a
-- long dark bar filled to the value's share of the biggest in the game (on
-- a square-root scale, so a huge outlier doesn't flatten the rest) with
-- the number in the middle; a weapon is a card with a coloured icon tile,
-- its name, and one row per figure: the number in red, what it is, and how
-- it reads ("1.80 reload slow"), then a line on what it does.

local UiIcons = require("@client/UI/UiIcons")
local Codex = require("../shared/Codex")
local Ui = require("./Ui")

local Kit = Ui.Kit

local StatBars = {}

local LABEL_W = 96
local ICON_W = 24
local ROW_H = 22
local BAR_BACK = Color3.fromRGB(26, 28, 33)
local CARD_BACK = Color3.fromRGB(20, 22, 27)
local ROW_LINE = Color3.fromRGB(44, 47, 55)
local FIGURE = Color3.fromRGB(236, 104, 92) -- a weapon row's number

-- Glyphs drawn in the icon cells: only ones Roblox's fallback fonts draw
-- (checked in Studio; ✹ ➚ ↻ ◷ ⌖ ➤ ➶ show as empty boxes).
StatBars.GLYPH = {
	supply = "◆",
	power = "⚡",
	time = "⏱",
	health = "♥",
	speed = "»",
	sight = "◉",
	radar = "◎",
	dps = "✚",
	range = "↗",
	build = "⚒",
	stock = "▤",
	reload = "≡",
	alpha = "♦",
	aoe = "☉",
	projectile = "→",
	salvo = "⁞",
	lock = "⊕",
	guidance = "⊕",
	ammo = "▤",
}

-- Bar fills, as the reference: metal white, energy amber, health green,
-- firepower red...
StatBars.COLOR = {
	supply = Color3.fromRGB(226, 229, 235),
	power = Color3.fromRGB(246, 190, 80),
	time = Color3.fromRGB(196, 200, 208),
	health = Color3.fromRGB(80, 214, 72),
	speed = Color3.fromRGB(96, 170, 236),
	sight = Color3.fromRGB(214, 218, 226),
	radar = Color3.fromRGB(120, 206, 214),
	dps = Color3.fromRGB(226, 40, 36),
	range = Color3.fromRGB(196, 34, 34),
	build = Color3.fromRGB(238, 186, 92),
	stock = Color3.fromRGB(214, 218, 226),
}

-- A stat's mark, `size` pixels square: 2D-E's icon from the UI atlas
-- (UiIcons, the match's marks too), tinted `color`; its text glyph while
-- the atlas isn't uploaded or for a key the atlas lacks.
local function mark(parent: Instance, key: string, color: Color3, size: number): GuiObject
	local icon = UiIcons.icons[key]
	if icon and UiIcons.image ~= "" then
		local px = UiIcons.sizes[#UiIcons.sizes]
		for _, s in UiIcons.sizes do
			if s >= size then
				px = s
				break
			end
		end
		local r = icon.rect[px]
		local img = Instance.new("ImageLabel")
		img.Name = "Mark"
		img.BackgroundTransparency = 1
		img.Image = UiIcons.image
		img.ImageRectOffset = Vector2.new(r[1], r[2])
		img.ImageRectSize = Vector2.new(r[3], r[4])
		img.ImageColor3 = color
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.fromOffset(size, size)
		img.Parent = parent
		return img
	end
	local g = Kit.text(parent, StatBars.GLYPH[key] or "•", "label", color)
	g.Name = "Mark"
	g.Size = UDim2.fromOffset(size, size)
	g.TextXAlignment = Enum.TextXAlignment.Center
	g.TextSize = 14
	return g
end

-- A mark in the middle of `cell`.
local function centred(cell: Instance, key: string, color: Color3, size: number)
	local m = mark(cell, key, color, size)
	m.AnchorPoint = Vector2.new(0.5, 0.5)
	m.Position = UDim2.fromScale(0.5, 0.5)
end

-- An icon's own tint (2D-E's), else `fallback`.
local function tint(key: string, fallback: Color3): Color3
	local icon = UiIcons.icons[key]
	if icon and UiIcons.image ~= "" then
		return Color3.fromRGB(icon.tint[1], icon.tint[2], icon.tint[3])
	end
	return fallback
end

local function glyphCell(parent: Instance, key: string, color: Color3, x: number): Frame
	local cell = Ui.frame(parent, "Icon", UDim2.fromOffset(ICON_W, ROW_H), UDim2.fromOffset(x, 0))
	cell.BackgroundColor3 = BAR_BACK
	cell.BackgroundTransparency = 0
	Ui.corner(cell, 3)
	centred(cell, key, color, 18)
	return cell
end

-- The share of the bar `v` fills next to `max`.
function StatBars.share(v: number, max: number?): number
	if not max or max <= 0 or v <= 0 then
		return 0
	end
	return math.clamp(math.sqrt(v / max), 0.03, 1)
end

-- A section heading in the reference's light, wide capitals.
function StatBars.heading(parent: Instance, text: string, order: number): TextLabel
	local l = Kit.text(parent, string.upper(text), "section", Kit.COLOR.text)
	l.Size = UDim2.new(1, 0, 0, 30)
	l.TextSize = 20
	l.FontFace = Kit.font(Enum.FontWeight.Regular)
	l.LayoutOrder = order
	return l
end

-- One stat bar: LABEL [icon] [====fill====   value   ].
function StatBars.bar(parent: Instance, label: string, key: string, value: number, shown: string, max: number?, order: number): Frame
	local row = Ui.frame(parent, label, UDim2.new(1, 0, 0, ROW_H))
	row.LayoutOrder = order
	local l = Kit.text(row, string.upper(label), "small", Kit.COLOR.dim)
	l.Size = UDim2.fromOffset(LABEL_W - 8, ROW_H)
	l.TextXAlignment = Enum.TextXAlignment.Right
	l.TextSize = 11
	local color = StatBars.COLOR[key] or Kit.COLOR.text
	glyphCell(row, key, color, LABEL_W)
	local x = LABEL_W + ICON_W + 4
	local track = Ui.frame(row, "Bar", UDim2.new(1, -x, 1, 0), UDim2.fromOffset(x, 0))
	track.BackgroundColor3 = BAR_BACK
	track.BackgroundTransparency = 0
	track.ClipsDescendants = true
	Ui.corner(track, 3)
	-- the reference's sheen: lighter in the middle of the bar
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 150)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 110, 110)),
	})
	sheen.Parent = track
	local k = StatBars.share(value, max)
	local fill = Ui.frame(track, "Fill", UDim2.new(k, -4, 1, -6), UDim2.fromOffset(2, 3))
	fill.BackgroundColor3 = color
	fill.BackgroundTransparency = 0
	Ui.corner(fill, 2)
	local v = Kit.text(track, shown, "label", Color3.new(1, 1, 1))
	v.Size = UDim2.fromScale(1, 1)
	v.TextXAlignment = Enum.TextXAlignment.Center
	v.FontFace = Kit.font(Enum.FontWeight.Bold)
	v.TextSize = 13
	v.ZIndex = fill.ZIndex + 1
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 1.2
	stroke.Transparency = 0.2
	stroke.Parent = v
	return row
end

-- Weapon icon tiles: a colour and a glyph per kind.
local KIND_LOOK: { [string]: { Color3 | string } } = {
	HOMING = { Color3.fromRGB(150, 60, 200), "⬆" },
	BALLISTIC = { Color3.fromRGB(206, 120, 40), "●" },
	HITSCAN = { Color3.fromRGB(200, 180, 60), "⁞" },
	BEAM = { Color3.fromRGB(60, 170, 210), "≡" },
	TORPEDO = { Color3.fromRGB(40, 90, 190), "→" },
	BOMB = { Color3.fromRGB(160, 50, 44), "▼" },
}

export type Line = { key: string, value: string, label: string, word: string? }

-- A weapon card: the tile, the name and its kind (and a stock round's
-- power), then `lines`, then `about`. The header folds the rows away.
function StatBars.weapon(parent: Instance, name: string, kind: string, kindName: string, cost: string?, lines: { Line }, about: string, order: number): Frame
	local card = Ui.frame(parent, name, UDim2.new(1, 0, 0, 0))
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = order
	card.BackgroundColor3 = CARD_BACK
	card.BackgroundTransparency = 0
	Ui.corner(card, Kit.CONTROL_RADIUS)
	local stroke = Instance.new("UIStroke")
	stroke.Color = ROW_LINE
	stroke.Transparency = 0.2
	stroke.Parent = card
	Kit.list(card, 0)
	-- header
	local head = Instance.new("TextButton")
	head.Name = "Head"
	head.AutoButtonColor = false
	head.Text = ""
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 60)
	head.LayoutOrder = 1
	head.Parent = card
	local look = KIND_LOOK[kind] or { Color3.fromRGB(120, 124, 132), "•" }
	local tile = Ui.frame(head, "Tile", UDim2.fromOffset(52, 52), UDim2.fromOffset(4, 4))
	tile.BackgroundColor3 = look[1] :: Color3
	tile.BackgroundTransparency = 0
	Ui.corner(tile, 4)
	local tg = Instance.new("UIGradient")
	tg.Rotation = 45
	tg.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(90, 90, 90))
	tg.Parent = tile
	local glyph = Kit.text(tile, look[2] :: string, "title", Color3.new(1, 1, 1))
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.TextSize = 28
	local title = Kit.text(head, string.upper(name), "label", Kit.COLOR.text)
	title.Position = UDim2.fromOffset(68, 10)
	title.Size = UDim2.new(1, -96, 0, 20)
	title.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	-- the kind, then the power a shot costs: "Cannon   ⚡ 120"
	local sub = Ui.frame(head, "Sub", UDim2.new(1, -96, 0, 18), UDim2.fromOffset(68, 32))
	local sl = Kit.list(sub, 4, true)
	sl.VerticalAlignment = Enum.VerticalAlignment.Center
	local kindText = Kit.text(sub, kindName, "small", Kit.COLOR.dim)
	kindText.AutomaticSize = Enum.AutomaticSize.X
	kindText.Size = UDim2.new(0, 0, 1, 0)
	kindText.LayoutOrder = 1
	if cost then
		local amber = StatBars.COLOR.power
		local m = mark(sub, "power", amber, 14)
		m.LayoutOrder = 2
		local c = Kit.text(sub, tostring(cost), "small", amber)
		c.AutomaticSize = Enum.AutomaticSize.X
		c.Size = UDim2.new(0, 0, 1, 0)
		c.LayoutOrder = 3
		kindText.Text = kindName .. "  "
	end
	local arrow = Kit.text(head, "▲", "small", Kit.COLOR.dim)
	arrow.AnchorPoint = Vector2.new(1, 0)
	arrow.Position = UDim2.new(1, -10, 0, 20)
	arrow.Size = UDim2.fromOffset(16, 20)
	-- the rows
	local body = Ui.frame(card, "Rows", UDim2.new(1, 0, 0, 0))
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 2
	Kit.list(body, 0)
	for i, line in lines do
		local row = Ui.frame(body, line.label, UDim2.new(1, 0, 0, 28))
		row.LayoutOrder = i
		local top = Ui.frame(row, "Line", UDim2.new(1, 0, 0, 1))
		top.BackgroundColor3 = ROW_LINE
		top.BackgroundTransparency = 0
		local cell = Ui.frame(row, "Icon", UDim2.new(0, 36, 1, -1), UDim2.fromOffset(0, 1))
		centred(cell, line.key, tint(line.key, Kit.COLOR.dim), 20)
		local div = Ui.frame(row, "Div", UDim2.new(0, 1, 1, -1), UDim2.fromOffset(36, 1))
		div.BackgroundColor3 = ROW_LINE
		div.BackgroundTransparency = 0
		local word = if line.word and line.word ~= "" then `  <b><font color="#E2E5EB">{string.upper(line.word)}</font></b>` else ""
		local t = Kit.text(row, `<font color="#{FIGURE:ToHex()}">{line.value}</font>  {string.upper(line.label)}{word}`, "small", Kit.COLOR.dim)
		t.RichText = true
		t.Position = UDim2.fromOffset(46, 1)
		t.Size = UDim2.new(1, -52, 1, -1)
	end
	-- what it does
	local foot = Ui.frame(body, "About", UDim2.new(1, 0, 0, 0))
	foot.AutomaticSize = Enum.AutomaticSize.Y
	foot.LayoutOrder = #lines + 1
	foot.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
	foot.BackgroundTransparency = 0
	Kit.pad(foot, Kit.SPACE.m, Kit.SPACE.m)
	local a = Kit.text(foot, about, "small", Kit.COLOR.text)
	a.TextWrapped = true
	a.AutomaticSize = Enum.AutomaticSize.Y
	a.Size = UDim2.new(1, 0, 0, 0)
	a.RichText = true
	head.MouseButton1Click:Connect(function()
		body.Visible = not body.Visible
		arrow.Text = if body.Visible then "▲" else "▼"
	end)
	return card
end

-- A figure as the cards print it: up to two decimals for small numbers.
function StatBars.figure(x: number): string
	if x >= 100 or x == math.floor(x) then
		return tostring(math.floor(x + 0.5))
	elseif x >= 10 then
		return (string.gsub(string.format("%.1f", x), "%.0$", ""))
	end
	return (string.format("%.2f", x))
end

StatBars.word = Codex.word

return StatBars

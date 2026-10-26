--!strict
-- The lobby's small components on top of the client's UI kit (used
-- read-only, `@client/UI/Kit`), so the lobby looks like the game. BAR's
-- lobby colors its actions: green to go (start, ready, launch), red to
-- leave: the kit's filled "go" / "stop" buttons (C-174).

local Kit = require("@client/UI/Kit")
local Config = require("../shared/Config")

local Ui = {}

Ui.Kit = Kit

function Ui.frame(parent: Instance?, name: string, size: UDim2, pos: UDim2?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = pos or UDim2.new()
	f.Parent = parent
	return f
end

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, transparency: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or Kit.COLOR.border
	s.Transparency = transparency
	s.Thickness = 1
	s.Parent = parent
end
Ui.corner = corner
Ui.stroke = stroke

-- A panel-styled area: the kit's dark fill, thin border, rounded corners.
function Ui.card(parent: Instance, name: string, size: UDim2, pos: UDim2?, alpha: number?): Frame
	local f = Ui.frame(parent, name, size, pos)
	f.BackgroundColor3 = Kit.COLOR.panel
	f.BackgroundTransparency = alpha or Kit.COLOR.panelTransparency
	corner(f, Kit.RADIUS)
	stroke(f, Kit.COLOR.borderTransparency)
	return f
end

-- A kit button; style "go" (green), "stop" (red), "primary" (amber),
-- "ghost" (outlined), "dark" (the kit's control fill: readable over key
-- art) or nil (plain), named after its text.
function Ui.button(parent: Instance, text: string, style: string?, onClick: () -> (), width: number?, height: number?): TextButton
	local b = if style == "dark" then Kit.button(parent, text, nil, onClick, width, Kit.COLOR.control) else Kit.button(parent, text, style, onClick, width)
	b.Name = text -- findable by name (tests, the Studio MCP's clicks)
	if height then
		b.Size = UDim2.fromOffset(width or 120, height)
	end
	return b
end

-- BAR's setting row (references 1): a darker label cell joined to a value
-- cell. Returns the value cell; fill it with Ui.fieldText, Ui.fieldDropdown
-- or a control. Rows are drawn top over bottom (ZIndex by order), so an
-- open dropdown's list lies over the rows below it.
local LABEL_CELL = Color3.fromRGB(13, 14, 18)
local VALUE_CELL = Color3.fromRGB(33, 36, 43)

function Ui.field(parent: Instance, label: string, order: number, height: number?): Frame
	local row = Ui.frame(parent, label, UDim2.new(1, 0, 0, height or 32))
	row.LayoutOrder = order
	row.ZIndex = 30 - order
	row.BackgroundColor3 = VALUE_CELL
	row.BackgroundTransparency = 0
	corner(row, Kit.CONTROL_RADIUS)
	local cell = Ui.frame(row, "Label", UDim2.new(0.36, 0, 1, 0))
	cell.BackgroundColor3 = LABEL_CELL
	cell.BackgroundTransparency = 0
	corner(cell, Kit.CONTROL_RADIUS)
	-- square the joined edge
	local join = Ui.frame(cell, "Join", UDim2.new(0, Kit.CONTROL_RADIUS, 1, 0), UDim2.new(1, -Kit.CONTROL_RADIUS, 0, 0))
	join.BackgroundColor3 = LABEL_CELL
	join.BackgroundTransparency = 0
	local text = Kit.text(cell, label, "label", Kit.COLOR.dim)
	text.Position = UDim2.fromOffset(Kit.SPACE.m, 0)
	text.Size = UDim2.new(1, -Kit.SPACE.m, 1, 0)
	text.TextTruncate = Enum.TextTruncate.AtEnd
	local value = Ui.frame(row, "Value", UDim2.new(0.64, 0, 1, 0), UDim2.fromScale(0.36, 0))
	return value
end

-- A chevron (two short bars: Montserrat has no arrow glyphs) at the right
-- end of a value cell.
function Ui.chevron(parent: Instance)
	local chevron = Ui.frame(parent, "Chevron", UDim2.fromOffset(12, 8), UDim2.new(1, -Kit.SPACE.m, 0.5, 1))
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	for i, angle in { 45, -45 } do
		local bar = Ui.frame(chevron, "Bar", UDim2.fromOffset(7, 1.6), UDim2.fromOffset(if i == 1 then 3.5 else 8.5, 2))
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Rotation = angle
		bar.BackgroundColor3 = Kit.COLOR.dim
		bar.BackgroundTransparency = 0
	end
end

-- Plain text in a value cell.
function Ui.fieldText(cell: Frame, text: string, color: Color3?): TextLabel
	local l = Kit.text(cell, text, "label", color or Kit.COLOR.text)
	l.Position = UDim2.fromOffset(Kit.SPACE.m, 0)
	l.Size = UDim2.new(1, -Kit.SPACE.m * 2, 1, 0)
	l.TextTruncate = Enum.TextTruncate.AtEnd
	return l
end

-- The kit's dropdown filling a value cell, blended into it (its own
-- chevron at the right end).
function Ui.fieldDropdown(cell: Frame, options: { { string } }, value: string, onChange: (string) -> ()): any
	local dd = Kit.dropdown(cell, options, value, onChange)
	dd.button.Size = UDim2.fromScale(1, 1)
	dd.button.BackgroundTransparency = 1
	dd.button.ZIndex = cell.ZIndex
	local s = dd.button:FindFirstChildOfClass("UIStroke")
	if s then
		s.Enabled = false
	end
	return dd
end

-- A kit toggle with On / Off beside it in a value cell. `onChange` nil:
-- shown, not changeable (a guest's view of the host's setting).
function Ui.fieldToggle(cell: Frame, on: boolean, onChange: ((boolean) -> ())?, onText: string?, offText: string?)
	local holder = Ui.frame(cell, "Toggle", UDim2.fromScale(1, 1))
	Kit.pad(holder, Kit.SPACE.m, 0, Kit.SPACE.m, 0)
	local l = Kit.list(holder, Kit.SPACE.s, true)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	local label: TextLabel
	local t = Kit.toggle(holder, on, function(v)
		label.Text = if v then onText or "On" else offText or "Off"
		if onChange then
			onChange(v)
		end
	end)
	t.button.LayoutOrder = 1
	label = Ui.label(holder, if on then onText or "On" else offText or "Off", "label", Kit.COLOR.text, 2)
	if onChange == nil then
		-- a cover takes the clicks; the switch stays as the host set it
		local cover = Instance.new("TextButton")
		cover.Name = "ReadOnly"
		cover.BackgroundTransparency = 1
		cover.Text = ""
		cover.AutoButtonColor = false
		cover.Size = UDim2.fromScale(1, 1)
		cover.ZIndex = holder.ZIndex + 5
		cover.Parent = cell
		t.button.BackgroundTransparency = 0.6
	end
end

-- Greys a button out (and back).
function Ui.enable(b: TextButton, on: boolean)
	b.Active = on
	b.AutoButtonColor = false
	b.TextTransparency = if on then 0 else 0.55
	b.BackgroundTransparency = if on then (if b.BackgroundTransparency >= 0.9 then b.BackgroundTransparency else 0) else math.max(b.BackgroundTransparency, 0.6)
end

-- The kit's text box (C-174).
Ui.input = Kit.input

function Ui.color(index: number?): Color3
	local c = Config.COLORS[index or 1] or Config.COLORS[1]
	return Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3])
end

-- A TeamColors colour (S-172); grey when there's none.
function Ui.rgb(c: { rgb: { number } }?): Color3
	if c == nil then
		return Color3.fromRGB(120, 120, 120)
	end
	return Color3.fromRGB(c.rgb[1], c.rgb[2], c.rgb[3])
end

function Ui.swatch(parent: Instance, color: Color3, size: number?): Frame
	local s = Instance.new("Frame")
	s.Name = "Swatch"
	s.Size = UDim2.fromOffset(size or 12, size or 12)
	s.BackgroundColor3 = color
	s.BorderSizePixel = 0
	s.Parent = parent
	corner(s, 3)
	return s
end

-- Removes everything but layouts, paddings and the like.
function Ui.clear(f: Instance)
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- A label that sizes to its text along X.
function Ui.label(parent: Instance, text: string, kind: string?, color: Color3?, order: number?): TextLabel
	local l = Kit.text(parent, text, kind, color)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.new(0, 0, 0, l.Size.Y.Offset)
	l.LayoutOrder = order or 0
	return l
end

function Ui.label2(key: string): string
	return (Config.LABELS :: any)[key] or key
end

-- A mode's name for `players` players: a two-player free for all is a 1v1.
function Ui.modeName(mode: string, players: number?): string
	if mode == "FFA" and players == 2 then
		return "1v1"
	end
	return Ui.label2(mode)
end

-- How long since `since` (the server's os.time()): "7 min", "under a minute".
function Ui.minutes(since: number): string
	local m = math.floor(math.max(0, workspace:GetServerTimeNow() - since) / 60)
	return if m < 1 then "under a minute" else `{m} min`
end

function Ui.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Ui

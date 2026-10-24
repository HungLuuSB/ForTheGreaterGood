--!strict
-- The lobby's small components on top of the client's UI kit (used
-- read-only, `@client/UI/Kit`), so the lobby looks like the game. BAR's
-- lobby colors its actions: green to go (start, ready, launch), red to
-- leave; everything else is the kit's.

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

local GO = Color3.fromRGB(70, 150, 84)
local STOP = Color3.fromRGB(168, 58, 52)

-- A kit button; style "go" (green), "stop" (red), "primary" (amber),
-- "ghost" (outlined) or nil (plain).
function Ui.button(parent: Instance, text: string, style: string?, onClick: () -> (), width: number?, height: number?): TextButton
	local b = Kit.button(parent, text, if style == "primary" or style == "ghost" then style else nil, onClick, width)
	b.Name = text -- findable by name (tests, the Studio MCP's clicks)
	if height then
		b.Size = UDim2.fromOffset(width or 120, height)
	end
	if style == "go" or style == "stop" then
		b.BackgroundColor3 = if style == "go" then GO else STOP
		b.BackgroundTransparency = 0
		b.TextColor3 = Color3.fromRGB(240, 244, 240)
		local base = 0
		b.MouseEnter:Connect(function()
			b.BackgroundColor3 = (if style == "go" then GO else STOP):Lerp(Color3.new(1, 1, 1), 0.12)
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundColor3 = if style == "go" then GO else STOP
			b.BackgroundTransparency = base
		end)
	end
	return b
end

-- Greys a button out (and back).
function Ui.enable(b: TextButton, on: boolean)
	b.Active = on
	b.AutoButtonColor = false
	b.TextTransparency = if on then 0 else 0.55
	b.BackgroundTransparency = if on then (if b.BackgroundTransparency >= 0.9 then b.BackgroundTransparency else 0) else math.max(b.BackgroundTransparency, 0.6)
end

-- A text box in the kit's control style (the kit has none yet: request 1).
function Ui.input(parent: Instance, placeholder: string, width: number?, onEnter: ((string) -> ())?): TextBox
	local t = Instance.new("TextBox")
	t.Name = "Input"
	t.Size = UDim2.fromOffset(width or 220, 30)
	t.BackgroundColor3 = Kit.COLOR.raised
	t.BackgroundTransparency = 0.94
	t.BorderSizePixel = 0
	t.FontFace = Kit.font(Enum.FontWeight.Regular)
	t.TextSize = 14
	t.TextColor3 = Kit.COLOR.text
	t.PlaceholderText = placeholder
	t.PlaceholderColor3 = Kit.COLOR.faint
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.ClearTextOnFocus = false
	t.Text = ""
	t.Parent = parent
	corner(t, Kit.CONTROL_RADIUS)
	stroke(t, 0.85)
	Kit.pad(t, Kit.SPACE.m, 0, Kit.SPACE.m, 0)
	if onEnter then
		t.FocusLost:Connect(function(enter: boolean)
			if enter then
				onEnter(t.Text)
			end
		end)
	end
	return t
end

function Ui.color(index: number?): Color3
	local c = Config.COLORS[index or 1] or Config.COLORS[1]
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

function Ui.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Ui

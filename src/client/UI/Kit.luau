--!strict
-- The UI kit (C-105): one theme and the components every panel uses, so
-- the settings, statistics, lobby and unit panels match. Style target: a
-- dark translucent panel with a thin light border, a soft shadow and a
-- faint diagonal stripe (our own, drawn in an EditableImage), light-grey
-- text in Montserrat (Roblox's built-in geometric sans), one warm amber
-- accent. Components:
--   panel (frame with title, optional sidebar nav with a highlighted pill)
--   toggle (green on, red off)   slider (with its value)   dropdown
--   segmented buttons   filter chips (with team color swatches)
--   thin scrollbar   button   table   line chart (Core/Chart, one
--   EditableImage per chart, drawn a chart per frame through a queue)
-- Sizes are in pixels before the settings' UI scale (a UIScale on the gui).

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Chart = require("../Core/Chart")

local Kit = {}

-- theme ----------------------------------------------------------------------

Kit.FAMILY = "rbxasset://fonts/families/Montserrat.json"
Kit.COLOR = table.freeze({
	panel = Color3.fromRGB(20, 22, 27),
	panelTransparency = 0.15, -- ~85% opaque
	raised = Color3.fromRGB(255, 255, 255), -- light overlays, used very transparent
	border = Color3.fromRGB(255, 255, 255),
	borderTransparency = 0.86,
	text = Color3.fromRGB(226, 229, 235),
	dim = Color3.fromRGB(150, 156, 168),
	faint = Color3.fromRGB(102, 108, 120),
	accent = Color3.fromRGB(238, 186, 92),
	on = Color3.fromRGB(96, 204, 122),
	off = Color3.fromRGB(216, 86, 76),
	selected = Color3.fromRGB(128, 98, 50), -- a chosen button's fill in the HUD panels (dark amber: white text stays readable)
	control = Color3.fromRGB(44, 48, 56), -- a HUD button's fill
	victory = Color3.fromRGB(132, 222, 140),
	defeat = Color3.fromRGB(236, 104, 92),
})
Kit.TYPE = table.freeze({ title = 26, section = 16, label = 14, small = 12 })
Kit.SPACE = table.freeze({ xs = 4, s = 8, m = 12, l = 16, xl = 24 })
Kit.RADIUS = 10 -- panels
Kit.CONTROL_RADIUS = 6
Kit.ROW = 34 -- a settings row's height

local WEIGHT = { title = Enum.FontWeight.SemiBold, section = Enum.FontWeight.SemiBold, label = Enum.FontWeight.Regular, small = Enum.FontWeight.Regular }

function Kit.font(weight: Enum.FontWeight?): Font
	return Font.new(Kit.FAMILY, weight or Enum.FontWeight.Regular)
end

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or Kit.CONTROL_RADIUS)
	c.Parent = parent
end

local function stroke(parent: Instance, transparency: number?, color: Color3?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color or Kit.COLOR.border
	s.Transparency = transparency or Kit.COLOR.borderTransparency
	s.Thickness = 1
	s.Parent = parent
end

-- A light overlay fill (hover, pills, tracks): white at `alpha`.
local function veil(frame: GuiObject, alpha: number)
	frame.BackgroundColor3 = Kit.COLOR.raised
	frame.BackgroundTransparency = 1 - alpha
	frame.BorderSizePixel = 0
end

-- shared images: the stripe tile and the soft shadow (drawn once) -------------

local images: { [string]: any } = {}

local function editable(key: string, size: number, fill: (buffer, number) -> ()): any
	if images[key] ~= nil then
		return images[key] or nil
	end
	local ok, img = pcall(function()
		return (AssetService :: any):CreateEditableImage({ Size = Vector2.new(size, size) })
	end)
	if not ok or img == nil then
		images[key] = false -- no editable memory: go without
		return nil
	end
	local buf = buffer.create(size * size * 4)
	fill(buf, size)
	img:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), buf)
	local content = (Content :: any).fromObject(img)
	images[key] = content
	return content
end

local function stripes(): any
	return editable("stripes", 16, function(buf, n)
		for y = 0, n - 1 do
			for x = 0, n - 1 do
				local o = (y * n + x) * 4
				buffer.writeu8(buf, o, 255)
				buffer.writeu8(buf, o + 1, 255)
				buffer.writeu8(buf, o + 2, 255)
				-- a 2-pixel line every 8 pixels, rising to the right
				buffer.writeu8(buf, o + 3, if (x + y) % 8 < 2 then 9 else 0)
			end
		end
	end)
end

local SHADOW = 64
local SHADOW_PAD = 22
local function shadow(): any
	return editable("shadow", SHADOW, function(buf, n)
		for y = 0, n - 1 do
			for x = 0, n - 1 do
				-- distance outside a rounded box inset by the pad, falling off softly
				local dx = math.max(SHADOW_PAD - x, x - (n - 1 - SHADOW_PAD), 0)
				local dy = math.max(SHADOW_PAD - y, y - (n - 1 - SHADOW_PAD), 0)
				local d = math.sqrt(dx * dx + dy * dy) / SHADOW_PAD
				local a = math.clamp(1 - d, 0, 1) ^ 2
				local o = (y * n + x) * 4
				buffer.writeu8(buf, o + 3, math.floor(a * 150))
			end
		end
	end)
end

-- text ------------------------------------------------------------------------

-- A text label of a type size ("title", "section", "label", "small").
function Kit.text(parent: Instance, text: string, kind: string?, color: Color3?): TextLabel
	local k = kind or "label"
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Kit.font(WEIGHT[k])
	l.TextSize = (Kit.TYPE :: any)[k]
	l.TextColor3 = color or (if k == "small" then Kit.COLOR.dim else Kit.COLOR.text)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Size = UDim2.new(1, 0, 0, (Kit.TYPE :: any)[k] + 10)
	l.Parent = parent
	return l
end

function Kit.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, padding or Kit.SPACE.s)
	if horizontal then
		l.FillDirection = Enum.FillDirection.Horizontal
		l.VerticalAlignment = Enum.VerticalAlignment.Center
	end
	l.Parent = parent
	return l
end

function Kit.pad(parent: Instance, l: number, t: number?, r: number?, b: number?)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, l)
	p.PaddingTop = UDim.new(0, t or l)
	p.PaddingRight = UDim.new(0, r or l)
	p.PaddingBottom = UDim.new(0, b or t or l)
	p.Parent = parent
end

-- A thin-scrollbar scrolling frame filling `parent` (content grows down).
function Kit.scroll(parent: Instance): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.Size = UDim2.fromScale(1, 1)
	s.ScrollBarThickness = 4
	s.ScrollBarImageColor3 = Kit.COLOR.raised
	s.ScrollBarImageTransparency = 0.7
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	s.Parent = parent
	return s
end

-- panel -----------------------------------------------------------------------

export type Panel = {
	root: Frame, -- holds the shadow and the panel; position and size this
	frame: Frame,
	content: Frame, -- the area right of the sidebar (or under the title)
	title: TextLabel,
	sidebar: Frame?,
	select: (name: string) -> (),
	selected: string?,
}

-- A panel of `size` centred in `parent`, titled `title`. With `nav` (item
-- names, "" for a divider), a sidebar lists them under the title with a
-- highlighted pill on the selected one; `onSelect(name)` is called on a
-- click and by panel.select.
function Kit.panel(parent: Instance, title: string, size: Vector2, nav: { string }?, onSelect: ((string) -> ())?): Panel
	local root = Instance.new("Frame")
	root.Name = title -- (the lobby's gui holds the lobby and the statistics panels)
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.Parent = parent
	local sh = shadow()
	if sh then
		local s = Instance.new("ImageLabel")
		s.Name = "Shadow"
		s.BackgroundTransparency = 1
		s.ImageContent = sh
		s.ScaleType = Enum.ScaleType.Slice
		s.SliceCenter = Rect.new(SHADOW_PAD + 2, SHADOW_PAD + 2, SHADOW - SHADOW_PAD - 2, SHADOW - SHADOW_PAD - 2)
		s.Position = UDim2.fromOffset(-SHADOW_PAD + 2, -SHADOW_PAD + 6)
		s.Size = UDim2.new(1, 2 * SHADOW_PAD - 4, 1, 2 * SHADOW_PAD - 4)
		s.ImageTransparency = 0.2
		s.ZIndex = 0
		s.Parent = root
	end
	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Kit.COLOR.panel
	frame.BackgroundTransparency = Kit.COLOR.panelTransparency
	frame.BorderSizePixel = 0
	frame.ZIndex = 1
	frame.Parent = root
	corner(frame, Kit.RADIUS)
	stroke(frame)
	local st = stripes()
	if st then
		local s = Instance.new("ImageLabel")
		s.Name = "Stripes"
		s.BackgroundTransparency = 1
		s.ImageContent = st
		s.ScaleType = Enum.ScaleType.Tile
		s.TileSize = UDim2.fromOffset(16, 16)
		s.Size = UDim2.fromScale(1, 1)
		s.Parent = frame
		corner(s, Kit.RADIUS)
	end
	-- never larger than the screen (at the settings' UI scale): contents scroll
	local function fit()
		local camera = workspace.CurrentCamera
		local vp = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
		local gui = root:FindFirstAncestorOfClass("ScreenGui")
		local uiScale = gui and gui:FindFirstChild("SettingsScale")
		local k = if uiScale and uiScale:IsA("UIScale") then uiScale.Scale else 1
		root.Size = UDim2.fromOffset(math.min(size.X, vp.X / k - 24), math.min(size.Y, vp.Y / k - 24))
	end
	fit()
	root:GetPropertyChangedSignal("Visible"):Connect(fit)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	local sideWidth = if nav then 210 else 0
	local titleLabel = Kit.text(frame, title, "title")
	titleLabel.Position = UDim2.fromOffset(Kit.SPACE.xl, Kit.SPACE.l)
	titleLabel.Size = UDim2.fromOffset(sideWidth > 0 and sideWidth - Kit.SPACE.xl or 400, 36)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	local p: Panel
	if nav then
		local side = Instance.new("Frame")
		side.Name = "Sidebar"
		side.BackgroundTransparency = 1
		side.Position = UDim2.fromOffset(Kit.SPACE.m, 68)
		side.Size = UDim2.new(0, sideWidth - Kit.SPACE.m * 2, 1, -80)
		side.Parent = frame
		Kit.list(side, 2)
		local buttons: { [string]: TextButton } = {}
		local divider = Instance.new("Frame")
		divider.BackgroundColor3 = Kit.COLOR.border
		divider.BackgroundTransparency = 0.9
		divider.BorderSizePixel = 0
		divider.Position = UDim2.fromOffset(sideWidth, Kit.SPACE.l)
		divider.Size = UDim2.new(0, 1, 1, -Kit.SPACE.l * 2)
		divider.Parent = frame
		for i, name in nav do
			if name == "" then
				local line = Instance.new("Frame")
				line.BackgroundColor3 = Kit.COLOR.border
				line.BackgroundTransparency = 0.9
				line.BorderSizePixel = 0
				line.Size = UDim2.new(1, 0, 0, 1)
				line.LayoutOrder = i
				line.Parent = side
				continue
			end
			local b = Instance.new("TextButton")
			b.Name = name
			b.AutoButtonColor = false
			b.Size = UDim2.new(1, 0, 0, 36)
			veil(b, 0)
			b.FontFace = Kit.font(Enum.FontWeight.Regular)
			b.TextSize = 15
			b.TextColor3 = Kit.COLOR.dim
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = name
			b.LayoutOrder = i
			b.Parent = side
			corner(b)
			Kit.pad(b, Kit.SPACE.m, 0, Kit.SPACE.m, 0)
			buttons[name] = b
			b.MouseEnter:Connect(function()
				if p.selected ~= name then
					b.BackgroundTransparency = 0.96
				end
			end)
			b.MouseLeave:Connect(function()
				if p.selected ~= name then
					b.BackgroundTransparency = 1
				end
			end)
			b.MouseButton1Click:Connect(function()
				p.select(name)
			end)
		end
		content.Position = UDim2.fromOffset(sideWidth + Kit.SPACE.l, Kit.SPACE.l)
		content.Size = UDim2.new(1, -sideWidth - Kit.SPACE.l * 2, 1, -Kit.SPACE.l * 2)
		content.Parent = frame
		p = {
			root = root,
			frame = frame,
			content = content,
			title = titleLabel,
			sidebar = side,
			selected = nil,
			select = function(name: string)
				p.selected = name
				for n, b in buttons do
					local on = n == name
					b.BackgroundTransparency = if on then 0.9 else 1
					b.TextColor3 = if on then Kit.COLOR.text else Kit.COLOR.dim
					b.FontFace = Kit.font(if on then Enum.FontWeight.Medium else Enum.FontWeight.Regular)
				end
				if onSelect then
					onSelect(name)
				end
			end,
		}
	else
		content.Position = UDim2.fromOffset(Kit.SPACE.xl, 60)
		content.Size = UDim2.new(1, -Kit.SPACE.xl * 2, 1, -60 - Kit.SPACE.l)
		content.Parent = frame
		p = { root = root, frame = frame, content = content, title = titleLabel, sidebar = nil, selected = nil, select = function(_: string) end }
	end
	return p
end

-- A section heading inside a page.
function Kit.section(parent: Instance, text: string, order: number?): TextLabel
	local l = Kit.text(parent, text, "section")
	l.Size = UDim2.new(1, 0, 0, 30)
	l.LayoutOrder = order or 0
	return l
end

-- A settings row: the label on the left, the control holder on the right
-- (controls added to it line up from the right edge).
function Kit.row(parent: Instance, label: string, order: number?, height: number?): Frame
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1
	r.Size = UDim2.new(1, 0, 0, height or Kit.ROW)
	r.LayoutOrder = order or 0
	r.Parent = parent
	local l = Kit.text(r, label, "label")
	l.Size = UDim2.new(0.45, 0, 1, 0)
	local holder = Instance.new("Frame")
	holder.Name = "Control"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.fromScale(1, 0)
	holder.Size = UDim2.new(0.55, 0, 1, 0)
	holder.Parent = r
	local list = Kit.list(holder, Kit.SPACE.s, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	return holder
end

-- controls --------------------------------------------------------------------

export type Toggle = { button: TextButton, set: (on: boolean) -> () }

-- A switch: a dark track with a square knob, green on the right when on,
-- red on the left when off.
function Kit.toggle(parent: Instance, on: boolean, onChange: (boolean) -> ()): Toggle
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(44, 22)
	b.BackgroundColor3 = Color3.fromRGB(10, 11, 14)
	b.BackgroundTransparency = 0.3
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 5)
	stroke(b, 0.85)
	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.BorderSizePixel = 0
	knob.Parent = b
	corner(knob, 3)
	local state = on
	local t: Toggle
	t = {
		button = b,
		set = function(v: boolean)
			state = v
			knob.Position = if v then UDim2.new(1, -18, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)
			knob.BackgroundColor3 = if v then Kit.COLOR.on else Kit.COLOR.off
		end,
	}
	t.set(on)
	b.MouseButton1Click:Connect(function()
		t.set(not state)
		onChange(state)
	end)
	return t
end

export type Slider = { frame: Frame, set: (value: number) -> () }

-- A slider from `min` to `max` in `step`s with its value (formatted by
-- `fmt`) on the right; `onChange` while dragging and on release.
function Kit.slider(parent: Instance, min: number, max: number, step: number, value: number, fmt: string, onChange: (number) -> (), width: number?): Slider
	local f = Instance.new("Frame")
	f.Name = "Slider"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset((width or 200) + 56, 22)
	f.Parent = parent
	local track = Instance.new("TextButton")
	track.AutoButtonColor = false
	track.Text = ""
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 0, 0.5, 0)
	track.Size = UDim2.new(0, width or 200, 0, 6)
	veil(track, 0.1)
	track.Parent = f
	corner(track, 3)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Kit.COLOR.accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, 3)
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(14, 14)
	knob.BackgroundColor3 = Kit.COLOR.text
	knob.BorderSizePixel = 0
	knob.Parent = track
	corner(knob, 7)
	local label = Kit.text(f, "", "label")
	label.AnchorPoint = Vector2.new(1, 0)
	label.Position = UDim2.fromScale(1, 0)
	label.Size = UDim2.new(0, 48, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Right
	local current = value
	local s: Slider
	s = {
		frame = f,
		set = function(v: number)
			current = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
			local k = (current - min) / math.max(max - min, 1e-9)
			fill.Size = UDim2.fromScale(k, 1)
			knob.Position = UDim2.fromScale(k, 0.5)
			label.Text = string.format(fmt, current)
		end,
	}
	s.set(value)
	local dragging = false
	local function at(x: number)
		local k = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		local before = current
		s.set(min + k * (max - min))
		if current ~= before then
			onChange(current)
		end
	end
	track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			at(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			at(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	return s
end

-- A button: "primary" (amber), "ghost" (outlined) or plain.
function Kit.button(parent: Instance, text: string, kind: string?, onClick: () -> (), width: number?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(width or 120, 30)
	b.FontFace = Kit.font(Enum.FontWeight.Medium)
	b.TextSize = 14
	b.Text = text
	b.BorderSizePixel = 0
	if kind == "primary" then
		b.BackgroundColor3 = Kit.COLOR.accent
		b.BackgroundTransparency = 0
		b.TextColor3 = Color3.fromRGB(28, 22, 12)
	else
		veil(b, if kind == "ghost" then 0 else 0.07)
		b.TextColor3 = Kit.COLOR.text
		stroke(b, if kind == "ghost" then 0.75 else 0.88)
	end
	b.Parent = parent
	corner(b)
	local base = b.BackgroundTransparency
	b.MouseEnter:Connect(function()
		b.BackgroundTransparency = math.max(0, base - 0.06)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundTransparency = base
	end)
	b.MouseButton1Click:Connect(onClick)
	return b
end

export type Segmented = { frame: Frame, set: (value: string) -> () }

-- Segmented buttons: one rounded group, the chosen segment a lit pill.
-- `options`: { { value, label } }.
function Kit.segmented(parent: Instance, options: { { string } }, value: string, onChange: (string) -> (), segWidth: number?): Segmented
	local w = segWidth or 84
	local f = Instance.new("Frame")
	f.Name = "Segmented"
	f.Size = UDim2.fromOffset(#options * w + 4, 28)
	veil(f, 0.05)
	f.Parent = parent
	corner(f)
	stroke(f, 0.88)
	Kit.pad(f, 2)
	Kit.list(f, 0, true)
	local buttons: { [string]: TextButton } = {}
	local seg: Segmented
	seg = {
		frame = f,
		set = function(v: string)
			for val, b in buttons do
				local on = val == v
				b.BackgroundTransparency = if on then 0.82 else 1
				b.TextColor3 = if on then Kit.COLOR.text else Kit.COLOR.dim
			end
		end,
	}
	for i, o in options do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(w, 24)
		veil(b, 0)
		b.FontFace = Kit.font(Enum.FontWeight.Medium)
		b.TextSize = 13
		b.Text = o[2]
		b.TextTruncate = Enum.TextTruncate.AtEnd
		b.LayoutOrder = i
		b.Parent = f
		corner(b, Kit.CONTROL_RADIUS - 2)
		buttons[o[1]] = b
		b.MouseButton1Click:Connect(function()
			seg.set(o[1])
			onChange(o[1])
		end)
	end
	seg.set(value)
	return seg
end

export type Dropdown = { button: TextButton, set: (value: string) -> () }

-- A dropdown: the current choice with a chevron; a click opens the list
-- below it (over everything in the panel). `options`: { { value, label } }.
function Kit.dropdown(parent: Instance, options: { { string } }, value: string, onChange: (string) -> (), width: number?): Dropdown
	local b = Instance.new("TextButton")
	b.Name = "Dropdown"
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(width or 180, 28)
	veil(b, 0.06)
	b.FontFace = Kit.font(Enum.FontWeight.Regular)
	b.TextSize = 14
	b.TextColor3 = Kit.COLOR.text
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.Parent = parent
	corner(b)
	stroke(b, 0.85)
	Kit.pad(b, Kit.SPACE.m, 0, 26, 0)
	-- the chevron: two short bars (Montserrat has no arrow glyphs)
	local chevron = Instance.new("Frame")
	chevron.BackgroundTransparency = 1
	chevron.AnchorPoint = Vector2.new(1, 0.5)
	chevron.Position = UDim2.new(1, 16, 0.5, 1)
	chevron.Size = UDim2.fromOffset(12, 8)
	chevron.Parent = b
	for i, angle in { 45, -45 } do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromOffset(if i == 1 then 3.5 else 8.5, 2)
		bar.Size = UDim2.fromOffset(7, 1.6)
		bar.Rotation = angle
		bar.BackgroundColor3 = Kit.COLOR.dim
		bar.BorderSizePixel = 0
		bar.Parent = chevron
	end
	local list = Instance.new("Frame")
	list.Name = "Options"
	list.Visible = false
	list.Position = UDim2.new(0, -Kit.SPACE.m, 1, 4)
	list.Size = UDim2.new(1, Kit.SPACE.m + 26, 0, #options * 28 + 8)
	list.BackgroundColor3 = Color3.fromRGB(28, 31, 38)
	list.BorderSizePixel = 0
	list.ZIndex = 20
	list.Parent = b
	corner(list)
	stroke(list, 0.8)
	Kit.pad(list, 4)
	Kit.list(list, 0)
	local labels: { [string]: string } = {}
	local dd: Dropdown
	dd = {
		button = b,
		set = function(v: string)
			b.Text = labels[v] or v
		end,
	}
	for i, o in options do
		labels[o[1]] = o[2]
		local item = Instance.new("TextButton")
		item.AutoButtonColor = false
		item.Size = UDim2.new(1, 0, 0, 28)
		veil(item, 0)
		item.FontFace = Kit.font(Enum.FontWeight.Regular)
		item.TextSize = 14
		item.TextColor3 = Kit.COLOR.text
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.Text = o[2]
		item.LayoutOrder = i
		item.ZIndex = 21
		item.Parent = list
		corner(item, 4)
		Kit.pad(item, Kit.SPACE.s, 0, Kit.SPACE.s, 0)
		item.MouseEnter:Connect(function()
			item.BackgroundTransparency = 0.92
		end)
		item.MouseLeave:Connect(function()
			item.BackgroundTransparency = 1
		end)
		item.MouseButton1Click:Connect(function()
			list.Visible = false
			dd.set(o[1])
			onChange(o[1])
		end)
	end
	b.MouseButton1Click:Connect(function()
		list.Visible = not list.Visible
	end)
	dd.set(value)
	return dd
end

export type Chip = { button: TextButton, set: (on: boolean) -> () }

-- A filter chip: its label and small team color swatches; the selected
-- chip has the accent outline.
function Kit.chip(parent: Instance, label: string, swatches: { Color3 }, onClick: () -> ()): Chip
	local b = Instance.new("TextButton")
	b.Name = "Chip"
	b.AutoButtonColor = false
	b.Text = ""
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 30)
	veil(b, 0.05)
	b.Parent = parent
	corner(b)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Thickness = 1
	s.Parent = b
	Kit.pad(b, Kit.SPACE.m, 0, Kit.SPACE.m, 0)
	Kit.list(b, Kit.SPACE.s, true)
	local l = Kit.text(b, label, "label")
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, 30)
	l.LayoutOrder = 0
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.AutomaticSize = Enum.AutomaticSize.X
	strip.Size = UDim2.fromOffset(0, 14)
	strip.LayoutOrder = 1
	strip.Parent = b
	Kit.list(strip, 0, true)
	for i, c in swatches do
		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(14, 14)
		sw.BackgroundColor3 = c
		sw.BorderSizePixel = 0
		sw.LayoutOrder = i
		sw.Parent = strip
	end
	local chip: Chip
	chip = {
		button = b,
		set = function(on: boolean)
			s.Color = if on then Kit.COLOR.accent else Kit.COLOR.border
			s.Transparency = if on then 0.1 else 0.88
			l.TextColor3 = if on then Kit.COLOR.text else Kit.COLOR.dim
		end,
	}
	chip.set(false)
	b.MouseButton1Click:Connect(onClick)
	return chip
end

-- table -----------------------------------------------------------------------

export type Column = { title: string, width: number, align: string? } -- width: share of the row (0..1)

-- A table: a header row (small, dim) and one row per entry, alternate rows
-- faintly lit. Cells are text, or a function(cell: Frame) that fills it.
function Kit.table(parent: Instance, columns: { Column }, rows: { { any } }, rowHeight: number?, order: number?): Frame
	local h = rowHeight or 30
	local t = Instance.new("Frame")
	t.Name = "Table"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, (#rows + 1) * h)
	t.LayoutOrder = order or 0
	t.Parent = parent
	Kit.list(t, 0)
	local function line(cells: { any }, header: boolean, i: number)
		local r = Instance.new("Frame")
		r.Size = UDim2.new(1, 0, 0, h)
		veil(r, if not header and i % 2 == 0 then 0.03 else 0)
		r.LayoutOrder = i
		r.Parent = t
		if not header then
			corner(r, 4)
		end
		local x = 0
		for c, col in columns do
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Position = UDim2.fromScale(x, 0)
			cell.Size = UDim2.fromScale(col.width, 1)
			cell.Parent = r
			Kit.pad(cell, Kit.SPACE.s, 0, Kit.SPACE.s, 0)
			x += col.width
			local v = cells[c]
			if type(v) == "function" then
				v(cell)
			else
				local l = Kit.text(cell, tostring(v or ""), if header then "small" else "label", if header then Kit.COLOR.faint else nil)
				l.Size = UDim2.fromScale(1, 1)
				l.TextTruncate = Enum.TextTruncate.AtEnd
				l.TextXAlignment = if col.align == "right" then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
			end
		end
	end
	local titles = {}
	for i, col in columns do
		titles[i] = col.title
	end
	line(titles, true, 0)
	for i, cells in rows do
		line(cells, false, i)
	end
	return t
end

-- skin ------------------------------------------------------------------------

local FONT_WEIGHT: { [Enum.Font]: Enum.FontWeight } = {
	[Enum.Font.Gotham] = Enum.FontWeight.Regular,
	[Enum.Font.GothamMedium] = Enum.FontWeight.Medium,
	[Enum.Font.GothamBold] = Enum.FontWeight.SemiBold,
	[Enum.Font.GothamBlack] = Enum.FontWeight.Bold,
	[Enum.Font.SourceSans] = Enum.FontWeight.Regular,
	[Enum.Font.SourceSansBold] = Enum.FontWeight.SemiBold,
}

local function skinOne(d: Instance)
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		local w = FONT_WEIGHT[d.Font]
		if w then
			d.FontFace = Kit.font(w)
		end
	end
	if d:IsA("Frame") and d.BackgroundTransparency < 1 and d.BackgroundColor3 == Kit.COLOR.panel then
		-- a panel: the kit's border and corners
		if d:FindFirstChildOfClass("UIStroke") == nil then
			stroke(d)
		end
		if d:FindFirstChildOfClass("UICorner") == nil then
			corner(d, 8)
		end
	elseif d:IsA("GuiButton") and d.BackgroundTransparency < 1 then
		if d:FindFirstChildOfClass("UICorner") == nil then
			corner(d, 4)
		end
		if d:FindFirstChildOfClass("UIStroke") == nil then
			stroke(d, 0.9)
		end
	end
end

-- Gives a HUD screen built before the kit the kit's look: Montserrat for
-- Gotham text, the panel border and corners, rounded outlined buttons;
-- elements added later get it too. (The modules' colors come from
-- Kit.COLOR: panel, control, selected.)
function Kit.skin(gui: Instance)
	for _, d in gui:GetDescendants() do
		skinOne(d)
	end
	gui.DescendantAdded:Connect(function(d: Instance)
		task.defer(skinOne, d) -- after the code that made it sets it up
	end)
end

-- line chart ------------------------------------------------------------------

export type ChartLine = { xs: { number }, ys: { number }, color: Color3 }
export type LineChart = {
	frame: Frame,
	set: (lines: { ChartLine }, xMax: number) -> (),
	note: (text: string?) -> (), -- a centred message instead of lines (no data yet)
}

local queue: { () -> () } = {}
local pumping = false
Kit.chartStats = { drawn = 0, lastMs = 0, maxMs = 0 }

-- Charts draw one per frame (Core/Chart.raster takes a few ms each), so
-- building or refiltering a page never hitches.
local function enqueue(job: () -> ())
	table.insert(queue, job)
	if pumping then
		return
	end
	pumping = true
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local j = table.remove(queue, 1)
		if j then
			local t0 = os.clock()
			j()
			local ms = (os.clock() - t0) * 1000
			Kit.chartStats.drawn += 1
			Kit.chartStats.lastMs = ms
			Kit.chartStats.maxMs = math.max(Kit.chartStats.maxMs, ms)
		end
		if #queue == 0 then
			pumping = false
			conn:Disconnect()
		end
	end)
end

Kit.PLOT = Vector2.new(220, 118) -- plot area pixels (also the image size); three charts fit across the statistics panel

-- A small line chart titled `title` (e.g. "Supply · Produced"): minimal
-- axes (0, the top value, 0:00 and the end time), lines drawn into one
-- EditableImage.
function Kit.chart(parent: Instance, title: string, order: number?): LineChart
	local W, H = Kit.PLOT.X, Kit.PLOT.Y
	local f = Instance.new("Frame")
	f.Name = "Chart"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(W + 44, H + 44)
	f.LayoutOrder = order or 0
	f.Parent = parent
	local t = Kit.text(f, title, "label")
	t.Size = UDim2.new(1, 0, 0, 20)
	local plot = Instance.new("Frame")
	plot.Name = "Plot"
	plot.BackgroundTransparency = 1
	plot.Position = UDim2.fromOffset(40, 22)
	plot.Size = UDim2.fromOffset(W, H)
	plot.Parent = f
	-- axes: left and bottom lines, a faint middle grid line
	local function rule(pos: UDim2, size: UDim2, alpha: number)
		local r = Instance.new("Frame")
		r.BackgroundColor3 = Kit.COLOR.raised
		r.BackgroundTransparency = 1 - alpha
		r.BorderSizePixel = 0
		r.Position = pos
		r.Size = size
		r.Parent = plot
	end
	rule(UDim2.fromOffset(0, 0), UDim2.new(0, 1, 1, 0), 0.25)
	rule(UDim2.new(0, 0, 1, -1), UDim2.new(1, 0, 0, 1), 0.25)
	rule(UDim2.new(0, 0, 0.5, 0), UDim2.new(1, 0, 0, 1), 0.06)
	rule(UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 1), 0.06)
	local function axisLabel(text: string, pos: UDim2, anchor: Vector2, align: Enum.TextXAlignment): TextLabel
		local l = Kit.text(f, text, "small", Kit.COLOR.faint)
		l.AnchorPoint = anchor
		l.Position = pos
		l.Size = UDim2.fromOffset(38, 14)
		l.TextXAlignment = align
		return l
	end
	local yTop = axisLabel("", UDim2.fromOffset(36, 22), Vector2.new(1, 0.5), Enum.TextXAlignment.Right)
	local yMid = axisLabel("", UDim2.fromOffset(36, 22 + H / 2), Vector2.new(1, 0.5), Enum.TextXAlignment.Right)
	axisLabel("0", UDim2.fromOffset(36, 22 + H), Vector2.new(1, 0.5), Enum.TextXAlignment.Right)
	axisLabel("0:00", UDim2.fromOffset(40, 24 + H), Vector2.new(0, 0), Enum.TextXAlignment.Left)
	local xEnd = axisLabel("", UDim2.fromOffset(40 + W, 24 + H), Vector2.new(1, 0), Enum.TextXAlignment.Right)
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = plot
	local note = Kit.text(plot, "", "small", Kit.COLOR.faint)
	note.Size = UDim2.fromScale(1, 1)
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.TextWrapped = true
	local editableImage: any = nil
	local buf = buffer.create(W * H * 4)
	local c: LineChart
	c = {
		frame = f,
		note = function(text: string?)
			note.Text = text or ""
			image.Visible = text == nil
		end,
		set = function(lines: { ChartLine }, xMax: number)
			local top = 0
			for _, l in lines do
				for _, y in l.ys do
					top = math.max(top, y)
				end
			end
			top = Chart.niceMax(top)
			yTop.Text = Chart.format(top)
			yMid.Text = Chart.format(top / 2)
			xEnd.Text = Chart.clock(xMax)
			c.note(nil)
			enqueue(function()
				if editableImage == nil then
					local ok, img = pcall(function()
						return (AssetService :: any):CreateEditableImage({ Size = Vector2.new(W, H) })
					end)
					if not ok or img == nil then
						c.note("not enough image memory for charts")
						return
					end
					editableImage = img
					image.ImageContent = (Content :: any).fromObject(img)
				end
				local raster = {}
				for _, l in lines do
					local xs, ys = Chart.downsample(l.xs, l.ys)
					table.insert(raster, { xs = xs, ys = ys, r = math.floor(l.color.R * 255), g = math.floor(l.color.G * 255), b = math.floor(l.color.B * 255) })
				end
				Chart.raster(buf, W, H, raster, math.max(xMax, 1e-6), top)
				editableImage:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), buf)
			end)
		end,
	}
	return c
end

return Kit

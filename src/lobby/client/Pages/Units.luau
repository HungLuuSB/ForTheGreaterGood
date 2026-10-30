--!strict
-- The unit encyclopedia (L-18), a wiki of both factions: the list of units
-- and structures by role on the left (faction, search, units or
-- structures, tier), the 3D showroom in the middle (Showroom: the unit on
-- its place, turning; place, turntable, light, colour and Compare under
-- it), and the article on the right: what it is, its counterpart in the
-- other faction with how they differ, its in-game values, its weapons,
-- what it builds and what builds it. Everything comes from the shared defs
-- (shared/Codex); nothing is sent to the server.

local Codex = require("../../shared/Codex")
local Config = require("../../shared/Config")
local Defs = require("@shared/Defs/Defs")
local UserInputService = game:GetService("UserInputService")

local IconAtlas = require("@client/UI/IconAtlas")
local UnitPictures = require("@client/UI/UnitPictures")
local Emblem = require("../Emblem")
local Showroom = require("../Showroom")
local StatBars = require("../StatBars")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Units = {}

local LIST_W = 300
local ARTICLE_W = 440
local LABEL_CELL = Color3.fromRGB(13, 14, 18)
local VALUE_CELL = Color3.fromRGB(33, 36, 43)

local CLASS_NAME = { LIGHT = "Light", ARMORED = "Armored", STRUCTURE = "Structure", AIR = "Air", SHIP = "Ship", SUB = "Submarine" }
local MOVE_NAME = {
	TRACKED = "Tracked",
	HEAVY_TRACKED = "Heavy tracked",
	WHEELED = "Wheeled",
	AMPHIB = "Amphibious",
	HOVER = "Hover",
	JET = "Jet",
	HELI = "Helicopter",
	SHIP = "Ship",
	SUB = "Submarine",
}
local KIND_NAME = { BALLISTIC = "ballistic", HOMING = "guided missile", BEAM = "beam", TORPEDO = "torpedo", LASER = "laser", BOMB = "bombs", ROCKET = "rockets" }

local function factionColor(f: string): Color3
	return if f == "order" then Showroom.ORDER else Showroom.CHAOS
end

local function n(x: number): string
	if x >= 1000 then
		-- thousands separated: 3600 -> "3,600"
		local grouped = string.reverse((string.gsub(string.reverse(tostring(math.floor(x + 0.5))), "(%d%d%d)", "%1,")))
		local out = string.gsub(grouped, "^,", "")
		return out
	end
	if x >= 100 or x == math.floor(x) then
		return tostring(math.floor(x + 0.5))
	end
	return string.format("%.1f", x)
end

-- "ord_heavy_cannon" -> "Heavy cannon"
local function weaponName(id: string): string
	local s = string.gsub(string.gsub(id, "^%a%a%a_", ""), "_", " ")
	return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local function icon(parent: Instance, def: any, size: number, color: Color3): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromOffset(size, size * IconAtlas.TILE_H / IconAtlas.TILE_W)
	img.ImageColor3 = color
	img.ScaleType = Enum.ScaleType.Fit
	local e = (IconAtlas :: any).byDef[def.id]
	local tile = e and (IconAtlas :: any).tiles[e.tile]
	if tile then
		img.Image = IconAtlas.images[tile[3]] or ""
		img.ImageRectOffset = Vector2.new(tile[1], tile[2])
		img.ImageRectSize = Vector2.new(IconAtlas.TILE_W, IconAtlas.TILE_H)
	end
	img.Parent = parent
	return img
end

-- 2d-E's pre-rendered picture of a def, `px` square with rounded corners;
-- nil while it has none (or its sheet isn't uploaded): callers draw the icon.
local function picture(parent: Instance, defId: string, px: number): ImageLabel?
	local image, x, y = UnitPictures.of(defId)
	if image == nil then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Picture"
	img.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	img.BackgroundTransparency = 0
	img.Size = UDim2.fromOffset(px, px)
	img.Image = image
	img.ImageRectOffset = Vector2.new(x, y)
	img.ImageRectSize = Vector2.new(UnitPictures.TILE, UnitPictures.TILE)
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = parent
	Ui.corner(img, 4)
	return img
end

-- An infobox row: a darker label cell joined to a value cell whose text
-- wraps (the room's rows, references 1).
local function info(parent: Instance, label: string, value: string, order: number, color: Color3?)
	-- the row is as tall as its value text (sized by hand: an automatic size
	-- would also grow with the label cell, which takes the row's height)
	local row = Ui.frame(parent, label, UDim2.new(1, 0, 0, 30))
	row.LayoutOrder = order
	row.BackgroundColor3 = VALUE_CELL
	row.BackgroundTransparency = 0
	Ui.corner(row, Kit.CONTROL_RADIUS)
	local cell = Ui.frame(row, "Label", UDim2.new(0, 132, 1, 0))
	cell.BackgroundColor3 = LABEL_CELL
	cell.BackgroundTransparency = 0
	Ui.corner(cell, Kit.CONTROL_RADIUS)
	local join = Ui.frame(cell, "Join", UDim2.new(0, Kit.CONTROL_RADIUS, 1, 0), UDim2.new(1, -Kit.CONTROL_RADIUS, 0, 0))
	join.BackgroundColor3 = LABEL_CELL
	join.BackgroundTransparency = 0
	local l = Kit.text(cell, label, "small", Kit.COLOR.dim)
	l.Position = UDim2.fromOffset(Kit.SPACE.m, 0)
	l.Size = UDim2.new(1, -Kit.SPACE.m, 1, 0)
	local v = Kit.text(row, value, "label", color or Kit.COLOR.text)
	v.Position = UDim2.fromOffset(132 + Kit.SPACE.m, 0)
	v.TextWrapped = true
	-- measured from the wrapped text (an automatic size measures one line
	-- before the width is known)
	local width = -132 - Kit.SPACE.m * 2
	local function fit()
		v.Size = UDim2.new(1, width, 0, 400)
		local h = math.max(30, v.TextBounds.Y + 14)
		v.Size = UDim2.new(1, width, 0, h)
		row.Size = UDim2.new(1, 0, 0, h)
	end
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if math.abs(v.AbsoluteSize.X - (row.AbsoluteSize.X + width)) > 1 then
			fit()
		end
	end)
	fit()
	task.defer(fit)
end

local function paragraph(parent: Instance, text: string, order: number, kind: string?, color: Color3?): TextLabel
	local l = Kit.text(parent, text, kind or "label", color)
	l.TextWrapped = true
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(1, 0, 0, 0)
	l.LayoutOrder = order
	l.RichText = true
	return l
end

-- A wrapping row of link chips (unit names that open their article).
local function chips(parent: Instance, codex: Codex.Codex, ids: { string }, order: number, open: (string) -> ())
	local flow = Ui.frame(parent, "Chips", UDim2.new(1, 0, 0, 0))
	flow.AutomaticSize = Enum.AutomaticSize.Y
	flow.LayoutOrder = order
	local fl = Kit.list(flow, 6, true)
	fl.Wraps = true
	for i, id in ids do
		local e = codex.entries[id]
		local def = codex.defs.units[id]
		if def == nil then
			continue
		end
		local b = Instance.new("TextButton")
		b.Name = id
		b.AutoButtonColor = false
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 28)
		b.BackgroundColor3 = Kit.COLOR.raised
		b.BackgroundTransparency = 0.93
		b.Text = ""
		b.LayoutOrder = i
		b.Parent = flow
		Ui.corner(b, 5)
		Kit.pad(b, 6, 0, Kit.SPACE.s, 0)
		local bl = Kit.list(b, 5, true)
		bl.VerticalAlignment = Enum.VerticalAlignment.Center
		icon(b, def, 16, factionColor(def.faction)).LayoutOrder = 1
		Ui.label(b, def.name, "small", if e then Kit.COLOR.text else Kit.COLOR.dim, 2)
		if e then
			b.MouseButton1Click:Connect(function()
				open(id)
			end)
		end
	end
end

-- A counterpart's card: its picture (else its icon), its name, and its
-- role and tier; opens its article.
local function counterpartCard(parent: Instance, codex: Codex.Codex, id: string, order: number, open: (string) -> ())
	local def = codex.defs.units[id]
	local e = codex.entries[id]
	if def == nil then
		return
	end
	local b = Instance.new("TextButton")
	b.Name = id
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.new(1, 0, 0, 88)
	b.BackgroundColor3 = Kit.COLOR.raised
	b.BackgroundTransparency = 0.93
	b.LayoutOrder = order
	b.Parent = parent
	Ui.corner(b, 6)
	Kit.pad(b, 6, 6, 6, 6)
	local bl = Kit.list(b, Kit.SPACE.m, true)
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	local pic = picture(b, id, 76)
	if pic then
		pic.LayoutOrder = 1
	else
		icon(b, def, 40, factionColor(def.faction)).LayoutOrder = 1
	end
	local text = Ui.frame(b, "Text", UDim2.new(1, -90, 1, 0))
	text.LayoutOrder = 2
	local tl = Kit.list(text, 2)
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	local name = Kit.text(text, def.name, "section", if e then Kit.COLOR.text else Kit.COLOR.dim)
	name.Size = UDim2.new(1, 0, 0, 22)
	name.LayoutOrder = 1
	local sub = Kit.text(text, `<font color="#{factionColor(def.faction):ToHex()}">{Ui.label2(def.faction)}</font>  ·  {if e and e.role then e.role.name else "Unit"}  ·  {Codex.tierName(def.tier)}`, "small", Kit.COLOR.dim)
	sub.RichText = true
	sub.Size = UDim2.new(1, 0, 0, 16)
	sub.LayoutOrder = 2
	if e then
		b.MouseEnter:Connect(function()
			b.BackgroundTransparency = 0.86
		end)
		b.MouseLeave:Connect(function()
			b.BackgroundTransparency = 0.93
		end)
		b.MouseButton1Click:Connect(function()
			open(id)
		end)
	end
end

function Units.new(frame: Frame, _router: any): any
	local codex: Codex.Codex? = nil
	local faction = "order"
	local filter = "all"
	local tierFilter = "all"
	local selected: string? = nil
	local compare = false
	local colorChoice: number? = nil -- nil: faction colours
	local refreshFire: () -> ()
	local setFullView: (boolean) -> ()

	-- left: the list ---------------------------------------------------------
	local left = Ui.card(frame, "List", UDim2.new(0, LIST_W, 1, 0), nil, 0.08)
	Kit.pad(left, Kit.SPACE.m, Kit.SPACE.m)
	local head = Ui.frame(left, "Head", UDim2.new(1, 0, 0, 176))
	Kit.list(head, Kit.SPACE.s)
	local title = Kit.text(head, "Units", "title")
	title.TextSize = 30
	title.Size = UDim2.new(1, 0, 0, 36)
	title.LayoutOrder = 1
	local render: () -> ()
	local factionOptions = { { "order", "Order" }, { "chaos", "Chaos" } }
	local factionSeg = Kit.segmented(head, factionOptions, faction, function(v)
		faction = v
		render()
	end, 136)
	factionSeg.frame.LayoutOrder = 2
	Emblem.decorate(factionSeg.frame, factionOptions)
	local search = Ui.input(head, "Search units and roles", LIST_W - Kit.SPACE.m * 2)
	search.LayoutOrder = 3
	Kit.segmented(head, { { "all", "All" }, { "units", "Units" }, { "structures", "Structures" } }, filter, function(v)
		filter = v
		render()
	end, 90).frame.LayoutOrder = 4
	Kit.segmented(head, { { "all", "All tiers" }, { "1", "T1" }, { "2", "T2" }, { "3", "T3" } }, tierFilter, function(v)
		tierFilter = v
		render()
	end, 68).frame.LayoutOrder = 5
	local listHolder = Ui.frame(left, "Entries", UDim2.new(1, 0, 1, -184), UDim2.fromOffset(0, 184))
	local list = Kit.scroll(listHolder)
	Kit.list(list, 2)

	-- right: the article -----------------------------------------------------
	local right = Ui.card(frame, "Article", UDim2.new(0, ARTICLE_W, 1, 0), UDim2.new(1, -ARTICLE_W, 0, 0), 0.08)
	Kit.pad(right, Kit.SPACE.l, Kit.SPACE.m, Kit.SPACE.s, Kit.SPACE.m)
	local article = Kit.scroll(right)
	Kit.list(article, Kit.SPACE.s)
	Kit.pad(article, 0, 0, Kit.SPACE.s, Kit.SPACE.l)

	-- middle: the stage --------------------------------------------------------
	local stage = Instance.new("TextButton")
	stage.Name = "Stage"
	stage.AutoButtonColor = false
	stage.BackgroundTransparency = 1
	stage.Text = ""
	stage.Position = UDim2.fromOffset(LIST_W + Kit.SPACE.l, 0)
	stage.Size = UDim2.new(1, -(LIST_W + ARTICLE_W + Kit.SPACE.l * 2), 1, 0)
	stage.Parent = frame
	Showroom.setRegion(stage)
	local stageName = Kit.text(stage, "", "title", Color3.new(1, 1, 1))
	stageName.TextSize = 34
	stageName.Size = UDim2.new(1, 0, 0, 42)
	stageName.TextXAlignment = Enum.TextXAlignment.Center
	local stageSub = Kit.text(stage, "", "label", Color3.fromRGB(214, 218, 226))
	stageSub.Position = UDim2.fromOffset(0, 42)
	stageSub.Size = UDim2.new(1, 0, 0, 22)
	stageSub.TextXAlignment = Enum.TextXAlignment.Center
	for _, l in { stageName, stageSub } do
		local outline = Instance.new("UIStroke")
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		outline.Color = Color3.new(0, 0, 0)
		outline.Thickness = 1.5
		outline.Transparency = 0.4
		outline.Parent = l
	end
	local hint = Kit.text(stage, "Drag to turn · scroll to zoom · H: full view", "small", Color3.fromRGB(200, 204, 212))
	hint.Position = UDim2.fromOffset(0, 66)
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local bar = Ui.card(stage, "Toolbar", UDim2.new(1, 0, 0, 84), UDim2.new(0, 0, 1, -84), 0.12)
	Kit.pad(bar, Kit.SPACE.m, Kit.SPACE.s)
	local bl = Kit.list(bar, Kit.SPACE.s)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local row1 = Ui.frame(bar, "Places", UDim2.new(1, 0, 0, 30))
	row1.LayoutOrder = 1
	local r1 = Kit.list(row1, Kit.SPACE.s, true)
	r1.HorizontalAlignment = Enum.HorizontalAlignment.Center
	r1.VerticalAlignment = Enum.VerticalAlignment.Center
	local placeOptions = {}
	for _, p in Showroom.PLACES do
		table.insert(placeOptions, { p, string.upper(string.sub(p, 1, 1)) .. string.sub(p, 2) })
	end
	Kit.segmented(row1, placeOptions, "auto", function(v)
		Showroom.setPlace(v)
		task.defer(function()
			refreshFire()
		end)
	end, 74)
	-- the firing range (L-22): targets for the unit's weapons
	local fire = Ui.frame(row1, "Fire", UDim2.fromOffset(0, 26))
	fire.AutomaticSize = Enum.AutomaticSize.X
	fire.LayoutOrder = 2
	local fl = Kit.list(fire, 6, true)
	fl.VerticalAlignment = Enum.VerticalAlignment.Center
	local fireToggle = Kit.toggle(fire, false, function(on)
		Showroom.setFiring(on)
	end)
	fireToggle.button.LayoutOrder = 1
	local fireLabel = Ui.label(fire, "Fire", "small", Kit.COLOR.text, 2)
	function refreshFire()
		if codex == nil or selected == nil then
			return
		end
		local def = (codex :: Codex.Codex).defs.units[selected :: string]
		local n = Showroom.firingWeapons(def)
		fireLabel.Text = if n > 0 then "Fire" else "Fire (no weapon)"
		fireLabel.TextColor3 = if n > 0 then Kit.COLOR.text else Kit.COLOR.dim
	end
	local row2 = Ui.frame(bar, "Options", UDim2.new(1, 0, 0, 30))
	row2.LayoutOrder = 2
	local r2 = Kit.list(row2, Kit.SPACE.m, true)
	r2.HorizontalAlignment = Enum.HorizontalAlignment.Center
	r2.VerticalAlignment = Enum.VerticalAlignment.Center
	local turn = Ui.frame(row2, "Turntable", UDim2.fromOffset(0, 26))
	turn.AutomaticSize = Enum.AutomaticSize.X
	turn.LayoutOrder = 1
	local tl = Kit.list(turn, 6, true)
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	Kit.toggle(turn, true, function(on)
		Showroom.setTurntable(on)
	end).button.LayoutOrder = 1
	Ui.label(turn, "Turn", "small", Kit.COLOR.text, 2)
	Kit.segmented(row2, { { "dusk", "Dusk" }, { "day", "Day" } }, "dusk", function(v)
		Showroom.setLight(v)
	end, 56).frame.LayoutOrder = 2
	local swatches = Ui.frame(row2, "Colours", UDim2.fromOffset(0, 22))
	swatches.AutomaticSize = Enum.AutomaticSize.X
	swatches.LayoutOrder = 3
	Kit.list(swatches, 3, true)
	local compareButton: TextButton

	-- full view (L-22): the panels and the top bar hide, the unit fills the screen
	local gui = frame:FindFirstAncestorOfClass("ScreenGui")
	local fullView = false
	local full = Ui.button(stage, "Full view", "ghost", function()
		setFullView(true)
	end, 96, 26)
	full.TextSize = 12
	full.AnchorPoint = Vector2.new(1, 0)
	full.Position = UDim2.new(1, 0, 0, 4)
	local back = Ui.button(gui or frame, "Show panels (H)", "ghost", function()
		setFullView(false)
	end, 150, 30)
	back.Name = "ShowPanels"
	back.TextSize = 12
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.new(0.5, 0, 1, -16)
	back.ZIndex = 20
	back.Visible = false
	function setFullView(on: boolean)
		if on == fullView then
			return
		end
		fullView = on
		for _, x in { left, right, bar, stageName, stageSub, hint, full } :: { GuiObject } do
			x.Visible = not on
		end
		local top = gui and gui:FindFirstChild("TopBar")
		if top and top:IsA("GuiObject") then
			top.Visible = not on
		end
		back.Visible = on
		-- the stage (the showroom's region, where drags turn the camera) takes the page
		stage.Position = if on then UDim2.new() else UDim2.fromOffset(LIST_W + Kit.SPACE.l, 0)
		stage.Size = if on then UDim2.fromScale(1, 1) else UDim2.new(1, -(LIST_W + ARTICLE_W + Kit.SPACE.l * 2), 1, 0)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.H then
			return
		end
		if frame.Visible and Showroom.isOpen() then
			setFullView(not fullView)
		end
	end)

	-- showing ------------------------------------------------------------------

	local function colorsFor(ids: { string }): { Color3 }
		local out = {}
		for i, id in ids do
			local def = (codex :: Codex.Codex).defs.units[id]
			out[i] = if colorChoice and i == 1 then Ui.color(colorChoice) else factionColor(def.faction)
		end
		return out
	end

	local function shownIds(): { string }
		local c = codex :: Codex.Codex
		local id = selected :: string
		local ids = { id }
		if compare then
			for _, other in c.entries[id].counterparts do
				table.insert(ids, other)
			end
		end
		return ids
	end

	local function stageUnits()
		if codex == nil or selected == nil then
			return
		end
		local c = codex :: Codex.Codex
		local ids = shownIds()
		local colors = colorsFor(ids)
		local items = {}
		for i, id in ids do
			items[i] = { def = c.defs.units[id], color = colors[i] }
		end
		Showroom.show(items)
		local names = {}
		for _, id in ids do
			table.insert(names, c.defs.units[id].name)
		end
		stageName.Text = table.concat(names, "  vs  ")
		local e = c.entries[selected :: string]
		stageSub.Text = `{Ui.label2(e.faction)} · {if e.role then e.role.name else "Unit"} · {Codex.tierName(e.def.tier)}`
		refreshFire()
	end

	for i = 0, #Config.COLORS do
		local b = Instance.new("TextButton")
		b.Name = if i == 0 then "Faction" else `Colour{i}`
		b.AutoButtonColor = false
		b.Text = if i == 0 then "F" else ""
		b.FontFace = Kit.font(Enum.FontWeight.Bold)
		b.TextSize = 11
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Size = UDim2.fromOffset(18, 18)
		b.BackgroundColor3 = if i == 0 then Color3.fromRGB(60, 64, 72) else Ui.color(i)
		b.LayoutOrder = i
		b.Parent = swatches
		Ui.corner(b, 3)
		b.MouseButton1Click:Connect(function()
			colorChoice = if i == 0 then nil else i
			if codex and selected then
				Showroom.setColors(colorsFor(shownIds()))
			end
		end)
	end

	compareButton = Ui.button(row2, "Compare", "ghost", function()
		compare = not compare
		compareButton.Text = if compare then "Compare: on" else "Compare"
		stageUnits()
	end, 110, 26)
	compareButton.LayoutOrder = 4

	-- the article ----------------------------------------------------------------

	local select: (string) -> ()

	local function writeArticle()
		Ui.clear(article)
		local c = codex :: Codex.Codex
		local id = selected :: string
		local e = c.entries[id]
		local def = e.def
		local s = Codex.stats(c, id)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		local head = Ui.frame(article, "Head", UDim2.new(1, 0, 0, 44))
		head.LayoutOrder = nextOrder()
		local hl = Kit.list(head, Kit.SPACE.s, true)
		hl.VerticalAlignment = Enum.VerticalAlignment.Center
		icon(head, def, 34, factionColor(e.faction)).LayoutOrder = 1
		local name = Ui.label(head, def.name, "title", nil, 2)
		name.TextSize = 30
		local emblem = Emblem.label(head, e.faction, 28)
		if emblem then
			emblem.LayoutOrder = 3
		end
		paragraph(article, `<font color="#{factionColor(e.faction):ToHex()}">{Ui.label2(e.faction)}</font>  ·  {if e.role then e.role.name else "Unit"}  ·  {Codex.tierName(def.tier)}`, nextOrder(), "label", Kit.COLOR.dim)
		paragraph(article, def.description or "", nextOrder(), "label")

		-- the counterpart
		Kit.section(article, if #e.counterparts > 0 then `{Ui.label2(if e.faction == "order" then "chaos" else "order")} counterpart` else "Counterpart", nextOrder())
		if #e.counterparts == 0 then
			paragraph(article, `None: only {Ui.label2(e.faction)} has a {if e.role then string.lower(e.role.name) else "unit like this"}.`, nextOrder(), "small", Kit.COLOR.dim)
		else
			for _, other in e.counterparts do
				counterpartCard(article, c, other, nextOrder(), select)
			end
			for _, other in e.counterparts do
				local diffs = Codex.compare(c, id, other)
				local parts = {}
				for k, d in diffs do
					if k > 5 then
						break
					end
					local hex = (if d.better then Kit.COLOR.victory else Kit.COLOR.defeat):ToHex()
					table.insert(parts, `<font color="#{hex}">{if d.pct > 0 then "+" else "−"}{math.floor(math.abs(d.pct) + 0.5)}% {d.label}</font>`)
				end
				local vs = `vs {c.defs.units[other].name}: `
				paragraph(article, vs .. (if #parts > 0 then table.concat(parts, ",  ") else "about the same"), nextOrder(), "small", Kit.COLOR.dim)
			end
		end

		-- the numbers (L-24, BAR's unit wiki): bars against the game's biggest,
		-- then the details that aren't amounts, then the weapons as cards
		local max = Codex.maxima(c)
		local function bars(name: string): Frame
			local f = Ui.frame(article, name, UDim2.new(1, 0, 0, 0))
			f.AutomaticSize = Enum.AutomaticSize.Y
			f.LayoutOrder = nextOrder()
			Kit.list(f, 4)
			return f
		end
		StatBars.heading(article, "Cost", nextOrder())
		local cost = bars("Cost")
		local k = 0
		local function bar(parent: Frame, label: string, key: string, value: number?, shown: string?, top: number?)
			if value and value > 0 then
				k += 1
				StatBars.bar(parent, label, key, value, shown or n(value), top, k)
			end
		end
		bar(cost, "Supply", "supply", s.supply, nil, max.supply)
		bar(cost, "Power", "power", s.power, nil, max.power)
		bar(cost, "Build time", "time", s.buildSeconds, if s.buildSeconds then `{n(s.buildSeconds)} s` else nil, max.buildSeconds)
		StatBars.heading(article, "General stats", nextOrder())
		local general = bars("General")
		bar(general, "Health", "health", s.health, nil, max.health)
		bar(general, "Speed", "speed", s.speed, nil, max.speed)
		bar(general, "Sight", "sight", s.sight, nil, max.sight)
		bar(general, "Radar", "radar", s.radar, nil, max.radar)
		bar(general, "DPS", "dps", s.dps, nil, max.dps)
		bar(general, "Range", "range", if s.dps > 0 then s.range else nil, nil, max.range)
		bar(general, "Build power", "build", s.buildPower, nil, max.buildPower)
		local stock = 0
		for _, w in s.weapons do
			stock += w.stock or 0
		end
		bar(general, "Stockpile", "stock", stock, nil, 20)
		bar(general, "Ammo", "ammo", s.ammo, nil, 20)

		Kit.section(article, "Details", nextOrder())
		local box = Ui.frame(article, "Infobox", UDim2.new(1, 0, 0, 0))
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.LayoutOrder = nextOrder()
		Kit.list(box, 3)
		local r = 0
		local function row(label: string, value: string?)
			if value and value ~= "" then
				r += 1
				info(box, label, value, r)
			end
		end
		row("Value", `{n(s.value)}  (supply + power ÷ 10)`)
		local where = ""
		if s.buildSeconds and s.builder then
			local b = c.defs.units[s.builder]
			where = ` · {n(s.buildSeconds)} s ` .. (if b.domain == "structure" then `in the {b.name}` else `by one {b.name}`)
		end
		row("Build", `{n(s.work)} work` .. where)
		row("Armor", CLASS_NAME[s.armor] or s.armor)
		if s.speed then
			row("Movement", `{MOVE_NAME[s.move or ""] or s.move or "?"}` .. (if s.turnRate then ` · turn rate {n(s.turnRate)}` else ""))
		end
		local senses = {}
		if s.airSight then
			table.insert(senses, `air sight {n(s.airSight)}`)
		end
		if s.sonar then
			table.insert(senses, `sonar {n(s.sonar)}`)
		end
		if s.jam then
			table.insert(senses, `jams {n(s.jam)}`)
		end
		if s.track then
			table.insert(senses, `tracks {n(s.track)}`)
		end
		row("Sensors", table.concat(senses, " · "))
		if s.stealth then
			row("Stealth", `radar signature {string.format("%.2f", s.stealth)}`)
		end
		if #s.countermeasures > 0 then
			row("Countermeasures", table.concat(s.countermeasures, " · "))
		end
		if s.income then
			local parts = {}
			if s.income.supply > 0 then
				table.insert(parts, `+{n(s.income.supply)} supply/s`)
			end
			if s.income.power > 0 then
				table.insert(parts, `+{n(s.income.power)} power/s`)
			end
			row("Income", table.concat(parts, " · "))
		end
		if s.storage then
			row("Storage", `{n(s.storage.supply)} supply · {n(s.storage.power)} power`)
		end
		row("Size", `{s.footprint} × {s.footprint} cells ({s.footprint * 8} studs)`)

		-- weapons
		if #s.weapons > 0 then
			StatBars.heading(article, if #s.weapons == 1 then "Weapon" else `Weapons ({#s.weapons})`, nextOrder())
			local F = StatBars.figure
			for _, w in s.weapons do
				local lines: { StatBars.Line } = {}
				local function line(key: string, value: string, label: string, word: string?)
					table.insert(lines, { key = key, value = value, label = label, word = word })
				end
				if w.stockSeconds then
					line("time", F(w.stockSeconds), "sec. to build ammo")
				end
				if w.stock then
					line("stock", tostring(w.stock), "stockpile")
				end
				line("dps", F(w.dps), "dps", `vs {string.lower(CLASS_NAME[w.class] or w.class)}`)
				line("reload", F(w.reload), "reload", Codex.word("reload", w.reload))
				line("alpha", F(w.alpha), "alpha", Codex.word("alpha", w.alpha))
				if w.shots > 1 then
					line("salvo", tostring(w.shots), "shots a volley")
				end
				line("range", F(w.range), "range", Codex.word("range", w.range))
				if w.aoe then
					line("aoe", F(w.aoe), "aoe", Codex.word("aoe", w.aoe))
				end
				if w.speed then
					line("projectile", F(w.speed), "projectile speed")
				end
				if w.lockRange then
					line("lock", F(w.lockRange), "lock range")
				end
				-- what it does, in a sentence: its kind, how it flies, what it hits
				local kind = KIND_NAME[w.kind] or string.lower(w.kind)
				local how = {}
				if w.guidance then
					table.insert(how, `{string.lower(w.guidance)}-guided`)
				end
				if w.launch == "vertical" then
					table.insert(how, "launched vertically")
				end
				local dmg = {}
				for _, cls in { "LIGHT", "ARMORED", "STRUCTURE", "AIR", "SHIP", "SUB" } do
					if w.damage[cls] then
						table.insert(dmg, `{string.lower(CLASS_NAME[cls])} {n(w.damage[cls])}`)
					end
				end
				local about = `{string.upper(string.sub(kind, 1, 1))}{string.sub(kind, 2)}` .. (if #how > 0 then ", " .. table.concat(how, ", ") else "")
					.. (if #w.targets > 0 then `; hits {string.lower(table.concat(w.targets, ", "))}.` else ".")
					.. `\n<font color="#969CA8">Per hit: {table.concat(dmg, " · ")}</font>`
				StatBars.weapon(article, weaponName(w.id), w.kind, kind, if w.stockPower then n(w.stockPower) else nil, lines, about, nextOrder())
			end
		end

		-- builds / built by
		if #s.builds > 0 then
			Kit.section(article, `Builds ({#s.builds})`, nextOrder())
			chips(article, c, s.builds, nextOrder(), select)
		end
		if #e.builtBy > 0 then
			Kit.section(article, "Built by", nextOrder())
			chips(article, c, e.builtBy, nextOrder(), select)
		end
		article.CanvasPosition = Vector2.zero
	end

	-- the list -----------------------------------------------------------------

	function render()
		Ui.clear(list)
		local c = codex
		if c == nil then
			return
		end
		local q = string.lower(search.Text)
		local lastSection = ""
		local order = 0
		for _, e in c.byFaction[faction] or {} do
			if filter == "units" and Codex.isStructures(e.section) or filter == "structures" and not Codex.isStructures(e.section) then
				continue
			end
			if tierFilter ~= "all" and tostring(e.def.tier) ~= tierFilter then
				continue
			end
			if q ~= "" and not string.find(string.lower(e.def.name .. " " .. (if e.role then e.role.name else "")), q, 1, true) then
				continue
			end
			if e.section ~= lastSection then
				lastSection = e.section
				order += 1
				local name = e.section
				for _, s in Codex.SECTIONS do
					if s.id == e.section then
						name = s.name
					end
				end
				local h = Kit.text(list, string.upper(name), "small", Kit.COLOR.faint)
				h.Size = UDim2.new(1, 0, 0, 26)
				h.TextYAlignment = Enum.TextYAlignment.Bottom
				h.LayoutOrder = order
			end
			order += 1
			local on = e.id == selected
			local b = Instance.new("TextButton")
			b.Name = e.id
			b.AutoButtonColor = false
			b.Text = ""
			b.Size = UDim2.new(1, -6, 0, 44)
			b.BackgroundColor3 = if on then Kit.COLOR.selected else Kit.COLOR.raised
			b.BackgroundTransparency = if on then 0.2 else 1
			b.LayoutOrder = order
			b.Parent = list
			Ui.corner(b, 5)
			Kit.pad(b, 3, 0, Kit.SPACE.s, 0)
			local rl = Kit.list(b, Kit.SPACE.s, true)
			rl.VerticalAlignment = Enum.VerticalAlignment.Center
			-- its picture (2d-E's), else its icon in a picture-sized cell
			local pic: GuiObject? = picture(b, e.id, 38)
			if pic == nil then
				local cell = Ui.frame(b, "Picture", UDim2.fromOffset(38, 38))
				local glyph = icon(cell, e.def, 22, factionColor(e.faction))
				glyph.AnchorPoint = Vector2.new(0.5, 0.5)
				glyph.Position = UDim2.fromScale(0.5, 0.5)
				pic = cell
			end
			(pic :: GuiObject).LayoutOrder = 1
			local nm = Ui.label(b, e.def.name, "label", Kit.COLOR.text, 2)
			nm.TextTruncate = Enum.TextTruncate.AtEnd
			local role = Ui.label(b, if e.role then e.role.name else "", "small", Kit.COLOR.faint, 3)
			role.TextTruncate = Enum.TextTruncate.AtEnd
			b.MouseEnter:Connect(function()
				if e.id ~= selected then
					b.BackgroundTransparency = 0.93
				end
			end)
			b.MouseLeave:Connect(function()
				if e.id ~= selected then
					b.BackgroundTransparency = 1
				end
			end)
			b.MouseButton1Click:Connect(function()
				select(e.id)
			end)
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		render()
	end)

	function select(id: string)
		local c = codex
		if c == nil or c.entries[id] == nil then
			return
		end
		selected = id
		local f = c.entries[id].faction
		if f ~= faction then
			faction = f
			factionSeg.set(f)
		end
		local hasPair = #c.entries[id].counterparts > 0
		if not hasPair and compare then
			compare = false
			compareButton.Text = "Compare"
		end
		Ui.enable(compareButton, hasPair)
		render()
		writeArticle()
		stageUnits()
	end

	return {
		show = function()
			if codex == nil then
				local defs = Defs.load()
				codex = Codex.build(defs)
				Showroom.enter(defs)
				select(if (codex :: Codex.Codex).entries.ord_paladin then "ord_paladin" else (codex :: Codex.Codex).byFaction.order[1].id)
			else
				Showroom.enter((codex :: Codex.Codex).defs)
				stageUnits()
			end
		end,
		hide = function()
			setFullView(false)
			Showroom.leave()
		end,
	}
end

return Units

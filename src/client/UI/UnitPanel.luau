--!strict
-- Unit panel (C-68; BAR style since C-71), bottom left under the build
-- grid, a functional PLACEHOLDER. One unit selected: a portrait tile (its
-- model at an angle with its type icon bottom right, as in the build menu;
-- a contact's icon alone), name and role, a health bar and, for own units,
-- what it adds to or takes from the economy now ("+5" supply, "−10" power;
-- Core/UnitFlow, C-125: no HP numbers), then its stats as the player may know them
-- (Core/UnitStats, C-76: combat, mobility and sensors, economy, state with
-- the server's fire / move state and ammo), the team's radar precision, the
-- next missile's progress, on / off and repeat, and a factory's queue as the
-- server has it (S-61). An enemy shows full stats only in sight or tracked;
-- a radar contact its domain only. Several selected: a tile per unit type
-- as BAR's selection panel (C-157): the type's portrait, its icon bottom
-- right and how many are selected top left (C-191); a click keeps only that
-- type, Shift-click drops it, Ctrl-click selects every own unit of that type
-- on screen. Reads only the client API's state.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Api = require("../Api")
local Kit = require("./Kit")
local Icons = require("../Core/Icons")
local Precision = require("../Core/Precision")
local Selection = require("../Core/Selection")
local UnitStats = require("../Core/UnitStats")
local World = require("../Core/World")
local Glyph = require("./Glyph")
local Portrait = require("./Portrait")
local UnitFlow = require("../Core/UnitFlow")
local TeamColors = require("../Render/TeamColors")

local UnitPanel = {}

local BG = Kit.COLOR.panel
local TILE = Color3.fromRGB(58, 62, 70)
local WIDTH = 460 -- wide enough for a stat line at a glance (C-76)

export type UI = {
	gui: ScreenGui,
	panel: Frame,
	portrait: Frame,
	portraitGlyph: Glyph.G, -- a contact's icon (no known type)
	portraitView: Portrait.Portrait, -- the model
	cornerGlyph: Glyph.G, -- the type icon, bottom right
	flowSupply: TextLabel,
	flowPower: TextLabel,
	name: TextLabel,
	role: TextLabel,
	stats: TextLabel,
	health: Frame,
	healthFill: Frame,
	types: Frame,
	typeButtons: { TextButton },
	typeGlyphs: { Glyph.G },
	typePortraits: { Portrait.Portrait }, -- each type tile's model (C-191)
	icons: Icons.Table,
	codes: { [number]: string },
	key: string,
}

local function textLabel(parent: Instance, font: Enum.Font, size: number, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextSize = size
	t.TextColor3 = color
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	t.Parent = parent
	return t
end

function UnitPanel.new(api: Api.Api): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "UnitPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 0, 1, 0)
	panel.Size = UDim2.fromOffset(WIDTH, 120)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local portrait = Instance.new("Frame")
	portrait.Name = "Portrait"
	portrait.Position = UDim2.fromOffset(6, 6)
	portrait.Size = UDim2.fromOffset(60, 60)
	portrait.BackgroundColor3 = TILE
	portrait.BorderSizePixel = 0
	portrait.Parent = panel
	local pg = Glyph.new(portrait)
	pg.root.Position = UDim2.fromScale(0.5, 0.5)
	local view = Portrait.new(portrait)
	local corner = Glyph.new(portrait)
	corner.root.AnchorPoint = Vector2.new(1, 1)
	corner.root.Position = UDim2.new(1, -2, 1, -2)
	corner.root.ZIndex = 4
	local health = Instance.new("Frame")
	health.Name = "Health"
	health.Position = UDim2.fromOffset(6, 70)
	health.Size = UDim2.fromOffset(60, 6)
	health.BackgroundColor3 = Color3.fromRGB(60, 22, 22)
	health.BorderSizePixel = 0
	health.Parent = panel
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	fill.BorderSizePixel = 0
	fill.Parent = health
	-- the economy flow: supply white, power yellow (the build menu's cost colors)
	local flowSupply = textLabel(panel, Enum.Font.GothamBold, 13, Color3.fromRGB(235, 235, 235))
	flowSupply.Position = UDim2.fromOffset(6, 79)
	flowSupply.Size = UDim2.fromOffset(64, 15)
	local flowPower = textLabel(panel, Enum.Font.GothamBold, 13, Color3.fromRGB(255, 214, 60))
	flowPower.Position = UDim2.fromOffset(6, 95)
	flowPower.Size = UDim2.fromOffset(64, 15)
	local name = textLabel(panel, Enum.Font.GothamBold, 15, Color3.fromRGB(190, 228, 96)) -- yellow-green (reference 3, C-203)
	name.Position = UDim2.fromOffset(72, 4)
	name.Size = UDim2.new(1, -78, 0, 18)
	local role = textLabel(panel, Enum.Font.Gotham, 11, Color3.fromRGB(190, 190, 190))
	role.Position = UDim2.fromOffset(72, 21)
	role.Size = UDim2.new(1, -78, 0, 14)
	role.TextTruncate = Enum.TextTruncate.AtEnd
	local stats = textLabel(panel, Enum.Font.Gotham, 11, Color3.fromRGB(225, 225, 225))
	stats.Position = UDim2.fromOffset(72, 36)
	stats.Size = UDim2.new(1, -78, 1, -38)
	stats.LineHeight = 1.05
	local types = Instance.new("Frame")
	types.Name = "Types"
	types.BackgroundTransparency = 1
	types.Position = UDim2.fromOffset(6, 6)
	types.Size = UDim2.new(1, -12, 1, -12)
	types.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(50, 50)
	gl.CellPadding = UDim2.fromOffset(3, 3)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = types
	Kit.skin(gui) -- the UI kit's look (C-105)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return {
		gui = gui, panel = panel, portrait = portrait, portraitGlyph = pg, portraitView = view, cornerGlyph = corner,
		flowSupply = flowSupply, flowPower = flowPower, name = name, role = role, stats = stats,
		health = health, healthFill = fill, types = types, typeButtons = {}, typeGlyphs = {}, typePortraits = {},
		icons = Icons.table(api.world.defs), codes = Icons.codes(api.world.defs), key = "",
	}
end

local function styleOf(ui: UI, def: any, team: number, size: number): any
	return Icons.ofDef(def, team, size)
end

local function one(ui: UI, api: Api.Api, id: number)
	local world = api.world
	local u = world.units[id]
	if u == nil then
		ui.name.Text, ui.role.Text, ui.stats.Text = "(out of view)", "", ""
		return
	end
	local sheet = UnitStats.of(world, u)
	local def = if sheet.access == "contact" then nil else (World.def(world, u) or world.defs.unitByIndex[u.icon or 0])
	-- the icon as drawn on the map (a contact's dashed frame, a ghost's faded type)
	local style = Icons.style(ui.icons, world, u, false)
	if def then
		-- the model at an angle, the type icon bottom right (the build menu's tile)
		Portrait.set(ui.portraitView, def, u.team)
		style.size = math.floor(style.size * 18 / Icons.BASE + 0.5)
		Glyph.apply(ui.cornerGlyph, style, TeamColors(u.team))
	else
		style.size = math.floor(style.size * 38 / Icons.BASE + 0.5)
		Glyph.apply(ui.portraitGlyph, style, TeamColors(u.team))
	end
	ui.portraitView.frame.Visible = def ~= nil
	ui.cornerGlyph.root.Visible = def ~= nil
	ui.portraitGlyph.root.Visible = def == nil
	ui.health.Visible = sheet.health ~= nil
	if sheet.health and sheet.maxHealth then
		ui.healthFill.Size = UDim2.fromScale(math.clamp(sheet.health / sheet.maxHealth, 0, 1), 1)
	end
	-- what it adds to / takes from the economy now (own units: the client knows their state)
	local own = def ~= nil and sheet.access == "own"
	ui.flowSupply.Visible, ui.flowPower.Visible = own, own
	if own then
		local eco = api.state.economy
		local ratio = if eco then math.min(eco.supply.ratio, eco.power.ratio) else 1
		local s, p = UnitFlow.of(world, u, def, { queue = api.state.factoryQueues[id], wind = eco and eco.wind, ratio = ratio })
		ui.flowSupply.Text = UnitFlow.text(s)
		ui.flowPower.Text = UnitFlow.text(p)
	end
	ui.name.Text = sheet.name
	ui.role.Text = if def then string.match(def.description or "", "^[^%.]*") or "" else ""
	local lines = UnitStats.lines(sheet)
	if sheet.build then
		table.insert(lines, 1, string.format("Building %d%%", math.floor(sheet.build * 100)))
	end
	if def == nil or sheet.access ~= "own" then
		ui.stats.Text = table.concat(lines, "\n")
		return
	end
	local renderTick = world.shownTick or world.latestTick
	for _, ws in def.weapons or {} do
		local cap = (ws :: any).stockCapacity
		if cap and u.stock then
			local shown = World.stockProgressOf(world, u, renderTick)
			if shown then
				table.insert(lines, string.format("Next missile %d%%", math.floor(shown * 100)))
			end
			break
		end
	end
	if Precision.relevant(def) then
		-- the team's radar precision from its Pinpointers (S-59, C-72)
		local p = Precision.of(world)
		table.insert(lines, string.format("Accuracy %d%%", math.floor(p * 100 + 0.5))) -- the user's wording
	end
	local st, flags = u.state or 0, {}
	if def.converter then -- only converters read the on / off bit (Economy)
		table.insert(flags, if bit32.band(st, 2) ~= 0 then "On" else "Off")
	end
	if bit32.band(st, 16) ~= 0 then
		table.insert(flags, "Repeat")
	end
	local q = api.state.factoryQueues[id]
	if q and #q > 0 then
		local parts, last, count = {}, nil, 0
		for i = 1, #q + 1 do
			if q[i] ~= last then
				if last then
					local d = world.defs.unitByIndex[last]
					table.insert(parts, `{if d then d.name else "?"} x{count}`)
				end
				last, count = q[i], 0
			end
			count += 1
		end
		local head = string.format(" (%d%%)", math.floor((u.queueProgress or 0) * 100))
		table.insert(flags, "Queue: " .. table.concat(parts, ", ") .. head)
	end
	if #flags > 0 then
		table.insert(lines, table.concat(flags, "   "))
	end
	ui.stats.Text = table.concat(lines, "\n")
end

-- The unit the panel describes alone: a hovered enemy (BAR: hover shows
-- its info), else a hovered unit with nothing selected, else the one
-- selected unit; nil for a multi-selection or nothing.
function UnitPanel.subject(api: Api.Api): number?
	local hover = api.state.hover
	local h = hover and hover.unit
	local hu = h and api.world.units[h]
	local sel = api.state.selection
	if hu and (hu.team ~= api.world.me.team or #sel == 0) then
		return h
	end
	return if #sel == 1 then sel[1] else nil
end

function UnitPanel.step(ui: UI, api: Api.Api)
	local sel = api.state.selection
	local subject = UnitPanel.subject(api)
	ui.panel.Visible = #sel > 0 or subject ~= nil
	if not ui.panel.Visible then
		return
	end
	local world = api.world
	local single = subject ~= nil
	for _, f in { ui.portrait, ui.health, ui.name, ui.role, ui.stats, ui.flowSupply, ui.flowPower } :: { GuiObject } do
		f.Visible = single
	end
	ui.types.Visible = not single
	if single then
		one(ui, api, subject :: number)
		ui.key = "" -- the type tiles redraw when the selection shows again
		return
	end
	local counts, order, teams = {}, {}, {}
	for _, id in sel do
		local u = world.units[id]
		local d = u and u.defIndex
		if d then
			if counts[d] == nil then
				counts[d] = 0
				teams[d] = u.team
				table.insert(order, d)
			end
			counts[d] += 1
		end
	end
	local parts = {}
	for _, d in order do
		table.insert(parts, `{d}:{counts[d]}`)
	end
	local key = table.concat(parts, ",")
	if key == ui.key then
		return
	end
	ui.key = key
	for i, d in order do
		local b = ui.typeButtons[i]
		if b == nil then
			b = Instance.new("TextButton")
			b.BackgroundColor3 = TILE
			b.BorderSizePixel = 0
			b.Text = ""
			b.Parent = ui.types
			-- the model at an angle (as the one-unit portrait), the type icon
			-- bottom right, the count top left (C-191)
			ui.typePortraits[i] = Portrait.new(b)
			local g = Glyph.new(b)
			g.root.AnchorPoint = Vector2.new(1, 1)
			g.root.Position = UDim2.new(1, -1, 1, -1)
			g.root.ZIndex = 4
			ui.typeGlyphs[i] = g
			local count = Instance.new("TextLabel")
			count.Name = "Count"
			count.BackgroundTransparency = 1
			count.AnchorPoint = Vector2.new(0, 0)
			count.Position = UDim2.fromOffset(3, 1)
			count.Size = UDim2.fromOffset(30, 14)
			count.Font = Enum.Font.GothamBold
			count.TextSize = 13
			count.TextColor3 = Color3.new(1, 1, 1)
			count.TextStrokeTransparency = 0.2
			count.TextXAlignment = Enum.TextXAlignment.Left
			count.ZIndex = 4
			count.Parent = b
			ui.typeButtons[i] = b
			b.MouseButton1Click:Connect(function()
				local want = b:GetAttribute("DefIndex") :: number
				local function down(a: Enum.KeyCode, z: Enum.KeyCode): boolean
					return UserInputService:IsKeyDown(a) or UserInputService:IsKeyDown(z)
				end
				local how: "keep" | "remove" | "screen" = if down(Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
					then "remove"
					elseif down(Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl) then "screen"
					else "keep"
				local onScreen = nil
				if how == "screen" then
					local cam = workspace.CurrentCamera
					local view = cam.ViewportSize
					onScreen = Selection.sameTypeOnScreen(api.world, function(x: number, y: number, z: number)
						local v, visible = cam:WorldToViewportPoint(Vector3.new(x, y, z))
						return v.X, v.Y, visible and v.Z > 0
					end, want, view.X, view.Y)
				end
				api.actions.select(Selection.tileClick(api.world, api.state.selection, want, how, onScreen))
			end)
		end
		b:SetAttribute("DefIndex", d)
		b.LayoutOrder = i
		b.Visible = true
		local def = world.defs.unitByIndex[d]
		Portrait.set(ui.typePortraits[i], def, teams[d])
		Glyph.apply(ui.typeGlyphs[i], styleOf(ui, def, teams[d], 15), TeamColors(teams[d]))
		;(b :: any).Count.Text = tostring(counts[d])
	end
	for i = #order + 1, #ui.typeButtons do
		ui.typeButtons[i].Visible = false
	end
end

return UnitPanel

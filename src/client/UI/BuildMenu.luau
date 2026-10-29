--!strict
-- Build menu (C-68, guide 15.7; BAR-style grid since C-71): what the
-- selected builders can build (Core/BuildMenu), in category tabs. Mobile
-- builders: a click starts the build ghost. Factories: a click queues one
-- (Shift: 5), a right click drops the last queued one; the badge is the
-- queued count. B opens the menu's keys / goes to the next tab; while they
-- are on, 1..0 pick the tab's items (the menu takes those keys before the
-- control groups). Acts only through the client API.
-- Tiles are BAR's (C-107; reference 3 since C-203): the unit's model
-- portrait at an angle (UI/Portrait), its type icon at the bottom left, the
-- cost stacked at the bottom right (supply white, power yellow), the hotkey
-- top left and the queued count top right. Hovering a tile shows its name
-- and stats. The category tabs sit under the grid, each with its colour
-- and hotkey (Economy Z, Combat X, Utility C, Build V, C-203): while a
-- builder's menu shows, those keys open the tab and arm the digits (over
-- Patrol, Cancel, camera right and range rings). A mobile builder selected
-- by click or box arms them at once (C-248).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Api = require("../Api")
local Kit = require("./Kit")
local BuildMenu = require("../Core/BuildMenu")
local Icons = require("../Core/Icons")
local Glyph = require("./Glyph")
local MinimapUI = require("./Minimap")
local Portrait = require("./Portrait")
local Upgrades = require("../Core/Upgrades")
local UnitStats = require("../Core/UnitStats")
local MeshModels = require("../Render/MeshModels")
local Models = require("../Render/Models")
local TeamColors = require("../Render/TeamColors")

local BuildMenuUI = {}

BuildMenuUI.KEY = Enum.KeyCode.B
-- the structure tabs' keys (Settings > Keys writes them)
BuildMenuUI.TAB_KEYS = { Economy = Enum.KeyCode.Z, Combat = Enum.KeyCode.X, Utility = Enum.KeyCode.C, Build = Enum.KeyCode.V } :: { [string]: Enum.KeyCode }
BuildMenuUI.active = nil :: any -- the menu, for key handlers made before it (C-203)
-- each tab's colour mark (reference 3)
local TAB_COLOR: { [string]: Color3 } = {
	Economy = Color3.fromRGB(255, 214, 60),
	Combat = Color3.fromRGB(236, 96, 84),
	Utility = Color3.fromRGB(92, 172, 240),
	Build = Color3.fromRGB(110, 210, 120),
	Units = Color3.fromRGB(200, 204, 212),
}
local DIGITS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9, [Enum.KeyCode.Zero] = 10,
}
local BG = Kit.COLOR.panel
local ON = Kit.COLOR.selected
local OFF = Kit.COLOR.control
local TILE = Color3.fromRGB(58, 62, 70)
local ITEMS_PER_ROW = 4
local CELL = 66
local ROWS = 2 -- visible rows; more scroll (2 since C-76: room for the wider unit panel)
local WIDTH = 280 -- four 66-pixel tiles; the grid sits on the unit panel, under the minimap (BAR layout)
local TOP = MinimapUI.SIZE
local FULL_HEIGHT = 26 + ROWS * (CELL + 3) + 8

export type UI = {
	gui: ScreenGui,
	panel: Frame,
	tabRow: Frame,
	grid: ScrollingFrame,
	tabButtons: { TextButton },
	itemButtons: { TextButton },
	itemGlyphs: { Glyph.G },
	portraits: { Portrait.Portrait },
	tip: Frame, -- the hover tooltip
	tipTitle: TextLabel,
	tipBody: TextLabel,
	hovered: number?, -- the tile under the mouse
	icons: Icons.Table,
	menu: BuildMenu.Menu?,
	tab: number,
	armed: boolean, -- B or a tab key pressed: the digits pick items, until the selection changes
	armedFor: string, -- the selection the digits were armed for
	key: string, -- what the drawn menu was built from
	codes: { [number]: string },
}

local function shift(): boolean
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function button(parent: Instance, name: string): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.BackgroundColor3 = OFF
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 12
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = b
	return b
end

local function queuedCount(api: Api.Api, menu: BuildMenu.Menu, defIndex: number): number
	local n = 0
	for _, f in menu.factories do
		for _, d in api.state.factoryQueues[f] or {} do
			if d == defIndex then
				n += 1
			end
		end
	end
	return n
end

-- Picks item `i` of the open tab: a ghost for mobile builders, a queued
-- unit for factories (`many`: 5).
local function pick(ui: UI, api: Api.Api, i: number, many: boolean)
	local menu = ui.menu
	if menu == nil then
		return
	end
	local items = menu.items[menu.tabs[ui.tab] or ""] or {}
	local defId = items[i]
	if defId == nil then
		return
	end
	if #menu.factories > 0 and api.world.defs.units[defId].domain ~= "structure" then
		api.actions.queueBuild(defId, if many then 5 else 1)
	else
		-- (the digits stay armed: the next one picks again, the user's report:
		-- after one pick the digits went to control groups until B again)
		api.actions.beginPlacement(defId)
	end
end

-- Drops the last queued `defId` from the selected factories.
local function unqueue(ui: UI, api: Api.Api, defId: string)
	local menu = ui.menu
	local def = api.world.defs.units[defId]
	if menu == nil or def == nil then
		return
	end
	for _, f in menu.factories do
		local q = api.state.factoryQueues[f] or {}
		for k = #q, 1, -1 do
			if q[k] == def.index then
				api.actions.select({ f })
				api.actions.cancel(k)
				return
			end
		end
	end
end

function BuildMenuUI.new(api: Api.Api): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	-- on top of the unit panel (120 high), growing up towards the minimap
	-- (the user: on tall screens it hung under the minimap with a gap below)
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 0, 1, -(120 + 4))
	panel.Size = UDim2.fromOffset(WIDTH, FULL_HEIGHT)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	-- the tabs under the grid (reference 3, C-203)
	local tabRow = Instance.new("Frame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.AnchorPoint = Vector2.new(0, 1)
	tabRow.Position = UDim2.new(0, 4, 1, -3)
	tabRow.Size = UDim2.new(1, -8, 0, 20)
	tabRow.Parent = panel
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 3)
	tl.Parent = tabRow
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Items"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Position = UDim2.fromOffset(4, 4)
	grid.Size = UDim2.new(1, -8, 1, -30)
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(CELL, CELL)
	gl.CellPadding = UDim2.fromOffset(2, 3)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	-- the hover tooltip: name, then the type's stats (C-107)
	-- (its own screen, over the unit panel and the command card)
	local tipGui = Instance.new("ScreenGui")
	tipGui.Name = "BuildTooltip"
	tipGui.ResetOnSpawn = false
	tipGui.DisplayOrder = 30
	local tip = Instance.new("Frame")
	tip.Name = "Tooltip"
	tip.BackgroundColor3 = BG
	tip.BackgroundTransparency = 0.05
	tip.BorderSizePixel = 0
	tip.AutomaticSize = Enum.AutomaticSize.Y
	tip.Size = UDim2.fromOffset(300, 0)
	tip.Visible = false
	tip.Parent = tipGui
	Kit.pad(tip, Kit.SPACE.m, Kit.SPACE.s)
	Kit.list(tip, 2)
	local tipTitle = Kit.text(tip, "", "section", Color3.fromRGB(176, 230, 120))
	tipTitle.LayoutOrder = 1
	local tipBody = Kit.text(tip, "", "small", Kit.COLOR.text)
	tipBody.LayoutOrder = 2
	tipBody.TextWrapped = true
	tipBody.AutomaticSize = Enum.AutomaticSize.Y
	tipBody.Size = UDim2.new(1, 0, 0, 0)
	Kit.skin(gui) -- the UI kit's look (C-105)
	Kit.skin(tipGui)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	tipGui.Parent = gui.Parent
	local ui: UI = { gui = gui, panel = panel, tabRow = tabRow, grid = grid, tabButtons = {}, itemButtons = {}, itemGlyphs = {}, portraits = {}, tip = tip, tipTitle = tipTitle, tipBody = tipBody, hovered = nil, icons = Icons.table(api.world.defs), menu = nil, tab = 1, armed = false, armedFor = "", key = "", codes = Icons.codes(api.world.defs) }
	BuildMenuUI.active = ui
	return ui
end

-- The structure tab bound to `key` while a builder's menu shows (its
-- tabs' keys take over then), or nil; `present` false when that tab is
-- bound but this menu lacks it.
local function tabKey(ui: UI, key: Enum.KeyCode): (string?, boolean)
	local menu = ui.menu
	if menu == nil then
		return nil, false
	end
	local layer = false
	for _, tab in menu.tabs do
		layer = layer or BuildMenuUI.TAB_KEYS[tab] ~= nil
	end
	if not layer then
		return nil, false
	end
	for tab, k in BuildMenuUI.TAB_KEYS do
		if k == key then
			return tab, table.find(menu.tabs, tab) ~= nil
		end
	end
	return nil, false
end

-- True when `key` is a build tab's key right now (other handlers of it
-- stand aside: range rings, the camera's turn).
function BuildMenuUI.takes(ui: UI, key: Enum.KeyCode): boolean
	return (tabKey(ui, key)) ~= nil
end

-- The menu's keys (Controls.capture): true when it took the key.
function BuildMenuUI.capture(ui: UI, api: Api.Api, input: InputObject): boolean
	local menu = ui.menu
	if menu == nil or #menu.tabs == 0 then
		ui.armed = false
		return false
	end
	local tab, present = tabKey(ui, input.KeyCode)
	if tab then
		if present then
			ui.tab = table.find(menu.tabs, tab) :: number
			ui.armed = true
			ui.key = "" -- redraw
		end
		return true
	end
	if input.KeyCode == BuildMenuUI.KEY then
		if ui.armed then
			ui.tab = ui.tab % #menu.tabs + 1
		end
		ui.armed = true
		ui.key = "" -- redraw
		return true
	end
	local d = DIGITS[input.KeyCode]
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if ui.armed and d and not ctrl then -- (Ctrl + digit still sets a control group)
		pick(ui, api, d, shift())
		return true
	end
	return false
end

-- The tooltip for the hovered tile, beside the menu.
local function tooltip(ui: UI, api: Api.Api, items: { string })
	local i = ui.hovered
	local defId = i and items[i]
	local b = i and ui.itemButtons[i]
	if defId == nil or b == nil or not b.Visible then
		ui.tip.Visible = false
		return
	end
	local world = api.world
	local def = world.defs.units[defId]
	local sheet = UnitStats.ofDef(world, def)
	local lines = {}
	if def.description then
		table.insert(lines, def.description)
	end
	if Upgrades.isUpgrade(world.defs, def) then
		table.insert(lines, Upgrades.TOOLTIP) -- C-121
	end
	local menu = ui.menu
	local power = 0
	for _, id in api.state.selection do
		local u = world.units[id]
		local d = u and world.defs.unitByIndex[u.defIndex or 0]
		power = math.max(power, d and d.buildPower or 0)
	end
	local cost = def.cost or {}
	local time = if power > 0 and cost.buildTime then string.format("  ·  %ds at %d buildpower", math.ceil(cost.buildTime / power), power) else ""
	table.insert(lines, `Cost {cost.supply or 0} supply / {cost.power or 0} power{time}`)
	if sheet.maxHealth then
		table.insert(lines, `Health {sheet.maxHealth}`)
	end
	for _, l in UnitStats.lines(sheet) do
		if not string.find(l, "^Cost ") then
			table.insert(lines, l)
		end
	end
	ui.tipTitle.Text = def.name
	ui.tipBody.Text = table.concat(lines, "\n")
	-- beside the menu, level with the tile, kept on screen
	local p = b.AbsolutePosition
	local screen = (ui.tip.Parent :: ScreenGui).AbsoluteSize
	local y = math.min(p.Y, screen.Y - ui.tip.AbsoluteSize.Y - 4)
	ui.tip.Position = UDim2.fromOffset(ui.panel.AbsolutePosition.X + ui.panel.AbsoluteSize.X + 6, math.max(0, y))
	ui.tip.Visible = menu ~= nil
end

function BuildMenuUI.step(ui: UI, api: Api.Api)
	local world = api.world
	local menu = BuildMenu.of(world, api.state.selection)
	ui.menu = menu
	-- another selection: a mobile builder picked by click or box arms the
	-- digits at once (H17: they did nothing until a tab key); one recalled
	-- from a control group, or a factory, leaves them to the groups until B
	-- or a tab key (a double tap still jumps the camera, C-248)
	local selKey = table.concat(api.state.selection, ",")
	if selKey ~= ui.armedFor then
		ui.armedFor = selKey
		ui.armed = #menu.tabs > 0 and #menu.factories == 0 and not api.state.recalled
	end
	ui.panel.Visible = #menu.tabs > 0
	if #menu.tabs == 0 then
		ui.armed = false
		ui.tip.Visible = false
		return
	end
	tooltip(ui, api, menu.items[menu.tabs[math.clamp(ui.tab, 1, #menu.tabs)]] or {})
	-- between the minimap and the unit panel (120 high) on short screens: the grid scrolls
	local camera = workspace.CurrentCamera
	local scale = ui.gui:FindFirstChild("SettingsScale")
	local k = if scale and scale:IsA("UIScale") then scale.Scale else 1
	local inset = game:GetService("GuiService"):GetGuiInset()
	local room = ((if camera then camera.ViewportSize.Y else 1080) - inset.Y) / k - TOP - 120 - 4
	ui.panel.Size = UDim2.fromOffset(WIDTH, math.clamp(room, 26 + CELL + 11, FULL_HEIGHT))
	ui.tab = math.clamp(ui.tab, 1, #menu.tabs)
	local items = menu.items[menu.tabs[ui.tab]] or {}
	-- redraw when the tabs, the tab, the armed state or a queued count change
	local parts = { table.concat(menu.tabs, ","), tostring(ui.tab), tostring(ui.armed), tostring(Models.version), tostring(MeshModels.stats.built), tostring(world.me.team) }
	for _, defId in items do
		table.insert(parts, tostring(queuedCount(api, menu, world.defs.units[defId].index)))
	end
	local key = table.concat(parts, "|")
	if key == ui.key then
		return
	end
	ui.key = key
	for i, tab in menu.tabs do
		local b = ui.tabButtons[i]
		if b == nil then
			b = button(ui.tabRow, "Tab")
			b.Size = UDim2.fromOffset(65, 20)
			b.TextSize = 10
			b.RichText = true
			b.TextXAlignment = Enum.TextXAlignment.Left
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 11)
			pad.Parent = b
			-- the tab's colour mark: a small diamond
			local mark = Instance.new("Frame")
			mark.Name = "Mark"
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.new(0, -5, 0.5, 0)
			mark.Size = UDim2.fromOffset(6, 6)
			mark.Rotation = 45
			mark.BorderSizePixel = 0
			mark.Parent = b
			local index = i
			b.MouseButton1Click:Connect(function()
				ui.tab = index
				ui.armed = true -- a clicked tab arms the digits too
				ui.key = ""
			end)
			ui.tabButtons[i] = b
		end
		local k = BuildMenuUI.TAB_KEYS[tab]
		b.Text = if k then `{tab} <font color="#A8AEB8">{k.Name}</font>` else tab
		b.Visible = true
		b.BackgroundColor3 = if i == ui.tab then ON else OFF
		;(b :: any).Mark.BackgroundColor3 = TAB_COLOR[tab] or Color3.new(1, 1, 1)
	end
	for i = #menu.tabs + 1, #ui.tabButtons do
		ui.tabButtons[i].Visible = false
	end
	for i, defId in items do
		local b = ui.itemButtons[i]
		if b == nil then
			b = button(ui.grid, "Item")
			b.Text = ""
			b.BackgroundColor3 = TILE
			b.ClipsDescendants = true
			-- the model portrait, the type's icon bottom left, the cost bottom
			-- right, the hotkey and the queued count (BAR tiles, C-107, C-203)
			ui.portraits[i] = Portrait.new(b)
			local g = Glyph.new(b)
			g.root.AnchorPoint = Vector2.new(0, 1)
			g.root.Position = UDim2.new(0, 2, 1, -2)
			g.root.ZIndex = 4
			ui.itemGlyphs[i] = g
			local function costLabel(name: string, y: number, color: Color3): TextLabel
				local l = Instance.new("TextLabel")
				l.Name = name
				l.BackgroundTransparency = 1
				l.AnchorPoint = Vector2.new(1, 1)
				l.Position = UDim2.new(1, -3, 1, y)
				l.Size = UDim2.new(1, -24, 0, 12)
				l.Font = Enum.Font.GothamBold
				l.TextSize = 11
				l.TextColor3 = color
				l.TextStrokeTransparency = 0.35
				l.TextXAlignment = Enum.TextXAlignment.Right
				l.ZIndex = 4
				l.Parent = b
				return l
			end
			costLabel("Supply", -13, Color3.fromRGB(235, 235, 235))
			costLabel("Power", -1, Color3.fromRGB(255, 214, 60))
			local hot = Instance.new("TextLabel")
			hot.Name = "Hot"
			hot.BackgroundTransparency = 1
			hot.Position = UDim2.fromOffset(2, 1)
			hot.Size = UDim2.fromOffset(12, 11)
			hot.Font = Enum.Font.GothamBold
			hot.TextSize = 10
			hot.TextColor3 = Color3.fromRGB(255, 220, 90)
			hot.TextXAlignment = Enum.TextXAlignment.Left
			hot.ZIndex = 4
			hot.Parent = b
			-- an upgrade in place (C-121): a green badge under the hotkey
			local up = Instance.new("TextLabel")
			up.Name = "Upgrade"
			up.BackgroundTransparency = 1
			up.Position = UDim2.fromOffset(2, 13)
			up.Size = UDim2.fromOffset(50, 11)
			up.Font = Enum.Font.GothamBold
			up.TextSize = 9
			up.TextColor3 = Color3.fromRGB(110, 235, 130)
			up.TextStrokeTransparency = 0.35
			up.TextXAlignment = Enum.TextXAlignment.Left
			up.Text = "▲ UPGRADE"
			up.ZIndex = 4
			up.Parent = b
			local count = Instance.new("TextLabel")
			count.Name = "Count"
			count.BackgroundTransparency = 1
			count.AnchorPoint = Vector2.new(1, 0)
			count.Position = UDim2.new(1, -2, 0, 1)
			count.Size = UDim2.fromOffset(26, 14)
			count.Font = Enum.Font.GothamBold
			count.TextSize = 13
			count.TextColor3 = Color3.new(1, 1, 1)
			count.TextStrokeTransparency = 0.3
			count.TextXAlignment = Enum.TextXAlignment.Right
			count.ZIndex = 4
			count.Parent = b
			local index = i
			b.MouseEnter:Connect(function()
				ui.hovered = index
			end)
			b.MouseLeave:Connect(function()
				if ui.hovered == index then
					ui.hovered = nil
				end
			end)
			b.MouseButton1Click:Connect(function()
				pick(ui, api, index, shift())
			end)
			b.MouseButton2Click:Connect(function()
				local m = ui.menu
				local list = m and m.items[m.tabs[ui.tab] or ""]
				if list and list[index] then
					unqueue(ui, api, list[index])
				end
			end)
			ui.itemButtons[i] = b
		end
		local def = world.defs.units[defId]
		local n = queuedCount(api, menu, def.index)
		local cost = def.cost or {}
		b.LayoutOrder = i
		b.Visible = true
		local style = Icons.ofDef(def, world.me.team, 18)
		Glyph.apply(ui.itemGlyphs[i], style, TeamColors.of(world.me.team))
		Portrait.set(ui.portraits[i], def, world.me.team)
		;(b :: any).Supply.Text = tostring(cost.supply or 0)
		;(b :: any).Power.Text = tostring(cost.power or 0)
		;(b :: any).Hot.Text = if ui.armed and i <= 10 then tostring(i % 10) else ""
		;(b :: any).Count.Text = if n > 0 then tostring(n) else ""
		;(b :: any).Upgrade.Visible = Upgrades.isUpgrade(world.defs, def)
		b:SetAttribute("Cost", `{cost.supply or 0} supply, {cost.power or 0} power`)
		b.BackgroundColor3 = if n > 0 then Color3.fromRGB(64, 84, 64) else TILE
		b:SetAttribute("DefId", defId)
	end
	for i = #items + 1, #ui.itemButtons do
		ui.itemButtons[i].Visible = false
	end
end

return BuildMenuUI

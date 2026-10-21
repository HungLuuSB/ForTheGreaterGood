--!strict
-- Unit panel (C-68; BAR style since C-71), bottom left under the build
-- grid, a functional PLACEHOLDER. One unit selected: a portrait tile (the
-- type's glyph), name and role, health, then BAR's stat lines: DPS, weapon
-- range and reload, speed, build power, sight and radar, missiles in stock
-- (and the next one's progress), on / off and repeat, a factory's queue
-- (as the client queued it: not replicated yet). Several selected: a tile
-- per unit type with its count; a click keeps only that type. Ammo isn't on
-- the wire yet. Reads only the client API's state.

local Players = game:GetService("Players")

local Api = require("../Api")
local Icons = require("../Core/Icons")
local Precision = require("../Core/Precision")
local World = require("../Core/World")
local Glyph = require("./Glyph")
local TeamColors = require("../Render/TeamColors")

local UnitPanel = {}

local BG = Color3.fromRGB(18, 20, 24)
local TILE = Color3.fromRGB(58, 62, 70)
local WIDTH = 280

export type UI = {
	gui: ScreenGui,
	panel: Frame,
	portrait: Frame,
	portraitGlyph: Glyph.G,
	name: TextLabel,
	role: TextLabel,
	stats: TextLabel,
	health: Frame,
	healthFill: Frame,
	healthText: TextLabel,
	types: Frame,
	typeButtons: { TextButton },
	typeGlyphs: { Glyph.G },
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
	panel.Size = UDim2.fromOffset(WIDTH, 112)
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
	local healthText = textLabel(panel, Enum.Font.GothamBold, 11, Color3.fromRGB(180, 230, 180))
	healthText.Position = UDim2.fromOffset(6, 78)
	healthText.Size = UDim2.fromOffset(64, 28)
	local name = textLabel(panel, Enum.Font.GothamBold, 15, Color3.new(1, 1, 1))
	name.Position = UDim2.fromOffset(72, 4)
	name.Size = UDim2.new(1, -78, 0, 18)
	local role = textLabel(panel, Enum.Font.Gotham, 11, Color3.fromRGB(190, 190, 190))
	role.Position = UDim2.fromOffset(72, 21)
	role.Size = UDim2.new(1, -78, 0, 14)
	role.TextTruncate = Enum.TextTruncate.AtEnd
	local stats = textLabel(panel, Enum.Font.Gotham, 11, Color3.fromRGB(225, 225, 225))
	stats.Position = UDim2.fromOffset(72, 38)
	stats.Size = UDim2.new(1, -78, 1, -40)
	local types = Instance.new("Frame")
	types.Name = "Types"
	types.BackgroundTransparency = 1
	types.Position = UDim2.fromOffset(6, 6)
	types.Size = UDim2.new(1, -12, 1, -12)
	types.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(46, 46)
	gl.CellPadding = UDim2.fromOffset(3, 3)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = types
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return {
		gui = gui, panel = panel, portrait = portrait, portraitGlyph = pg, name = name, role = role, stats = stats,
		health = health, healthFill = fill, healthText = healthText, types = types, typeButtons = {}, typeGlyphs = {},
		icons = Icons.table(api.world.defs), codes = Icons.codes(api.world.defs), key = "",
	}
end

local function styleOf(ui: UI, def: any, team: number, size: number): any
	return Icons.ofDef(def, team, size)
end

-- BAR's stat lines for one unit.
local function statLines(world: World.World, def: any): { string }
	local dps, range, reload = 0, 0, nil
	for _, ws in def.weapons or {} do
		local w = world.defs.weaponByIndex[(ws :: any).weaponIndex] :: any
		if w then
			local best = 0
			for _, d in w.damage or {} do
				best = math.max(best, d)
			end
			local shots = (w.salvo or 1) * (w.projectiles or 1)
			dps += best * shots / math.max(w.reload or 1, 0.05)
			range = math.max(range, w.range or 0)
			reload = reload or w.reload
		end
	end
	local lines = {}
	if dps > 0 then
		table.insert(lines, string.format("DPS %d,  Weapon range %d,  Reload %.2f", math.floor(dps + 0.5), range, reload or 0))
	end
	local move = def.movement
	local sensors = def.sensors or {}
	local parts = {}
	if move and move.maxSpeed then
		table.insert(parts, string.format("Speed %d", math.floor(move.maxSpeed + 0.5)))
	end
	if def.buildPower then
		table.insert(parts, `Buildpower {def.buildPower}`)
	end
	if #parts > 0 then
		table.insert(lines, table.concat(parts, ",  "))
	end
	local see = {}
	if (sensors.sight or 0) > 0 then
		table.insert(see, `LoS {sensors.sight}`)
	end
	if (sensors.airSight or 0) > 0 then
		table.insert(see, `AirLoS {sensors.airSight}`)
	end
	if (sensors.radar or 0) > 0 then
		table.insert(see, `Radar {sensors.radar}`)
	end
	if (sensors.jam or 0) > 0 then
		table.insert(see, `Jammer {sensors.jam}`)
	end
	if #see > 0 then
		table.insert(lines, table.concat(see, ",  "))
	end
	return lines
end

local function one(ui: UI, api: Api.Api, id: number)
	local world = api.world
	local u = world.units[id]
	local def = u and World.def(world, u)
	if u == nil or def == nil then
		ui.name.Text, ui.role.Text, ui.stats.Text = "(out of view)", "", ""
		return
	end
	Glyph.apply(ui.portraitGlyph, styleOf(ui, def, u.team, 38), TeamColors(u.team))
	local h = World.shownHealth(world, u) or u.health or 1
	ui.healthFill.Size = UDim2.fromScale(math.clamp(h, 0, 1), 1)
	ui.healthText.Text = `{math.floor(h * (def.health or 0) + 0.5)}\n/ {def.health or 0}`
	ui.name.Text = def.name
	ui.role.Text = string.match(def.description or "", "^[^%.]*") or ""
	local lines = statLines(world, def)
	if u.build and u.build < 1 then
		table.insert(lines, 1, string.format("Building %d%%", math.floor(u.build * 100)))
	end
	local renderTick = world.shownTick or world.latestTick
	for slot, ws in def.weapons or {} do
		local cap = (ws :: any).stockCapacity
		if cap and u.stock then
			local line = `Stock {u.stock[slot] or 0}/{cap}`
			if (u.stock[slot] or 0) < cap then
				local shown = World.stockProgressOf(world, u, renderTick)
				if shown then
					line ..= string.format(", next %d%%", math.floor(shown * 100))
				end
			end
			table.insert(lines, line)
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
		table.insert(flags, "Queue: " .. table.concat(parts, ", "))
	end
	if #flags > 0 then
		table.insert(lines, table.concat(flags, "   "))
	end
	ui.stats.Text = table.concat(lines, "\n")
end

function UnitPanel.step(ui: UI, api: Api.Api)
	local sel = api.state.selection
	ui.panel.Visible = #sel > 0
	if #sel == 0 then
		return
	end
	local world = api.world
	local single = #sel == 1
	for _, f in { ui.portrait, ui.health, ui.healthText, ui.name, ui.role, ui.stats } :: { GuiObject } do
		f.Visible = single
	end
	ui.types.Visible = not single
	if single then
		one(ui, api, sel[1])
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
			local g = Glyph.new(b)
			g.root.Position = UDim2.fromScale(0.5, 0.45)
			ui.typeGlyphs[i] = g
			local count = Instance.new("TextLabel")
			count.Name = "Count"
			count.BackgroundTransparency = 1
			count.AnchorPoint = Vector2.new(1, 1)
			count.Position = UDim2.new(1, -2, 1, -1)
			count.Size = UDim2.fromOffset(30, 14)
			count.Font = Enum.Font.GothamBold
			count.TextSize = 12
			count.TextColor3 = Color3.new(1, 1, 1)
			count.TextStrokeTransparency = 0.3
			count.TextXAlignment = Enum.TextXAlignment.Right
			count.ZIndex = 4
			count.Parent = b
			ui.typeButtons[i] = b
			b.MouseButton1Click:Connect(function()
				local want = b:GetAttribute("DefIndex")
				local keep = {}
				for _, id in api.state.selection do
					local u = api.world.units[id]
					if u and u.defIndex == want then
						table.insert(keep, id)
					end
				end
				api.actions.select(keep)
			end)
		end
		b:SetAttribute("DefIndex", d)
		b.LayoutOrder = i
		b.Visible = true
		local def = world.defs.unitByIndex[d]
		Glyph.apply(ui.typeGlyphs[i], styleOf(ui, def, teams[d], 24), TeamColors(teams[d]))
		;(b :: any).Count.Text = tostring(counts[d])
	end
	for i = #order + 1, #ui.typeButtons do
		ui.typeButtons[i].Visible = false
	end
end

return UnitPanel

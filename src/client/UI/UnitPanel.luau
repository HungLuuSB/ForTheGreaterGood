--!strict
-- Unit panel (C-68, guide 15.7), a functional PLACEHOLDER. One unit
-- selected: its name and code, health, build progress, weapons (range,
-- missiles in stock and the next one's progress), on / off and repeat, and
-- a factory's queue (as the client queued it: not replicated yet). Several
-- selected: a button per unit type with its count; a click keeps only that
-- type. Ammo isn't on the wire yet: only stockpiles show. Reads only the
-- client API's state.

local Players = game:GetService("Players")

local Api = require("../Api")
local Icons = require("../Core/Icons")
local World = require("../Core/World")

local UnitPanel = {}

local BG = Color3.fromRGB(20, 22, 26)
local OFF = Color3.fromRGB(40, 44, 52)

export type UI = { gui: ScreenGui, panel: Frame, text: TextLabel, health: Frame, healthFill: Frame, types: Frame, typeButtons: { TextButton }, codes: { [number]: string }, key: string }

function UnitPanel.new(api: Api.Api): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "UnitPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -10)
	panel.Size = UDim2.fromOffset(440, 124)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(8, 20)
	text.Size = UDim2.new(1, -16, 1, -24)
	text.Font = Enum.Font.Code
	text.TextSize = 13
	text.TextColor3 = Color3.fromRGB(225, 225, 225)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.Parent = panel
	local health = Instance.new("Frame")
	health.Name = "Health"
	health.Position = UDim2.fromOffset(8, 6)
	health.Size = UDim2.new(1, -16, 0, 8)
	health.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
	health.BorderSizePixel = 0
	health.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 90)
	fill.BorderSizePixel = 0
	fill.Parent = health
	local types = Instance.new("Frame")
	types.Name = "Types"
	types.BackgroundTransparency = 1
	types.Position = UDim2.fromOffset(8, 8)
	types.Size = UDim2.new(1, -16, 1, -16)
	types.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(66, 32)
	gl.CellPadding = UDim2.fromOffset(4, 4)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = types
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, panel = panel, text = text, health = health, healthFill = fill, types = types, typeButtons = {}, codes = Icons.codes(api.world.defs), key = "" }
end

local function one(ui: UI, api: Api.Api, id: number): string
	local world = api.world
	local u = world.units[id]
	local def = u and World.def(world, u)
	if u == nil or def == nil then
		return "(out of view)"
	end
	local lines = {}
	local h = World.shownHealth(world, u) or u.health or 1
	ui.healthFill.Size = UDim2.fromScale(math.clamp(h, 0, 1), 1)
	local hp = math.floor(h * (def.health or 0) + 0.5)
	table.insert(lines, `{ui.codes[def.index] or ""}  {def.name}   {hp} / {def.health or 0} hp`)
	if u.build and u.build < 1 then
		table.insert(lines, string.format("building: %d%%", math.floor(u.build * 100)))
	end
	local renderTick = world.shownTick or world.latestTick
	for slot, ws in def.weapons or {} do
		local w = world.defs.weaponByIndex[(ws :: any).weaponIndex] :: any
		if w then
			local line = `{w.id}: range {w.range}`
			local cap = (ws :: any).stockCapacity
			if cap and u.stock then
				line ..= `, stock {u.stock[slot] or 0}/{cap}`
				local p = u.stockProgress and u.stockProgress[slot]
				if p and (u.stock[slot] or 0) < cap then
					local shown = World.stockProgressOf(world, u, renderTick)
					line ..= string.format(" (next %d%%)", math.floor((shown or p[1]) * 100))
				end
			end
			table.insert(lines, line)
		end
	end
	local st = u.state or 0
	local flags = {}
	local sensors = def.sensors or {}
	if (sensors.radar or 0) > 0 or (sensors.jam or 0) > 0 or def.converter then -- (0 is truthy)
		table.insert(flags, if bit32.band(st, 2) ~= 0 then "on" else "off")
	end
	if bit32.band(st, 16) ~= 0 then
		table.insert(flags, "repeat")
	end
	if #flags > 0 then
		table.insert(lines, table.concat(flags, ", "))
	end
	local q = api.state.factoryQueues[id]
	if q and #q > 0 then
		local parts, last, count = {}, nil, 0
		for i = 1, #q + 1 do
			if q[i] ~= last then
				if last then
					table.insert(parts, `{ui.codes[last] or "?"} x{count}`)
				end
				last, count = q[i], 0
			end
			count += 1
		end
		table.insert(lines, "queue: " .. table.concat(parts, "  "))
	end
	return table.concat(lines, "\n")
end

function UnitPanel.step(ui: UI, api: Api.Api)
	local sel = api.state.selection
	ui.panel.Visible = #sel > 0
	if #sel == 0 then
		return
	end
	local world = api.world
	if #sel == 1 then
		ui.types.Visible = false
		ui.text.Visible, ui.health.Visible = true, true
		ui.text.Text = one(ui, api, sel[1])
		return
	end
	ui.text.Visible, ui.health.Visible = false, false
	ui.types.Visible = true
	-- a button per type
	local counts, order = {}, {}
	for _, id in sel do
		local u = world.units[id]
		local d = u and u.defIndex
		if d then
			if counts[d] == nil then
				counts[d] = 0
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
			b.BackgroundColor3 = OFF
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamBold
			b.TextSize = 12
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Parent = ui.types
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
		b.Text = `{ui.codes[d] or "?"} x{counts[d]}`
		b.Visible = true
	end
	for i = #order + 1, #ui.typeButtons do
		ui.typeButtons[i].Visible = false
	end
end

return UnitPanel

--!strict
-- Command card (C-68; BAR style since C-71), bottom left next to the unit
-- panel, a functional PLACEHOLDER: small grey text buttons in BAR's order.
-- State buttons on the top row carry a colored bar under the text (fire
-- state: at will green, return yellow, hold red; move state: roam green,
-- maneuver yellow, hold red; repeat and on / off: green on, red off); the
-- command modes (move, fight, attack, patrol, guard: the next left click
-- gives the order) light up while active. Hotkeys (Input/Controls) show on
-- hover. Fire and move states are the server's (protocol 20, S-61) for
-- the first selected unit that has them. Acts only through the client API.
-- Only the selection's own commands show (Core/CommandSet, C-109): a
-- defense has stop / attack / fire state, a builder movement, repair,
-- reclaim and guard (assist), a silo stop and a manual attack, a factory
-- its queue and orders for the units it builds. Repair and reclaim are
-- command modes like attack (reclaim: the known wreck nearest the click).

local Players = game:GetService("Players")

local Api = require("../Api")
local Kit = require("./Kit")
local World = require("../Core/World")
local CommandSet = require("../Core/CommandSet")
local SettingsMenu = require("./SettingsMenu")

local CommandCard = {}

local BG = Kit.COLOR.panel
local BTN = Kit.COLOR.control
local ACTIVE = Kit.COLOR.selected
local GREEN, YELLOW, RED = Color3.fromRGB(90, 210, 90), Color3.fromRGB(230, 200, 60), Color3.fromRGB(220, 70, 60)
local FIRE = { [0] = { "Hold fire", RED }, [1] = { "Return fire", YELLOW }, [2] = { "Fire at will", GREEN } }
local MOVE = { [0] = { "Hold pos", RED }, [1] = { "Maneuver", YELLOW }, [2] = { "Roam", GREEN } }
local COLS = 5
local W, H = 64, 24

export type UI = { gui: ScreenGui, panel: Frame, buttons: { [string]: TextButton }, shown: string }

local function selected(api: Api.Api): (boolean, boolean, { number }, boolean)
	local anyOn, anyRepeat, factories = false, false, {}
	local switchable = false -- converters, beam towers and shield generators (S-154): the units the on / off bit does something for
	for _, id in api.state.selection do
		local u = api.world.units[id]
		if u then
			local d = World.def(api.world, u)
			switchable = switchable or (d ~= nil and (d.converter ~= nil or d.retract ~= nil or d.shield ~= nil)) -- beam towers retract when off (S-96); shields go down (S-154)
			anyOn = anyOn or bit32.band(u.state or 0, 2) ~= 0
			anyRepeat = anyRepeat or bit32.band(u.state or 0, 16) ~= 0
			local def = World.def(api.world, u)
			if def and def.domain == "structure" and def.buildOptions and #def.buildOptions > 0 then
				table.insert(factories, id)
			end
		end
	end
	return anyOn, anyRepeat, factories, switchable
end

-- BAR's order: states, then orders.
local ORDER = CommandSet.ORDER
-- each button's key action (Core/Keybinds; rebindable, C-159)
local ACTION = { move = "move", fight = "fight", attack = "attack", patrol = "patrol", guard = "guard", stop = "stop", fire = "fireState", movestate = "moveState", ["repeat"] = "repeat", toggle = "toggle", cancel = "cancel", alert = "lastAlert", reclaim = "reclaim" }
local function keyOf(name: string): string
	local id = ACTION[name]
	return if id then SettingsMenu.binds[id] or "" else ""
end
local STATES = { fire = true, movestate = true, ["repeat"] = true, toggle = true }

local function act(api: Api.Api, name: string)
	local a = api.actions
	if name == "move" or name == "fight" or name == "attack" or name == "patrol" or name == "guard" or name == "repair" or name == "reclaim" or name == "upgrade" then
		a.setCommandMode(if api.state.commandMode == name then nil else name)
	elseif name == "stop" then
		a.stop()
	elseif name == "fire" then
		a.setFireState(((api.state.fireState or 1) + 1) % 3)
	elseif name == "movestate" then
		a.setMoveState(((api.state.moveState or 1) + 1) % 3)
	elseif name == "repeat" then
		local _, anyRepeat = selected(api)
		a.setRepeat(not anyRepeat)
	elseif name == "toggle" then
		local anyOn = selected(api)
		a.toggle(not anyOn)
	elseif name == "cancel" then
		local _, _, factories = selected(api)
		local q = factories[1] and api.state.factoryQueues[factories[1]]
		a.cancel(if q and #q > 0 then #q else 0)
	elseif name == "alert" then
		local list = api.state.alerts
		for i = #list, 1, -1 do
			if list[i].at then
				a.focusCamera(list[i].x, list[i].z)
				break
			end
		end
	end
end

function CommandCard.new(api: Api.Api): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "CommandCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 464, 1, 0) -- right of the 460-pixel unit panel (C-76)
	local rows = math.ceil(#ORDER / COLS)
	panel.Size = UDim2.fromOffset(COLS * (W + 3) + 7, rows * (H + 4) + 8)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(W, H)
	grid.CellPadding = UDim2.fromOffset(3, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = panel
	local buttons = {}
	for i, name in ORDER do
		local b = Instance.new("TextButton")
		b.Name = name
		b.LayoutOrder = i
		b.BackgroundColor3 = BTN
		b.BorderSizePixel = 0
		b.Font = Enum.Font.Gotham
		b.TextSize = 11
		b.TextColor3 = Color3.fromRGB(235, 235, 235)
		b.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 2)
		c.Parent = b
		if STATES[name] then
			local bar = Instance.new("Frame")
			bar.Name = "State"
			bar.AnchorPoint = Vector2.new(0.5, 1)
			bar.Position = UDim2.new(0.5, 0, 1, -2)
			bar.Size = UDim2.new(0.6, 0, 0, 2)
			bar.BorderSizePixel = 0
			bar.Parent = b
		end
		b.MouseButton1Click:Connect(function()
			act(api, name)
		end)
		buttons[name] = b
	end
	Kit.skin(gui) -- the UI kit's look (C-105)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, panel = panel, buttons = buttons, shown = "" }
end

function CommandCard.step(ui: UI, api: Api.Api)
	ui.panel.Visible = #api.state.selection > 0
	if not ui.panel.Visible then
		return
	end
	local anyOn, anyRepeat, factories, switchable = selected(api)
	-- this selection's commands only, packed into rows
	local defs = {}
	for _, id in api.state.selection do
		local u = api.world.units[id]
		local d = u and World.def(api.world, u)
		if d then
			table.insert(defs, d)
		end
	end
	local list = CommandSet.of(defs, api.world.defs)
	local shown = table.concat(list, ",")
	if shown ~= ui.shown then
		ui.shown = shown
		local on = {}
		for i, name in list do
			on[name] = i
		end
		for name, b in ui.buttons do
			b.Visible = on[name] ~= nil
			b.LayoutOrder = on[name] or 99
		end
		local rows = math.max(1, math.ceil(#list / COLS))
		ui.panel.Size = UDim2.fromOffset(COLS * (W + 3) + 7, rows * (H + 4) + 8)
	end
	local fire = FIRE[api.state.fireState or -1]
	local move = MOVE[api.state.moveState or -1]
	-- builders guarding a builder or a factory help it build (S-128, C-163)
	local builders = #defs > 0
	for _, d in defs do
		if d.buildPower == nil or d.domain == "structure" then
			builders = false
		end
	end
	local label = {
		fire = if fire then fire[1] else "Fire state",
		movestate = if move then move[1] else "Move state",
		["repeat"] = "Repeat",
		-- only converters, beam towers and shields switch (the sim's TOGGLED_ON bit); for anything else
		-- "Off" in red read as a stopped factory (the user, C-107)
		toggle = if not switchable then "On / Off" elseif anyOn then "On" else "Off",
		cancel = "Cancel",
		stop = "Stop",
		attack = "Attack",
		move = "Move",
		patrol = "Patrol",
		fight = "Fight",
		guard = if builders then "Assist" else "Guard",
		alert = "Last alert",
		repair = "Repair",
		reclaim = "Reclaim",
		upgrade = "Upgrade", -- Upgrade extractors (C-121)
	}
	local stateColor = {
		fire = if fire then fire[2] else Color3.fromRGB(110, 110, 110),
		movestate = if move then move[2] else Color3.fromRGB(110, 110, 110),
		["repeat"] = if anyRepeat then GREEN else RED,
		toggle = if not switchable then Color3.fromRGB(110, 110, 110) elseif anyOn then GREEN else RED,
	}
	local mouse = game:GetService("UserInputService"):GetMouseLocation()
	local inset = game:GetService("GuiService"):GetGuiInset()
	for name, b in ui.buttons do
		-- the hotkey while hovered, else the label
		local p, s = b.AbsolutePosition, b.AbsoluteSize
		local over = mouse.X >= p.X and mouse.X <= p.X + s.X and mouse.Y - inset.Y >= p.Y and mouse.Y - inset.Y <= p.Y + s.Y
		local key = keyOf(name)
		b.Text = if over and key ~= "" then `{label[name]} [{key}]` else label[name]
		b.BackgroundColor3 = if api.state.commandMode == name then ACTIVE else BTN
		local bar = b:FindFirstChild("State") :: Frame?
		if bar then
			bar.BackgroundColor3 = stateColor[name]
		end
	end
	ui.buttons["repeat"].TextTransparency = if #factories > 0 then 0 else 0.5
	ui.buttons.toggle.TextTransparency = if switchable then 0 else 0.5
end

return CommandCard

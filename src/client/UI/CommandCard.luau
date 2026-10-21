--!strict
-- Command card (C-68, guide 15.7), a functional PLACEHOLDER: the selected
-- units' commands and states, each button with its hotkey (Input/Controls
-- has the same keys): move, fight, attack, patrol, guard (a mode: the next
-- left click gives it), stop, fire state, move state, factory repeat,
-- on / off, cancel, jump to the last alert. Fire and move states show the
-- last one sent (the wire doesn't carry them yet). Acts only through the
-- client API.

local Players = game:GetService("Players")

local Api = require("../Api")
local World = require("../Core/World")

local CommandCard = {}

local BG = Color3.fromRGB(20, 22, 26)
local ON = Color3.fromRGB(70, 110, 160)
local OFF = Color3.fromRGB(40, 44, 52)
local FIRE = { [0] = "Hold fire", [1] = "Return fire", [2] = "Fire at will" }
local MOVE = { [0] = "Hold pos", [1] = "Maneuver", [2] = "Roam" }

export type UI = { gui: ScreenGui, panel: Frame, buttons: { [string]: TextButton } }

-- What the selection is: any toggled on, any repeating, its factories.
local function selected(api: Api.Api): (boolean, boolean, { number })
	local anyOn, anyRepeat, factories = false, false, {}
	for _, id in api.state.selection do
		local u = api.world.units[id]
		if u then
			anyOn = anyOn or bit32.band(u.state or 0, 2) ~= 0
			anyRepeat = anyRepeat or bit32.band(u.state or 0, 16) ~= 0
			local def = World.def(api.world, u)
			if def and def.domain == "structure" and def.buildOptions and #def.buildOptions > 0 then
				table.insert(factories, id)
			end
		end
	end
	return anyOn, anyRepeat, factories
end

local ORDER = { "move", "fight", "attack", "patrol", "guard", "stop", "fire", "movestate", "repeat", "toggle", "cancel", "alert" }
local KEYS = { move = "M", fight = "F", attack = "A", patrol = "Z", guard = "G", stop = "S", fire = "L", movestate = "K", ["repeat"] = "Y", toggle = "U", cancel = "X", alert = "J" }

local function act(api: Api.Api, name: string)
	local a = api.actions
	if name == "move" or name == "fight" or name == "attack" or name == "patrol" or name == "guard" then
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
			if list[i].kind ~= "stall" then
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
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -10, 1, -10)
	panel.Size = UDim2.fromOffset(4 * 74 + 8, 3 * 38 + 8)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(70, 34)
	grid.CellPadding = UDim2.fromOffset(4, 4)
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
		b.BackgroundColor3 = OFF
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 11
		b.TextWrapped = true
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Parent = panel
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = b
		b.MouseButton1Click:Connect(function()
			act(api, name)
		end)
		buttons[name] = b
	end
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, panel = panel, buttons = buttons }
end

function CommandCard.step(ui: UI, api: Api.Api)
	ui.panel.Visible = #api.state.selection > 0
	if not ui.panel.Visible then
		return
	end
	local anyOn, anyRepeat, factories = selected(api)
	local label = {
		move = "Move",
		fight = "Fight",
		attack = "Attack",
		patrol = "Patrol",
		guard = "Guard",
		stop = "Stop",
		fire = FIRE[api.state.fireState or -1] or "Fire state",
		movestate = MOVE[api.state.moveState or -1] or "Move state",
		["repeat"] = if anyRepeat then "Repeat on" else "Repeat off",
		toggle = if anyOn then "On" else "Off",
		cancel = "Cancel",
		alert = "Last alert",
	}
	for name, b in ui.buttons do
		b.Text = `{label[name]}\n[{KEYS[name]}]`
		local active = api.state.commandMode == name or (name == "toggle" and anyOn) or (name == "repeat" and anyRepeat)
		b.BackgroundColor3 = if active then ON else OFF
		b.AutoButtonColor = true
	end
	ui.buttons["repeat"].TextTransparency = if #factories > 0 then 0 else 0.5
end

return CommandCard

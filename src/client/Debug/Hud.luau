--!strict
-- Debug readout (guide 17.3), toggled with F3: tick, render delay, unit
-- counts, dropped records. Placeholder UI.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local World = require("../Core/World")

local Hud = {}

export type Hud = { label: TextLabel, nextUpdate: number }

function Hud.new(): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local label = Instance.new("TextLabel")
	label.Name = "Readout"
	label.BackgroundTransparency = 0.4
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.Code
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.AnchorPoint = Vector2.new(1, 1)
	label.Position = UDim2.new(1, -8, 1, -8) -- bottom right (C-124; top right until then), over the team panel while shown
	label.Text = ""
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = label
	-- off in a live game (F3 shows it): the team panel has its corner (F23)
	gui.Enabled = game:GetService("RunService"):IsStudio()
	gui.DisplayOrder = 20
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F3 then
			gui.Enabled = not gui.Enabled
		end
	end)
	return { label = label, nextUpdate = 0 }
end

function Hud.update(h: Hud, world: World.World, renderTick: number, drawn: number, rect: { number }, now: number, selected: number, placing: string?, speed: number?)
	if now < h.nextUpdate then
		return
	end
	h.nextUpdate = now + 0.25
	local tactical, strategic, own = 0, 0, 0
	for _, u in world.units do
		if u.tier == "tactical" then
			tactical += 1
		else
			strategic += 1
		end
		if u.team == world.me.team then
			own += 1
		end
	end
	h.label.Text = string.format(
		"FTGG client (F3)\ntick %d  render %.1f (%.1f behind)\nunits %d tactical, %d strategic, %d own; %d models; %d selected\ncamera cells %d,%d .. %d,%d\ndropped %d",
		world.latestTick,
		renderTick,
		world.latestTick - renderTick,
		tactical,
		strategic,
		own,
		drawn,
		selected,
		rect[1],
		rect[2],
		rect[3],
		rect[4],
		world.dropped
	) .. (if placing then "\nplacing " .. placing else "") .. (if speed and speed ~= 1 then (if speed == 0 then "\nsim PAUSED (P)" else string.format("\nsim speed %gx (- / =, P pause)", speed)) else "")
end

return Hud

--!strict
-- Idle counts in the top strip (C-158, BAR's idle indicators): right of
-- the resource bar, idle builders and idle factories (Core/Idle). Amber
-- when there are any; a click on one jumps to the next (the camera follows
-- it), as the I key does for builders. A placeholder look in the UI kit.

local Players = game:GetService("Players")

local Kit = require("./Kit")

local IdleStrip = {}

local DIM = Color3.fromRGB(150, 150, 150)

export type Strip = { gui: ScreenGui, builders: TextButton, factories: TextButton, shown: string }

local function line(parent: Instance, y: number): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundTransparency = 1
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextColor3 = DIM
	b.Position = UDim2.fromOffset(8, y)
	b.Size = UDim2.new(1, -12, 0, 16)
	b.AutoButtonColor = false
	b.Parent = parent
	return b
end

-- `pick(kind)` is called on a click ("builder" or "factory").
function IdleStrip.new(pick: (string) -> ()): Strip
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggIdle"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	local root = Instance.new("Frame")
	root.Name = "Idle"
	root.AnchorPoint = Vector2.new(0, 0)
	-- the resource bar is 546 px wide, centred, 6 px down (UI/ResourceBar)
	root.Position = UDim2.new(0.5, 279, 0, 6)
	root.Size = UDim2.fromOffset(128, 40)
	root.BackgroundColor3 = Kit.COLOR.panel
	root.BorderSizePixel = 0
	root.Parent = gui
	local builders = line(root, 3)
	local factories = line(root, 21)
	builders.MouseButton1Click:Connect(function()
		pick("builder")
	end)
	factories.MouseButton1Click:Connect(function()
		pick("factory")
	end)
	Kit.skin(gui)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, builders = builders, factories = factories, shown = "" }
end

function IdleStrip.step(strip: Strip, builders: number, factories: number)
	local key = `{builders}/{factories}`
	if key == strip.shown then
		return
	end
	strip.shown = key
	strip.builders.Text = `Idle builders (I): {builders}`
	strip.builders.TextColor3 = if builders > 0 then Kit.COLOR.accent else DIM
	strip.factories.Text = `Idle factories: {factories}`
	strip.factories.TextColor3 = if factories > 0 then Kit.COLOR.accent else DIM
end

return IdleStrip

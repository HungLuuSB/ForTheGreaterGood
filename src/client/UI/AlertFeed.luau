--!strict
-- Alert feed (C-68, guide 15.7), a functional PLACEHOLDER: the newest
-- alerts (the server's, Core/Alerts through the API's `alert` signal) as lines at the top
-- right that fade after SHOW seconds; a click jumps the camera there (J jumps
-- to the last one, Input/Controls). Each alert also pings the minimap.

local Players = game:GetService("Players")

local Api = require("../Api")

local AlertFeed = {}

AlertFeed.SHOW = 8 -- seconds a line stays
AlertFeed.LINES = 5
local COLOR = {
	attack = Color3.fromRGB(255, 170, 70),
	lost = Color3.fromRGB(255, 90, 80),
	stall = Color3.fromRGB(240, 220, 90),
	nuke = Color3.fromRGB(255, 60, 60),
	commander = Color3.fromRGB(255, 120, 60),
	built = Color3.fromRGB(130, 220, 130),
}
AlertFeed.COLOR = COLOR

export type UI = { gui: ScreenGui, list: Frame, lines: { { button: TextButton, alert: any, at: number } } }

function AlertFeed.new(api: Api.Api): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Alerts"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.IgnoreGuiInset = true -- the resource bar moved up into the top strip (C-109)
	local list = Instance.new("Frame")
	list.Name = "List"
	list.AnchorPoint = Vector2.new(0, 0)
	list.Position = UDim2.new(0.5, -273, 0, 52) -- under the resource bar, like BAR's messages (C-71)
	list.Size = UDim2.fromOffset(300, AlertFeed.LINES * 24)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = list
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local ui: UI = { gui = gui, list = list, lines = {} }
	api.changed.alert:Connect(function(alert: any)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(300, 21)
		b.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
		b.BackgroundTransparency = 1
		b.TextStrokeTransparency = 0.3
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 13
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.TextColor3 = COLOR[alert.kind] or Color3.new(1, 1, 1)
		b.Text = alert.text
		b.LayoutOrder = -math.floor(alert.time * 100)
		b.Parent = list
		b.MouseButton1Click:Connect(function()
			if alert.at then
				api.actions.focusCamera(alert.x, alert.z)
			end
		end)
		table.insert(ui.lines, 1, { button = b, alert = alert, at = os.clock() })
		while #ui.lines > AlertFeed.LINES do
			local old = table.remove(ui.lines) :: any
			old.button:Destroy()
		end
	end)
	return ui
end

function AlertFeed.step(ui: UI)
	local now = os.clock()
	for i = #ui.lines, 1, -1 do
		local l = ui.lines[i]
		local age = now - l.at
		if age > AlertFeed.SHOW then
			l.button:Destroy()
			table.remove(ui.lines, i)
		elseif age > AlertFeed.SHOW - 1 then
			local t = age - (AlertFeed.SHOW - 1)
			l.button.TextTransparency = t
			l.button.TextStrokeTransparency = 0.3 + 0.7 * t
		end
	end
end

return AlertFeed

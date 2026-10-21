--!strict
-- PLACEHOLDER camera follow button (C-43), bottom left next to the minimap:
-- "Follow (T)" starts following (the first selected unit, else the missile
-- nearest the screen centre), "Stop follow (T)" while following.

local Players = game:GetService("Players")

local FollowButton = {}

export type Button = { gui: ScreenGui, button: TextButton }

function FollowButton.new(onClick: () -> ()): Button
	local gui = Instance.new("ScreenGui")
	gui.Name = "FollowButton"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local button = Instance.new("TextButton")
	button.Name = "Follow"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -8, 1, -8) -- bottom right corner (BAR layout, C-71)
	button.Size = UDim2.fromOffset(140, 26)
	button.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.Code
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = "Follow (T)"
	button.Parent = gui
	button.Activated:Connect(onClick)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, button = button }
end

-- `label`: what is followed ("Falcon", "missile"), nil when nothing is.
function FollowButton.step(b: Button, label: string?)
	local text = if label then `Stop follow (T): {label}` else "Follow (T)"
	if b.button.Text ~= text then
		b.button.Text = text
		b.button.Size = UDim2.fromOffset(if label then 160 + 8 * #label else 140, 26)
		b.button.TextColor3 = if label then Color3.fromRGB(110, 220, 255) else Color3.new(1, 1, 1)
	end
end

return FollowButton

--!strict
-- The mouse cursor while a command is chosen (C-263, the user: the command
-- buttons don't need icons; the icon can be the cursor while choosing a
-- command): 2D-E's icon for that command (UI/UiIcons, E-10) in its order
-- colour, centred on the point a click gives the order at. Roblox's mouse
-- icon takes a whole image, not a rect of the atlas, so the system cursor is
-- hidden and the icon is drawn at the mouse each frame. A command without an
-- icon, or before the atlas is uploaded, keeps the system cursor.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UiIcon = require("./UiIcon")
local UiIcons = require("./UiIcons")

local CommandCursor = {}

CommandCursor.SIZE = 24 -- pixels

export type UI = { gui: ScreenGui, icon: ImageLabel?, kind: string? }

function CommandCursor.new(): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggCommandCursor"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100 -- over every panel
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, icon = nil, kind = nil }
end

-- Once a frame: the cursor for command `kind` (nil: none chosen).
function CommandCursor.step(ui: UI, kind: string?)
	if kind ~= ui.kind then
		ui.kind = kind
		if ui.icon then
			ui.icon:Destroy()
			ui.icon = nil
		end
		local info = kind and UiIcons.icons[kind]
		if info then
			local icon = UiIcon.make(kind :: string, CommandCursor.SIZE)
			if icon then
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = ui.gui
				ui.icon = icon
			end
		end
		UserInputService.MouseIconEnabled = ui.icon == nil
	end
	local icon = ui.icon
	if icon then
		local at = UserInputService:GetMouseLocation()
		icon.Position = UDim2.fromOffset(at.X, at.Y)
	end
end

return CommandCursor

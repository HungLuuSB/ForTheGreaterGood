--!strict
-- Replay controls (C-79), a functional PLACEHOLDER at the bottom centre
-- while a replay plays: play / pause, slower / faster with the speed, the
-- time played and the length, a seek bar (click anywhere on it), and Exit
-- (back to the live match). Also the banner at the top centre that says
-- what the view is: a replay of a player, or spectating everyone. Reads
-- Core/ReplayPlayer's state; the callbacks do the work.

local Players = game:GetService("Players")

local ReplayPlayer = require("../Core/ReplayPlayer")

local ReplayBar = {}

local BG = Color3.fromRGB(16, 18, 22)
local BTN = Color3.fromRGB(52, 56, 64)
local FILL = Color3.fromRGB(90, 150, 220)

export type Callbacks = {
	toggle: () -> (),
	faster: (up: boolean) -> (),
	seek: (fraction: number) -> (),
	exit: () -> (),
}

export type UI = { gui: ScreenGui, bar: Frame, play: TextButton, speed: TextLabel, time: TextLabel, track: TextButton, fill: Frame, banner: TextLabel }

local function button(parent: Instance, text: string, w: number, click: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 26)
	b.BackgroundColor3 = BTN
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = #parent:GetChildren()
	b.Parent = parent
	b.MouseButton1Click:Connect(click)
	return b
end

local function text(parent: Instance, w: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromOffset(w, 26)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextColor3 = Color3.new(1, 1, 1)
	l.LayoutOrder = #parent:GetChildren()
	l.Parent = parent
	return l
end

function ReplayBar.new(cb: Callbacks): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Replay"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -8)
	bar.Size = UDim2.fromOffset(620, 40)
	bar.BackgroundColor3 = BG
	bar.BackgroundTransparency = 0.1
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingTop = UDim.new(0, 7), UDim.new(0, 7)
	pad.Parent = bar
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = bar
	local play = button(bar, "Pause", 64, cb.toggle)
	button(bar, "−", 26, function()
		cb.faster(false)
	end)
	local speed = text(bar, 40)
	button(bar, "+", 26, function()
		cb.faster(true)
	end)
	local time = text(bar, 96)
	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.Size = UDim2.fromOffset(250, 26)
	track.BackgroundColor3 = BTN
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.LayoutOrder = #bar:GetChildren()
	track.Parent = bar
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = FILL
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	track.MouseButton1Down:Connect(function(x: number)
		cb.seek(math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1))
	end)
	button(bar, "Exit", 56, cb.exit)
	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 56)
	banner.Size = UDim2.fromOffset(520, 22)
	banner.BackgroundColor3 = BG
	banner.BackgroundTransparency = 0.25
	banner.BorderSizePixel = 0
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 13
	banner.TextColor3 = Color3.fromRGB(255, 220, 120)
	banner.Visible = false
	banner.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, bar = bar, play = play, speed = speed, time = time, track = track, fill = fill, banner = banner }
end

local function clock(seconds: number): string
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds) % 60)
end

-- `p` the replay playing (nil: live); `banner` the view's line, or nil.
function ReplayBar.step(ui: UI, p: ReplayPlayer.Player?, banner: string?)
	ui.banner.Visible = banner ~= nil
	ui.banner.Text = banner or ""
	ui.bar.Visible = p ~= nil
	if p == nil then
		return
	end
	local played, total = ReplayPlayer.progress(p)
	ui.play.Text = if p.paused or ReplayPlayer.done(p) then "Play" else "Pause"
	ui.speed.Text = `{p.speed}×`
	ui.time.Text = `{clock(math.max(played, 0))} / {clock(total)}`
	ui.fill.Size = UDim2.fromScale(math.clamp(played / math.max(total, 1e-6), 0, 1), 1)
end

return ReplayBar

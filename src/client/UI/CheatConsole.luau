--!strict
-- The cheat command line (C-119, BAR's /cheat): Enter or "/" opens a UI-kit
-- bar at the bottom centre; typing shows suggestions (Core/CheatInput:
-- commands, then unit ids or names after "give"; Tab or a click takes the
-- first / that one); Enter sends, Escape closes, Up / Down walk the
-- history. Lines and the server's results print in a log above the bar,
-- fading after a while. Ctrl+Shift+G repeats the last give at the cursor.
-- Roblox's chat window is off (C-109), so this is the game's command line;
-- the same commands are also TextChatService commands (Main), for when it
-- is on. `submit(line)` does the sending (Main: CheatText and the Cmd
-- channel, or the stub until the sim's side is in).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CheatInput = require("../Core/CheatInput")
local Kit = require("./Kit")

local CheatConsole = {}

CheatConsole.LOG_LINES = 16 -- /help alone is 13
CheatConsole.LOG_SECONDS = 12 -- a line fades out after this long
CheatConsole.TOP_CLEAR = 76 -- the log never climbs over the resource bar (its oldest lines clip)

export type UI = {
	gui: ScreenGui,
	bar: Frame,
	box: TextBox,
	suggest: Frame,
	log: Frame,
	logRoom: number, -- pixels the log may take (placeLog)
	lines: { { label: TextLabel, at: number } },
	history: { string },
	historyAt: number,
	lastGive: string?,
	submit: (string) -> (),
	defs: any,
	suggestions: { CheatInput.Suggestion },
	sent: boolean, -- this line went already (Return seen before FocusLost)
}

-- The log's bottom `above` pixels up from the screen bottom, its height
-- capped to the room under the top HUD.
local function placeLog(ui: UI, above: number)
	ui.log.Position = UDim2.new(0.5, 0, 1, -above)
	local screen = ui.gui.AbsoluteSize.Y
	ui.logRoom = math.max(40, screen - above - CheatConsole.TOP_CLEAR)
end

local function suggestionRows(ui: UI)
	for _, c in ui.suggest:GetChildren() do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	ui.suggestions = CheatInput.suggest(ui.box.Text, ui.defs)
	for i, s in ui.suggestions do
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.new(1, 0, 0, 22)
		b.BackgroundColor3 = Kit.COLOR.raised
		b.BackgroundTransparency = if i == 1 then 0.9 else 1
		b.BorderSizePixel = 0
		b.FontFace = Kit.font(Enum.FontWeight.Regular)
		b.TextSize = 13
		b.TextColor3 = if i == 1 then Kit.COLOR.text else Kit.COLOR.dim
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Text = s.label
		b.LayoutOrder = i
		b.Parent = ui.suggest
		Kit.pad(b, Kit.SPACE.s, 0, Kit.SPACE.s, 0)
		b.MouseButton1Click:Connect(function()
			ui.box.Text = s.text
			ui.box.CursorPosition = #s.text + 1
			ui.box:CaptureFocus()
		end)
	end
	ui.suggest.Visible = #ui.suggestions > 0
	ui.suggest.Size = UDim2.new(1, 0, 0, #ui.suggestions * 22 + 8)
	-- the log stays above the suggestions
	placeLog(ui, 230 + (if ui.suggest.Visible then #ui.suggestions * 22 + 8 else 0))
end

-- Prints `text` in the log (`color`: dim for echoes, text for results).
function CheatConsole.print(ui: UI, text: string, color: Color3?)
	local l = Kit.text(ui.log, text, "label", color or Kit.COLOR.text)
	l.TextStrokeTransparency = 0.6
	l.TextWrapped = true
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Size = UDim2.new(1, 0, 0, 0)
	l.LayoutOrder = (#ui.lines > 0 and ui.lines[#ui.lines].label.LayoutOrder or 0) + 1
	table.insert(ui.lines, { label = l, at = os.clock() })
	while #ui.lines > CheatConsole.LOG_LINES do
		table.remove(ui.lines, 1).label:Destroy()
	end
end

local function send(ui: UI, line: string)
	local text = string.gsub(line, "^%s+", "")
	if text == "" then
		return
	end
	table.insert(ui.history, text)
	ui.historyAt = #ui.history + 1
	CheatConsole.print(ui, "> " .. text, Kit.COLOR.dim)
	local s = string.lower(CheatInput.strip(text))
	if s == "help" or s == "?" then
		for _, h in CheatInput.help() do
			CheatConsole.print(ui, h, Kit.COLOR.dim)
		end
		return
	end
	if string.sub(s, 1, 5) == "give " then
		ui.lastGive = text
	end
	ui.submit(text)
end

-- Sends `line` as if typed and entered (the debug hook, C-119).
function CheatConsole.enter(ui: UI, line: string)
	send(ui, line)
end

function CheatConsole.open(ui: UI, start: string?)
	ui.bar.Visible = true
	ui.box.Text = start or ""
	ui.box:CaptureFocus()
	ui.box.CursorPosition = #ui.box.Text + 1
	suggestionRows(ui)
end

function CheatConsole.close(ui: UI)
	ui.bar.Visible = false
	ui.suggest.Visible = false
	placeLog(ui, 230)
	ui.box:ReleaseFocus()
end

-- Repeats the last give (at the cursor now): Ctrl+Shift+G.
function CheatConsole.repeatGive(ui: UI)
	if ui.lastGive then
		local w = {}
		for x in string.gmatch(ui.lastGive, "%S+") do
			if string.lower(x) == "at" then
				break -- drop the old position: the cursor's goes in
			end
			table.insert(w, x)
		end
		send(ui, table.concat(w, " "))
	else
		CheatConsole.print(ui, "no /give to repeat yet", Kit.COLOR.dim)
	end
end

function CheatConsole.new(defs: any, submit: (string) -> ()): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "CheatConsole"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true
	local log = Instance.new("Frame")
	log.Name = "Log"
	log.BackgroundColor3 = Kit.COLOR.panel
	log.BackgroundTransparency = 0.45 -- a faint backing so lines read over the terrain
	log.BorderSizePixel = 0
	log.AnchorPoint = Vector2.new(0.5, 1)
	log.Position = UDim2.new(0.5, 0, 1, -230)
	log.Size = UDim2.fromOffset(560, 0)
	log.AutomaticSize = Enum.AutomaticSize.Y
	log.Parent = gui
	local list = Kit.list(log, 2)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	Kit.pad(log, Kit.SPACE.s, Kit.SPACE.xs)
	local logCorner = Instance.new("UICorner")
	logCorner.CornerRadius = UDim.new(0, Kit.CONTROL_RADIUS)
	logCorner.Parent = log
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -190)
	bar.Size = UDim2.fromOffset(560, 34)
	bar.BackgroundColor3 = Kit.COLOR.panel
	bar.BackgroundTransparency = Kit.COLOR.panelTransparency
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Kit.CONTROL_RADIUS)
	corner.Parent = bar
	local stroke = Instance.new("UIStroke")
	stroke.Color = Kit.COLOR.accent
	stroke.Transparency = 0.4
	stroke.Parent = bar
	local box = Instance.new("TextBox")
	box.Name = "Box"
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromScale(1, 1)
	box.ClearTextOnFocus = false
	box.FontFace = Kit.font(Enum.FontWeight.Regular)
	box.TextSize = 15
	box.TextColor3 = Kit.COLOR.text
	box.PlaceholderText = "/help for cheat commands"
	box.PlaceholderColor3 = Kit.COLOR.faint
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Text = ""
	box.Parent = bar
	Kit.pad(box, Kit.SPACE.m, 0, Kit.SPACE.m, 0)
	local suggest = Instance.new("Frame")
	suggest.Name = "Suggestions"
	suggest.AnchorPoint = Vector2.new(0, 1)
	suggest.Position = UDim2.new(0, 0, 0, -4)
	suggest.BackgroundColor3 = Kit.COLOR.panel
	suggest.BackgroundTransparency = Kit.COLOR.panelTransparency
	suggest.BorderSizePixel = 0
	suggest.Visible = false
	suggest.Parent = bar
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0, Kit.CONTROL_RADIUS)
	sc.Parent = suggest
	Kit.pad(suggest, 4)
	Kit.list(suggest, 0)
	local ui: UI = { gui = gui, bar = bar, box = box, suggest = suggest, log = log, logRoom = 1000, lines = {}, history = {}, historyAt = 1, lastGive = nil, submit = submit, defs = defs, suggestions = {}, sent = false }
	box:GetPropertyChangedSignal("Text"):Connect(function()
		-- Tab completes: Roblox types a tab character into the box
		if string.find(box.Text, "\t", 1, true) then
			local first = ui.suggestions[1]
			box.Text = if first then first.text else string.gsub(box.Text, "\t", "")
			box.CursorPosition = #box.Text + 1
			return
		end
		suggestionRows(ui)
	end)
	box.FocusLost:Connect(function(enter: boolean)
		-- some input paths report Return without enterPressed: a focus lost while
		-- Return is down counts too (Escape and clicking away don't send)
		local returnDown = UserInputService:IsKeyDown(Enum.KeyCode.Return) or UserInputService:IsKeyDown(Enum.KeyCode.KeypadEnter)
		if (enter or returnDown) and not ui.sent then
			send(ui, box.Text)
		end
		ui.sent = false
		CheatConsole.close(ui)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local k = input.KeyCode
		if box:IsFocused() then
			if k == Enum.KeyCode.Return or k == Enum.KeyCode.KeypadEnter then
				-- some input paths drop the TextBox's enterPressed: send here, once
				ui.sent = true
				local text = box.Text
				CheatConsole.close(ui)
				send(ui, text)
			elseif k == Enum.KeyCode.Up or k == Enum.KeyCode.Down then
				ui.historyAt = math.clamp(ui.historyAt + (if k == Enum.KeyCode.Up then -1 else 1), 1, #ui.history + 1)
				box.Text = ui.history[ui.historyAt] or ""
				box.CursorPosition = #box.Text + 1
			end
			return
		end
		if processed then
			return
		end
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if k == Enum.KeyCode.G and ctrl and shift then
			CheatConsole.repeatGive(ui)
		elseif k == Enum.KeyCode.Return then
			CheatConsole.open(ui)
		elseif k == Enum.KeyCode.Slash then
			task.defer(CheatConsole.open, ui, "/")
		end
	end)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	placeLog(ui, 230)
	return ui
end

-- Once a frame: old log lines fade out.
function CheatConsole.step(ui: UI)
	local now = os.clock()
	for i = #ui.lines, 1, -1 do
		local line = ui.lines[i]
		local age = now - line.at
		if age > CheatConsole.LOG_SECONDS + 1 and not ui.bar.Visible then
			line.label:Destroy()
			table.remove(ui.lines, i)
		else
			local fade = if ui.bar.Visible then 0 else math.clamp(age - CheatConsole.LOG_SECONDS, 0, 1)
			line.label.TextTransparency = fade
			line.label.TextStrokeTransparency = 0.6 + 0.4 * fade
		end
	end
	-- the newest lines that fit under the top HUD; older ones hide
	local used = 2 * Kit.SPACE.xs
	for i = #ui.lines, 1, -1 do
		local label = ui.lines[i].label
		used += label.AbsoluteSize.Y + 2
		label.Visible = used <= ui.logRoom
	end
	ui.log.Visible = #ui.lines > 0 -- no empty backing
end

return CheatConsole

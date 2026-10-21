--!strict
-- Lobby and results screens (C-70, guide 16.3), functional PLACEHOLDERS:
-- the server's lobby (src/roblox/Lobby) arrives as the Remotes folder's
-- "Lobby" attribute (JSON); changes go back through the "Lobby" remote.
-- Lobby: map, mode (FFA / Team), win rule (Command Ends / Annihilation),
-- faction (Order / Chaos), AI slots with Easy / Normal / Hard, Start.
-- Results: victory or defeat, the match's length, each player's end, and
-- back to the lobby. Hidden while the match runs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LobbyUI = {}

local BG = Color3.fromRGB(16, 18, 22)
local BTN = Color3.fromRGB(44, 50, 60)
local ON = Color3.fromRGB(70, 110, 160)
local WIN_NAMES = { COMMAND_ENDS = "Command Ends", ANNIHILATION = "Annihilation" }

export type UI = { gui: ScreenGui, panel: Frame, body: Frame, remote: RemoteEvent, last: string? }

local function label(parent: Instance, text: string, size: number, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 8)
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = text
	l.LayoutOrder = order
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, w: number, on: boolean?, click: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 28)
	b.BackgroundColor3 = if on then ON else BTN
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = #parent:GetChildren() -- after the row's label, in the order added
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	b.MouseButton1Click:Connect(click)
	return b
end

local function row(parent: Instance, name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 30)
	f.LayoutOrder = order
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 6)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromOffset(90, 28)
	t.Font = Enum.Font.Gotham
	t.TextSize = 13
	t.TextColor3 = Color3.fromRGB(200, 200, 200)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = name
	t.LayoutOrder = 0
	t.Parent = f
	return f
end

local function render(ui: UI, data: any)
	for _, c in ui.body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	local s = data.state
	local send = function(msg: any)
		ui.remote:FireServer(msg)
	end
	ui.panel.Visible = s.phase ~= "playing"
	if s.phase == "results" then
		local r = s.results or {}
		local title = if r.youWon then "VICTORY" elseif r.over then "DEFEAT" else "ELIMINATED"
		label(ui.body, title, 30, 1).TextColor3 = if r.youWon then Color3.fromRGB(120, 230, 120) else Color3.fromRGB(240, 100, 90)
		label(ui.body, string.format("Match length %d:%02d", math.floor((r.seconds or 0) / 60), math.floor(r.seconds or 0) % 60), 14, 2)
		for i, p in r.players or {} do
			local out = if p.outAt then string.format("out at %d:%02d", math.floor(p.outAt / 60), math.floor(p.outAt) % 60) else "standing"
			label(ui.body, `{p.name}  ·  {p.faction}  ·  ally team {p.allyTeam}  ·  {if p.won then "won" else out}  ·  {p.units} units`, 13, 2 + i)
		end
		local back = row(ui.body, "", 50)
		button(back, "Back to lobby", 160, true, function()
			send({ op = "lobby" })
		end)
		return
	end
	label(ui.body, "SKIRMISH", 24, 1)
	-- map
	local mapRow = row(ui.body, "Map", 2)
	for _, m in data.maps do
		button(mapRow, `{m.name} ({m.starts})`, 112, m.id == s.mapId, function()
			send({ op = "set", key = "mapId", value = m.id })
		end)
	end
	local modeRow = row(ui.body, "Mode", 3)
	for _, mode in { "FFA", "TEAM" } do
		button(modeRow, if mode == "FFA" then "Free for all" else "Teams", 112, s.mode == mode, function()
			send({ op = "set", key = "mode", value = mode })
		end)
	end
	local winRow = row(ui.body, "Win", 4)
	for _, w in { "COMMAND_ENDS", "ANNIHILATION" } do
		button(winRow, WIN_NAMES[w], 112, s.win == w, function()
			send({ op = "set", key = "win", value = w })
		end)
	end
	local facRow = row(ui.body, "Faction", 5)
	for _, f in { "order", "chaos" } do
		button(facRow, if f == "order" then "Order" else "Chaos", 112, s.faction == f, function()
			send({ op = "set", key = "faction", value = f })
		end)
	end
	local starts = 2
	for _, m in data.maps do
		if m.id == s.mapId then
			starts = m.starts
		end
	end
	for i, level in s.ai do
		local r = row(ui.body, `AI {i}`, 5 + i)
		for _, l in data.levels do
			button(r, string.upper(string.sub(l, 1, 1)) .. string.sub(l, 2), 80, l == level, function()
				send({ op = "ai", index = i, level = l })
			end)
		end
		if #s.ai > 1 then
			button(r, "Remove", 80, false, function()
				send({ op = "ai", index = i, level = nil })
			end)
		end
	end
	local actions = row(ui.body, "", 30)
	if #s.ai < starts - 1 then
		button(actions, "Add AI", 100, false, function()
			send({ op = "ai", index = #s.ai + 1, level = "normal" })
		end)
	end
	button(actions, "START", 140, true, function()
		send({ op = "start" })
	end)
	if s.mode == "TEAM" then
		label(ui.body, "Teams: you and every second AI against the others", 12, 40)
	end
end

function LobbyUI.new(remotes: Folder): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Lobby"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 420)
	panel.BackgroundColor3 = BG
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 16), UDim.new(0, 16), UDim.new(0, 12)
	pad.Parent = panel
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = body
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local ui: UI = { gui = gui, panel = panel, body = body, remote = remotes:WaitForChild("Lobby") :: RemoteEvent, last = nil }
	local function refresh()
		local json = remotes:GetAttribute("Lobby")
		if type(json) ~= "string" or json == ui.last then
			return
		end
		ui.last = json
		local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
		if ok and type(data) == "table" and data.state then
			render(ui, data)
		end
	end
	remotes:GetAttributeChangedSignal("Lobby"):Connect(refresh)
	refresh()
	return ui
end

return LobbyUI

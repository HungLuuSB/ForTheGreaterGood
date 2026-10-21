--!strict
-- Lobby and results screens (C-70; seats since C-77, guide 16.3),
-- functional PLACEHOLDERS: the server's lobby (src/roblox/Lobby) arrives as
-- the Remotes folder's "Lobby" attribute (JSON); changes go back through
-- the "Lobby" remote. Lobby: map (the named maps with their starts), mode
-- (FFA / Teams), win rule (Command Ends / Annihilation), then a row per
-- seat: who plays it (you, another human, an AI with Easy / Normal / Hard,
-- or open for a human to join), its faction and, in Teams, its ally team.
-- The host (seat 1) changes everything and starts; every human picks their
-- own faction. Results: victory or defeat for you, the match's length, and
-- a table per player (end, units built / lost / killed, resources
-- gathered / spent, damage dealt; the sim's Stats, S-63), and the replays (C-79): Save replay keeps your view of
-- the match for this server session, Watch replay plays it (or one saved
-- earlier) with the replay controls. Hidden while the match runs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local LobbyUI = {}

local BG = Color3.fromRGB(16, 18, 22)
local BTN = Color3.fromRGB(44, 50, 60)
local ON = Color3.fromRGB(70, 110, 160)
local WIN_NAMES = { COMMAND_ENDS = "Command Ends", ANNIHILATION = "Annihilation" }

export type UI = { gui: ScreenGui, panel: Frame, body: Frame, remote: RemoteEvent, last: string?, host: boolean, replay: RemoteEvent?, status: string, saved: { string }, data: any }

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

local function clock(seconds: number): string
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds) % 60)
end

local function cap(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

local function results(ui: UI, r: any, me: number, send: (any) -> ())
	local mine
	for _, p in r.players or {} do
		if p.user == me then
			mine = p
		end
	end
	local won = mine ~= nil and mine.won
	local title = if won then "VICTORY" elseif r.over then "DEFEAT" elseif mine and mine.outAt then "ELIMINATED" else "MATCH OVER"
	label(ui.body, title, 30, 1).TextColor3 = if won then Color3.fromRGB(120, 230, 120) else Color3.fromRGB(240, 100, 90)
	label(ui.body, `Match length {clock(r.seconds or 0)}`, 14, 2)
	label(ui.body, "Player · faction · team · end  |  units built / lost / killed  |  supply gathered / spent  |  power gathered / spent  |  damage dealt", 11, 3).TextColor3 = Color3.fromRGB(170, 170, 170)
	for i, p in r.players or {} do
		local out = if p.won then "won" elseif p.outAt then `out at {clock(p.outAt)}` else "standing"
		local st = p.stats
		local line = `{p.name}{if p.user == me then " (you)" else ""}  ·  {p.faction}  ·  {p.allyTeam}  ·  {out}`
		if st then
			local r0 = function(x: number?): string
				return tostring(math.floor((x or 0) + 0.5))
			end
			line ..= `  |  {st.unitsBuilt} / {st.unitsLost} / {st.unitsKilled}  |  {r0(st.supplyGathered)} / {r0(st.supplySpent)}  |  {r0(st.powerGathered)} / {r0(st.powerSpent)}  |  {r0(st.damageDealt)}`
		else
			line ..= `  |  {p.units} units`
		end
		label(ui.body, line, 12, 3 + i)
	end
	if r.replays and ui.replay then
		local replay = ui.replay :: RemoteEvent
		local rr = row(ui.body, "Replay", 40)
		button(rr, "Save replay", 120, false, function()
			replay:FireServer({ op = "save" })
		end)
		button(rr, "Watch replay", 120, true, function()
			replay:FireServer({ op = "watch" })
		end)
		for i, name in ui.saved do
			if i > 3 then
				break
			end
			button(rr, `▶ {name}`, 150, false, function()
				replay:FireServer({ op = "watch", index = i })
			end).TextTruncate = Enum.TextTruncate.AtEnd
		end
		if ui.status ~= "" then
			label(ui.body, ui.status, 12, 41).TextColor3 = Color3.fromRGB(180, 210, 180)
		end
	end
	local back = row(ui.body, "", 50)
	if ui.host then
		button(back, "Back to lobby", 160, true, function()
			send({ op = "lobby" })
		end)
	else
		label(back, "The host returns to the lobby", 12, 1)
	end
end

local function render(ui: UI, data: any)
	for _, c in ui.body:GetChildren() do
		if not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
	ui.data = data
	local s = data.state
	local send = function(msg: any)
		ui.remote:FireServer(msg)
	end
	local me = (Players.LocalPlayer :: Player).UserId
	local mySeat
	for i, sl in s.slots or {} do
		if sl.kind == "human" and sl.user == me then
			mySeat = i
		end
	end
	ui.host = mySeat == 1
	ui.panel.Visible = s.phase ~= "playing"
	if s.phase == "results" then
		results(ui, s.results or {}, me, send)
		return
	end
	label(ui.body, if ui.host then "SKIRMISH: you host" elseif mySeat then "SKIRMISH: waiting for the host" else "SKIRMISH: no free seat", 22, 1)
	local host = ui.host
	local mapRow = row(ui.body, "Map", 2)
	for _, m in data.maps do
		local b = button(mapRow, `{m.name} ({m.starts})`, 112, m.id == s.mapId, function()
			send({ op = "set", key = "mapId", value = m.id })
		end)
		b.Active = host
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
	local ffRow = row(ui.body, "Friendly fire", 4)
	for _, v in { true, false } do
		button(ffRow, if v then "On" else "Off", 112, s.friendlyFire ~= false and v or s.friendlyFire == false and not v, function()
			send({ op = "set", key = "friendlyFire", value = v })
		end)
	end
	local starts = 2
	for _, m in data.maps do
		if m.id == s.mapId then
			starts = m.starts
		end
	end
	for i, sl in s.slots or {} do
		local who = if sl.kind == "human" then (if sl.user == me then "You" else sl.name or "Player") elseif sl.kind == "open" then "Open" else "AI"
		local r = row(ui.body, `{i}. {who}`, 4 + i)
		-- faction: your own seat, or the host for AI and open seats
		if (sl.kind == "human" and sl.user == me) or (host and sl.kind ~= "human") then
			for _, f in { "order", "chaos" } do
				button(r, cap(f), 64, sl.faction == f, function()
					send({ op = "faction", index = i, value = f })
				end)
			end
		else
			label(r, cap(sl.faction), 12, 1).Size = UDim2.fromOffset(64, 28)
		end
		if host and i > 1 and sl.kind ~= "human" then
			for _, l in data.levels do
				button(r, cap(l), 60, sl.kind == "ai" and l == sl.level, function()
					send({ op = "slot", index = i, kind = "ai", level = l })
				end)
			end
			button(r, "Open", 54, sl.kind == "open", function()
				send({ op = "slot", index = i, kind = "open" })
			end)
			if #s.slots > 2 then
				button(r, "×", 28, false, function()
					send({ op = "slot", index = i, kind = nil })
				end)
			end
		elseif sl.kind == "ai" then
			label(r, cap(sl.level), 12, 2).Size = UDim2.fromOffset(60, 28)
		end
		if s.mode == "TEAM" then
			for _, a in { 1, 2 } do
				local b = button(r, `Team {a}`, 60, sl.ally == a, function()
					send({ op = "ally", index = i, value = a })
				end)
				b.Active = host
			end
		end
	end
	local actions = row(ui.body, "", 30)
	if host then
		if #s.slots < starts then
			button(actions, "Add AI", 90, false, function()
				send({ op = "slot", index = #s.slots + 1, kind = "ai", level = "normal" })
			end)
			button(actions, "Add seat", 90, false, function()
				send({ op = "slot", index = #s.slots + 1, kind = "open" })
			end)
		end
		button(actions, "START", 140, true, function()
			send({ op = "start" })
		end)
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
	panel.Size = UDim2.fromOffset(880, 460)
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
	local ui: UI = { gui = gui, panel = panel, body = body, remote = remotes:WaitForChild("Lobby") :: RemoteEvent, last = nil, host = false, replay = remotes:WaitForChild("Replay", 5) :: RemoteEvent?, status = "", saved = {}, data = nil }
	local replayRemote = ui.replay
	if replayRemote then
		replayRemote.OnClientEvent:Connect(function(msg: any)
			if type(msg) ~= "table" then
				return
			end
			if msg.op == "saved" then
				ui.status = string.format("Saved \"%s\" (%.1f KB) for this server session%s", msg.name, (msg.bytes or 0) / 1024, if msg.datastore == "saved" then "; also in the DataStore" elseif msg.datastore then "; DataStore: " .. string.sub(msg.datastore, 1, 80) else "")
				replayRemote:FireServer({ op = "list" })
			elseif msg.op == "list" and type(msg.names) == "table" then
				ui.saved = msg.names
			else
				return
			end
			if ui.data then
				render(ui, ui.data)
			end
		end)
	end
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

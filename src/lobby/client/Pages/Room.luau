--!strict
-- The battle room (L-3, BAR's room layout): teams (or players) and
-- spectators on the left, room chat in the middle, the map and the rules on
-- the right with Leave / Ready / Start. The host's controls show only for
-- the host; the server checks every request anyway. A click on a seat opens
-- its editor: your own faction, team and color; the host's AI (level,
-- faction, team, color, remove) and kick.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Config = require("../../shared/Config")
local MapImage = require("../MapImage")
local MatchConfig = require("../../shared/MatchConfig")
local Net = require("../Net")
local Ui = require("../Ui")
local Browser = require("./Browser")

local Kit = Ui.Kit
local me = Players.LocalPlayer.UserId

local Room = {}

local function options(list: { string }): { { string } }
	local out = {}
	for _, v in list do
		table.insert(out, { v, Ui.label2(v) })
	end
	return out
end

local function memberOf(room: any, user: number?): any?
	for _, m in room.members do
		if m.user == user then
			return m
		end
	end
	return nil
end

local function slotOf(room: any, user: number): number?
	for i, s in room.slots do
		if s.kind == "human" and s.user == user then
			return i
		end
	end
	return nil
end

-- Start colors as the match will seat them (MatchConfig's order).
local function startColors(room: any): { [number]: Color3 }
	local ok, c = pcall(MatchConfig.build, room, "preview", 0, 0, { placeId = 0, jobId = "" })
	local out = {}
	if ok then
		for _, p in c.players do
			out[p.start] = Ui.color(p.color)
		end
	end
	return out
end

-- The seat editor (a small modal).
local function editSeat(gui: Instance, index: number)
	local view = Net.view
	local room = view and view.room
	if room == nil or room.phase ~= "setup" then
		return
	end
	local s = room.slots[index]
	if s == nil then
		return
	end
	local mine = s.kind == "human" and s.user == me
	local host = room.host == me
	if not mine and not host then
		return
	end
	local m = memberOf(room, s.user)
	local title = if s.kind == "ai" then "AI player" elseif mine then "Your seat" else (if m then m.name else "Player")
	local p, close = Browser.dialog(gui, title, Vector2.new(460, if s.kind == "ai" then 400 else 330))
	Kit.list(p.content, Kit.SPACE.s)
	local function send(fields: any)
		local msg = table.clone(fields)
		if mine then
			msg.op = "mine"
		else
			msg.op = "ai"
			msg.index = index
		end
		Net.send(msg)
	end
	if mine or s.kind == "ai" then
		Kit.segmented(Kit.row(p.content, "Faction", 1), options(Config.FACTIONS), s.faction, function(v)
			send({ faction = v })
		end, 90)
		if room.settings.mode == "TEAM" then
			local teams = {}
			for t = 1, Config.MAX_ALLY_TEAMS do
				table.insert(teams, { tostring(t), `Team {t}` })
			end
			Kit.segmented(Kit.row(p.content, "Team", 2), teams, tostring(s.team), function(v)
				send({ team = tonumber(v) })
			end, 62)
		end
		if s.kind == "ai" then
			Kit.segmented(Kit.row(p.content, "Difficulty", 3), options(Config.LEVELS), s.level, function(v)
				send({ level = v })
			end, 80)
		end
		local colorRow = Kit.row(p.content, "Color", 4, 64)
		colorRow.Size = UDim2.new(0.7, 0, 1, 0)
		colorRow.Position = UDim2.fromScale(0.3, 0)
		local wrap = Ui.frame(colorRow, "Colors", UDim2.fromOffset(6 * 30, 58))
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(24, 24)
		gl.CellPadding = UDim2.fromOffset(6, 6)
		gl.Parent = wrap
		local taken: { [number]: boolean } = {}
		for j, other in room.slots do
			if j ~= index then
				taken[other.color] = true
			end
		end
		for c = 1, #Config.COLORS do
			local b = Instance.new("TextButton")
			b.Text = if taken[c] then "×" else ""
			b.TextColor3 = Color3.new(0, 0, 0)
			b.TextSize = 16
			b.BackgroundColor3 = Ui.color(c)
			b.BackgroundTransparency = if taken[c] then 0.7 else 0
			b.LayoutOrder = c
			b.AutoButtonColor = not taken[c]
			b.Parent = wrap
			Ui.corner(b, 4)
			if c == s.color then
				Ui.stroke(b, 0, Color3.new(1, 1, 1))
			end
			b.MouseButton1Click:Connect(function()
				if not taken[c] then
					send({ color = c })
					close()
				end
			end)
		end
	end
	local buttons = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 34))
	buttons.LayoutOrder = 9
	local bl = Kit.list(buttons, Kit.SPACE.s, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	if s.kind == "ai" and host then
		Ui.button(buttons, "Remove AI", "stop", function()
			Net.send({ op = "removeAi", index = index })
			close()
		end, 120)
	elseif mine then
		Ui.button(buttons, "Spectate", "ghost", function()
			Net.send({ op = "spectate" })
			close()
		end, 110)
	elseif host and s.user then
		Ui.button(buttons, "Kick", "stop", function()
			Net.send({ op = "kick", user = s.user })
			close()
		end, 100)
	end
	Ui.button(buttons, "Done", "primary", close, 100)
end

-- A confirmation for the host's forced start.
local function confirmForce(gui: Instance, waiting: { string })
	local p, close = Browser.dialog(gui, "Start without everyone ready?", Vector2.new(480, 210))
	Kit.list(p.content, Kit.SPACE.m)
	local t = Kit.text(p.content, `Not ready: {table.concat(waiting, ", ")}. They'll be sent into the match anyway.`, "label")
	t.TextWrapped = true
	t.Size = UDim2.new(1, 0, 0, 44)
	t.LayoutOrder = 1
	local buttons = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 34))
	buttons.LayoutOrder = 2
	local bl = Kit.list(buttons, Kit.SPACE.s, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	Ui.button(buttons, "Cancel", "ghost", close, 110)
	Ui.button(buttons, "Force start", "primary", function()
		Net.send({ op = "start", force = true })
		close()
	end, 140)
end

function Room.new(frame: Frame, _router: any): any
	local gui = frame:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui

	-- left: header, notice, seats
	local left = Ui.card(frame, "Seats", UDim2.new(0.4, -Kit.SPACE.m, 1, 0), nil, 0.12)
	Kit.pad(left, Kit.SPACE.xl, Kit.SPACE.l, Kit.SPACE.xl, Kit.SPACE.l)
	local name = Kit.text(left, "", "title")
	name.TextSize = 30
	name.Size = UDim2.new(1, 0, 0, 40)
	local sub = Kit.text(left, "", "small", Kit.COLOR.dim)
	sub.Position = UDim2.fromOffset(0, 40)
	sub.RichText = true
	local notice = Ui.card(left, "Notice", UDim2.new(1, 0, 0, 0), UDim2.fromOffset(0, 70), 0.3)
	notice.BackgroundColor3 = Color3.fromRGB(70, 30, 26)
	notice.AutomaticSize = Enum.AutomaticSize.Y
	Kit.pad(notice, Kit.SPACE.m, Kit.SPACE.s)
	local noticeText = Kit.text(notice, "", "small", Kit.COLOR.text)
	noticeText.TextWrapped = true
	noticeText.AutomaticSize = Enum.AutomaticSize.Y
	noticeText.Size = UDim2.new(1, 0, 0, 0)
	local seatsHolder = Ui.frame(left, "List", UDim2.new(1, 0, 1, -76), UDim2.fromOffset(0, 76))
	local seats = Kit.scroll(seatsHolder)
	Kit.list(seats, Kit.SPACE.s)

	-- middle: chat
	local chat = Ui.card(frame, "Chat", UDim2.new(0.3, -Kit.SPACE.m, 1, 0), UDim2.new(0.4, 0, 0, 0), 0.25)
	Kit.pad(chat, Kit.SPACE.m)
	local chatHead = Kit.text(chat, "ROOM CHAT", "small", Kit.COLOR.faint)
	chatHead.Size = UDim2.new(1, 0, 0, 20)
	local logHolder = Ui.frame(chat, "Log", UDim2.new(1, 0, 1, -64), UDim2.fromOffset(0, 24))
	local log = Kit.scroll(logHolder)
	local ll = Kit.list(log, 4)
	ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local input = Ui.input(chat, "Say something to the room", 100)
	input.Size = UDim2.new(1, 0, 0, 32)
	input.Position = UDim2.new(0, 0, 1, -32)

	-- right: map, rules, actions
	local rightCol = Ui.frame(frame, "Setup", UDim2.new(0.3, 0, 1, 0), UDim2.new(0.7, 0, 0, 0))
	local mapHolder = Ui.frame(rightCol, "MapHolder", UDim2.new(1, 0, 0.42, 0))
	local mapImage = MapImage.new(mapHolder)
	local rules = Ui.card(rightCol, "Rules", UDim2.new(1, 0, 0.58, -Kit.SPACE.m - 52), UDim2.new(0, 0, 0.42, Kit.SPACE.m), 0.12)
	Kit.pad(rules, Kit.SPACE.l, Kit.SPACE.m)
	Kit.list(rules, 2)
	local actions = Ui.frame(rightCol, "Actions", UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 1, -44))
	local al = Kit.list(actions, Kit.SPACE.s, true)
	al.HorizontalAlignment = Enum.HorizontalAlignment.Right

	-- chat wiring: the room's TextChatService channel
	local channel: TextChannel? = nil
	local channelConn: RBXScriptConnection? = nil
	local chatOrder = 0
	local function addLine(who: string?, text: string, color: Color3?)
		chatOrder += 1
		local row = Instance.new("TextLabel")
		row.BackgroundColor3 = Color3.fromRGB(60, 90, 110)
		row.BackgroundTransparency = 0.6
		row.BorderSizePixel = 0
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, -6, 0, 0)
		row.FontFace = Kit.font(Enum.FontWeight.Regular)
		row.TextSize = 14
		row.TextWrapped = true
		row.RichText = true
		row.TextColor3 = color or Kit.COLOR.text
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.LayoutOrder = chatOrder
		local esc = string.gsub(string.gsub(string.gsub(text, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
		row.Text = if who then `<font color="#EEBA5C">{who}</font>  {esc}` else esc
		row.Parent = log
		Ui.corner(row, 4)
		Kit.pad(row, Kit.SPACE.s, 5)
		local kids = log:GetChildren()
		if #kids > 120 then
			for _, k in kids do
				if k:IsA("TextLabel") then
					k:Destroy()
					break
				end
			end
		end
		task.defer(function()
			log.CanvasPosition = Vector2.new(0, log.AbsoluteCanvasSize.Y)
		end)
	end
	local function bindChannel(roomId: string?)
		if channelConn then
			channelConn:Disconnect()
			channelConn = nil
		end
		channel = nil
		Ui.clear(log)
		if roomId == nil then
			return
		end
		task.spawn(function()
			local folder = TextChatService:WaitForChild("LobbyRooms", 10)
			local c = folder and folder:WaitForChild(`Room_{roomId}`, 10)
			if c == nil or not c:IsA("TextChannel") then
				return
			end
			if Net.view == nil or Net.view.room == nil or Net.view.room.id ~= roomId then
				return
			end
			channel = c
			addLine(nil, `You joined {Net.view.room.name}. Room code {roomId}.`, Kit.COLOR.dim)
			channelConn = c.MessageReceived:Connect(function(msg: TextChatMessage)
				local who = if msg.TextSource then (Players:GetPlayerByUserId(msg.TextSource.UserId) or {} :: any).DisplayName else nil
				addLine(who or "?", msg.Text)
			end)
		end)
	end
	input.FocusLost:Connect(function(enter: boolean)
		if enter and input.Text ~= "" and channel then
			local text = input.Text
			input.Text = ""
			task.spawn(function()
				pcall(function()
					(channel :: TextChannel):SendAsync(text)
				end)
			end)
		end
	end)

	local boundRoom: string? = nil

	local function seatChip(parent: Instance, room: any, index: number?, member: any?, order: number)
		local s = if index then room.slots[index] else nil
		local chip = Instance.new("TextButton")
		chip.Name = "Seat"
		chip.AutoButtonColor = false
		chip.Text = ""
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, 32)
		chip.BackgroundColor3 = Kit.COLOR.raised
		chip.BackgroundTransparency = 0.94
		chip.BorderSizePixel = 0
		chip.LayoutOrder = order
		chip.Parent = parent
		Ui.corner(chip, 5)
		Ui.stroke(chip, if (s and s.user == me) or (member and member.user == me) then 0.4 else 0.88, if (s and s.user == me) or (member and member.user == me) then Kit.COLOR.accent else nil)
		Kit.pad(chip, Kit.SPACE.s, 0, Kit.SPACE.m, 0)
		local l = Kit.list(chip, 6, true)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		if s then
			Ui.swatch(chip, Ui.color(s.color), 12).LayoutOrder = 1
		end
		local who
		if s and s.kind == "ai" then
			who = `AI ({Ui.label2(s.level)})`
		else
			local m = member or memberOf(room, s and s.user)
			who = if m then m.name else "?"
		end
		Ui.label(chip, who, "label", nil, 2)
		if s then
			Ui.label(chip, Ui.label2(s.faction), "small", if s.faction == "order" then Color3.fromRGB(140, 180, 240) else Color3.fromRGB(236, 120, 100), 3)
		end
		local m = member or (s and s.user and memberOf(room, s.user))
		if m then
			if m.user == room.host then
				Ui.label(chip, "HOST", "small", Kit.COLOR.accent, 4)
			end
			if m.away then
				Ui.label(chip, "in match", "small", Kit.COLOR.accent, 5)
			elseif s and room.phase == "setup" then
				local dot = Ui.swatch(chip, if m.ready or m.user == room.host then Kit.COLOR.on else Kit.COLOR.off, 8)
				Ui.corner(dot, 4)
				dot.LayoutOrder = 6
			end
		end
		if index then
			chip.MouseButton1Click:Connect(function()
				editSeat(gui, index)
			end)
		elseif member and room.host == me and member.user ~= me and room.phase == "setup" then
			chip.MouseButton1Click:Connect(function()
				local p, close = Browser.dialog(gui, member.name, Vector2.new(380, 160))
				local b = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 34))
				local bl = Kit.list(b, Kit.SPACE.s, true)
				bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
				Ui.button(b, "Kick", "stop", function()
					Net.send({ op = "kick", user = member.user })
					close()
				end, 100)
				Ui.button(b, "Close", "ghost", close, 100)
			end)
		end
		return chip
	end

	local function section(parent: Instance, title: string, countText: string, order: number, buttons: { { any } })
		local head = Ui.frame(parent, "Head", UDim2.new(1, 0, 0, 34))
		head.LayoutOrder = order
		local hl = Kit.list(head, Kit.SPACE.s, true)
		hl.VerticalAlignment = Enum.VerticalAlignment.Center
		local t = Ui.label(head, title, "section", nil, 1)
		t.TextSize = 20
		Ui.label(head, countText, "label", Kit.COLOR.dim, 2)
		for i, b in buttons do
			local btn = Ui.button(head, b[1], nil, b[2], b[3] or 80, 24)
			btn.TextSize = 12
			btn.LayoutOrder = 2 + i
		end
		local flow = Ui.frame(parent, "Flow", UDim2.new(1, 0, 0, 0))
		flow.AutomaticSize = Enum.AutomaticSize.Y
		flow.LayoutOrder = order + 1
		local fl = Kit.list(flow, 6, true)
		fl.Wraps = true
		fl.VerticalAlignment = Enum.VerticalAlignment.Top
		return flow
	end

	local function render(v: any)
		local room = v.room
		if room == nil then
			if boundRoom then
				boundRoom = nil
				bindChannel(nil)
			end
			return
		end
		if boundRoom ~= room.id then
			boundRoom = room.id
			bindChannel(room.id)
		end
		local host = room.host == me
		local setup = room.phase == "setup"
		local mySlot = slotOf(room, me)
		local hostMember = memberOf(room, room.host)
		name.Text = room.name
		sub.Text = `Hosted by {if hostMember then hostMember.name else "?"}   ·   Code <b>{room.id}</b>   ·   {Ui.label2(room.privacy)}{if room.locked then " · password" else ""}   ·   {#room.members}/{room.maxPlayers}`
		local noticeText2 = room.notice
		if room.phase == "match" then
			noticeText2 = "A match is in progress."
		end
		notice.Visible = noticeText2 ~= nil
		noticeText.Text = noticeText2 or ""
		notice.BackgroundColor3 = if room.phase == "match" then Color3.fromRGB(40, 60, 80) else Color3.fromRGB(70, 30, 26)
		seatsHolder.Position = UDim2.fromOffset(0, if notice.Visible then 76 + notice.AbsoluteSize.Y + 8 else 70)

		-- seats
		Ui.clear(seats)
		local order = 0
		local function addAiButton(team: number?): { any }
			return { "Add AI", function()
				Net.send({ op = "addAi" })
				if team then
					task.delay(0.3, function()
						local r = Net.view and Net.view.room
						if r then
							Net.send({ op = "ai", index = #r.slots, team = team })
						end
					end)
				end
			end }
		end
		if room.settings.mode == "TEAM" then
			local used: { [number]: { number } } = {}
			local top = 2
			for i, s in room.slots do
				used[s.team] = used[s.team] or {}
				table.insert(used[s.team], i)
				top = math.max(top, s.team)
			end
			top = math.min(Config.MAX_ALLY_TEAMS, top + (if top < Config.MAX_ALLY_TEAMS then 1 else 0))
			for team = 1, top do
				local list = used[team] or {}
				local buttons = {}
				if setup and host then
					table.insert(buttons, addAiButton(team))
				end
				if setup and (mySlot == nil or room.slots[mySlot].team ~= team) then
					table.insert(buttons, { "Join", function()
						if mySlot then
							Net.send({ op = "mine", team = team })
						else
							Net.send({ op = "play" })
							task.delay(0.3, function()
								Net.send({ op = "mine", team = team })
							end)
						end
					end, 60 })
				end
				order += 2
				local flow = section(seats, `Team {team}`, `({#list})`, order, buttons)
				for k, i in list do
					seatChip(flow, room, i, nil, k)
				end
			end
		else
			local buttons = {}
			if setup and host then
				table.insert(buttons, addAiButton(nil))
			end
			if setup and mySlot == nil then
				table.insert(buttons, { "Play", function()
					Net.send({ op = "play" })
				end, 60 })
			end
			order += 2
			local flow = section(seats, "Players", `({#room.slots}/{room.starts})`, order, buttons)
			for i in room.slots do
				seatChip(flow, room, i, nil, i)
			end
		end
		local specs = {}
		for _, m in room.members do
			if slotOf(room, m.user) == nil then
				table.insert(specs, m)
			end
		end
		local specButtons = {}
		if setup and mySlot then
			table.insert(specButtons, { "Spectate", function()
				Net.send({ op = "spectate" })
			end, 90 })
		end
		order += 2
		local flow = section(seats, "Spectators", `({#specs})`, order, specButtons)
		for k, m in specs do
			seatChip(flow, room, nil, m, k)
		end

		-- map
		local map = Net.map(room.settings.mapId)
		mapImage.set(map, startColors(room))

		-- rules
		Ui.clear(rules)
		local canEdit = host and setup
		local function rule(label: string, order2: number, editor: (Frame) -> (), value: string)
			local row = Kit.row(rules, label, order2, 34)
			if canEdit then
				editor(row)
			else
				Ui.label(row, value, "label", Kit.COLOR.text)
			end
		end
		local mapOptions = {}
		for _, m in Net.maps or {} do
			table.insert(mapOptions, { m.id, `{m.name} ({m.starts})` })
		end
		rule("Map", 1, function(row)
			Kit.dropdown(row, mapOptions, room.settings.mapId, function(id)
				Net.send({ op = "set", key = "mapId", value = id })
			end, 200)
		end, room.mapName)
		rule("Mode", 2, function(row)
			Kit.segmented(row, options(Config.MODES), room.settings.mode, function(x)
				Net.send({ op = "set", key = "mode", value = x })
			end, 100)
		end, Ui.label2(room.settings.mode))
		rule("Win rule", 3, function(row)
			Kit.dropdown(row, options(Config.WINS), room.settings.win, function(x)
				Net.send({ op = "set", key = "win", value = x })
			end, 200)
		end, Ui.label2(room.settings.win))
		rule("Friendly fire", 4, function(row)
			Kit.toggle(row, room.settings.friendlyFire, function(on)
				Net.send({ op = "set", key = "friendlyFire", value = on })
			end)
		end, if room.settings.friendlyFire then "On" else "Off")
		rule("Cheats", 5, function(row)
			Kit.toggle(row, room.settings.cheats, function(on)
				Net.send({ op = "set", key = "cheats", value = on })
			end)
		end, if room.settings.cheats then "On (not counted)" else "Off")
		if mySlot then
			local s = room.slots[mySlot]
			local row = Kit.row(rules, "You", 6, 34)
			Ui.swatch(row, Ui.color(s.color), 14).LayoutOrder = 1
			Ui.label(row, `{Ui.label2(s.faction)}{if room.settings.mode == "TEAM" then ` · Team {s.team}` else ""}`, "label", nil, 2)
			if setup then
				Ui.button(row, "Change", "ghost", function()
					editSeat(gui, mySlot)
				end, 80, 26).LayoutOrder = 3
			end
		end

		-- actions
		Ui.clear(actions)
		local myMember = memberOf(room, me)
		Ui.button(actions, "Leave", "stop", function()
			Net.send({ op = "leave" })
		end, 110, 40).LayoutOrder = 1
		if room.phase == "match" then
			if myMember and not myMember.away then
				Ui.button(actions, "Rejoin match", "go", function()
					Net.send({ op = "rejoin" })
				end, 170, 40).LayoutOrder = 2
			end
		elseif host then
			local waiting = room.notReady or {}
			local start = Ui.button(actions, if #waiting == 0 then "Start" else "Start (force)", if #waiting == 0 then "go" else "primary", function()
				if #waiting == 0 then
					Net.send({ op = "start" })
				else
					confirmForce(gui, waiting)
				end
			end, 170, 40)
			start.LayoutOrder = 3
			if not setup then
				start.Text = "Starting..."
				Ui.enable(start, false)
			end
		elseif mySlot and myMember then
			local ready = myMember.ready
			Ui.button(actions, if ready then "Ready" else "Ready up", if ready then "go" else "primary", function()
				Net.send({ op = "ready", value = not ready })
			end, 170, 40).LayoutOrder = 3
		end
	end

	return {
		update = render,
	}
end

return Room

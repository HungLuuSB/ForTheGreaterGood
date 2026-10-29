--!strict
-- The battle room (L-3, BAR's room layout): teams (or players) and
-- spectators on the left, room chat in the middle, the map and the rules on
-- the right with Leave / Invite / Ready / Start. The rules are BAR's rows (a
-- darker label cell joined to a value cell; real switches for friendly
-- fire and cheats) under a big map preview; while a match runs the header
-- says how long. Invite sends a Roblox game invite carrying the room code
-- (L-17). The host's controls show only for the host; the server checks
-- every request anyway. A click on a seat opens its editor: your own
-- faction and team; the host's AI (level, faction, team, remove) and kick.
-- Colours are automatic (S-172), as the match shows them to you: you and
-- your allies cold, enemies warm (MatchConfig.colors). In Teams the map
-- shows each team's spawn box; the host drags them (F26, BoxEditor).

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TextChatService = game:GetService("TextChatService")

local Config = require("../../shared/Config")
local Listing = require("../../shared/Listing")
local MatchConfig = require("../../shared/MatchConfig")
local SpawnBoxes = require("../../shared/SpawnBoxes")
local BoxEditor = require("../BoxEditor")
local Emblem = require("../Emblem")
local MapImage = require("../MapImage")
local MapPicker = require("../MapPicker")
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

-- How many teams the room's map allows (its starts, at most
-- MAX_ALLY_TEAMS): starts are picked in the match's pre-game (S-171), so a
-- map's starts cap the sides, not the players.
local function sidesFor(room: any): number
	local map = Net.map(room.settings.mapId)
	return math.min(Config.MAX_ALLY_TEAMS, if map then map.starts else Config.MAX_ALLY_TEAMS)
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
	local p, close = Browser.dialog(gui, title, Vector2.new(460, if s.kind == "ai" then 268 else 248))
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
		Emblem.picker(Kit.row(p.content, "Faction", 1, 94), Config.FACTIONS, s.faction, function(v)
			send({ faction = v })
		end)
		if mine then
			-- F35: the match's pre-game has the last word on factions
			local note = Kit.text(p.content, "A first choice: you can change it in the match before it starts.", "small", Kit.COLOR.dim)
			note.Size = UDim2.new(1, 0, 0, 16)
			note.LayoutOrder = 1
		end
		if room.settings.mode == "TEAM" then
			local teams = {}
			local sides = sidesFor(room)
			for t = 1, sides do
				table.insert(teams, { tostring(t), if sides > 4 then tostring(t) else `Team {t}` })
			end
			Kit.segmented(Kit.row(p.content, "Team", 2), teams, tostring(s.team), function(v)
				send({ team = tonumber(v) })
			end, if sides > 4 then 30 else 62)
		end
		if s.kind == "ai" then
			local levels = {}
			for _, v in Config.LEVELS do
				table.insert(levels, { v, (Config.LEVEL_SHORT :: any)[v] or Ui.label2(v) })
			end
			Kit.segmented(Kit.row(p.content, "Difficulty", 3), levels, s.level, function(v)
				send({ level = v })
			end, 78)
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

-- A Roblox game invite to this room: friends who accept arrive with
-- "room=<code>" as launch data and the server takes them to the room.
local function invite(room: any)
	local player = Players.LocalPlayer
	task.spawn(function()
		local okCan, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if not okCan or not can then
			if Net.view and Net.view.studio then
				Net.toast(`Invites need the published game. To test here: StandInLaunch = "{Listing.launchData(room.id)}" on ServerScriptService.Lobby, then a new player.`)
			else
				Net.toast(`You can't send invites right now. Share the room code {room.id} instead.`, "error")
			end
			return
		end
		local ok, err = pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.LaunchData = Listing.launchData(room.id)
			options.PromptMessage = `Join my room "{room.name}" in For The Greater Good`
			SocialService:PromptGameInvite(player, options)
		end)
		if not ok then
			warn(`[Lobby] invite: {err}`)
			Net.toast(`The invite didn't open. Share the room code {room.id} instead.`, "error")
		end
	end)
end

function Room.new(frame: Frame, _router: any): any
	local gui = frame:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui

	-- left: header, notice, seats
	local left = Ui.card(frame, "Seats", UDim2.new(0.37, -Kit.SPACE.m, 1, 0), nil, 0.12)
	Kit.pad(left, Kit.SPACE.xl, Kit.SPACE.l, Kit.SPACE.xl, Kit.SPACE.l)
	local name = Kit.text(left, "", "title")
	name.TextSize = 30
	name.Size = UDim2.new(1, 0, 0, 40)
	local sub = Kit.text(left, "", "small", Kit.COLOR.dim)
	sub.Position = UDim2.fromOffset(0, 40)
	sub.RichText = true
	-- BAR's "Running for 3 minutes", at the right of the title
	local status = Kit.text(left, "", "label", Kit.COLOR.accent)
	status.AnchorPoint = Vector2.new(1, 0)
	status.Position = UDim2.fromScale(1, 0)
	status.Size = UDim2.new(0.5, 0, 0, 40)
	status.TextXAlignment = Enum.TextXAlignment.Right
	name.TextTruncate = Enum.TextTruncate.AtEnd
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
	local chat = Ui.card(frame, "Chat", UDim2.new(0.27, -Kit.SPACE.m, 1, 0), UDim2.new(0.37, 0, 0, 0), 0.25)
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

	-- right: the map as big as the column allows, the rules under it, actions
	local RULE_H, RULE_GAP = 30, 3
	local rulesH = 6 * RULE_H + 5 * RULE_GAP + Kit.SPACE.s * 2
	local rightCol = Ui.frame(frame, "Setup", UDim2.new(0.36, 0, 1, 0), UDim2.new(0.64, 0, 0, 0))
	local mapHolder = Ui.frame(rightCol, "MapHolder", UDim2.new(1, 0, 1, -(rulesH + 44 + Kit.SPACE.s * 2)))
	local mapImage = MapImage.new(mapHolder, false) -- no starts: players pick theirs in the match (G12)
	local boxEditor = BoxEditor.new(mapImage.image, function(team: number, box: { number })
		Net.send({ op = "box", team = team, box = box })
	end)
	-- at the column's corner, beside the map (not over a box to drag)
	local resetBoxes = Ui.button(mapHolder, "Reset boxes", "ghost", function()
		Net.send({ op = "resetBoxes" })
	end, 100, 26)
	resetBoxes.TextSize = 12
	resetBoxes.AnchorPoint = Vector2.new(0, 1)
	resetBoxes.Position = UDim2.new(0, 0, 1, 0)
	resetBoxes.ZIndex = 9
	resetBoxes.Visible = false
	local rules = Ui.card(rightCol, "Rules", UDim2.new(1, 0, 0, rulesH), UDim2.new(0, 0, 1, -(rulesH + 44 + Kit.SPACE.s)), 0.12)
	Kit.pad(rules, Kit.SPACE.s, Kit.SPACE.s)
	Kit.list(rules, RULE_GAP)
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
	local currentRoom: any = nil
	local function paintStatus()
		local room = currentRoom
		if room == nil then
			status.Text = ""
		elseif room.phase == "match" then
			status.Text = if room.startedAt then `In match · running for {Ui.minutes(room.startedAt)}` else "In match"
		elseif room.phase == "starting" then
			status.Text = "Starting..."
		else
			status.Text = ""
		end
		-- the title takes the width the status leaves
		name.Size = UDim2.new(1, -(if status.Text == "" then 0 else status.TextBounds.X + Kit.SPACE.l), 0, 40)
	end
	task.spawn(function()
		while true do
			task.wait(15)
			paintStatus()
		end
	end)

	local colors: { [number]: any } = {} -- by slot index, from your view
	local roles: { [number]: string } = {} -- AI team roles by slot index (S-187)
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
			Ui.swatch(chip, Ui.rgb(colors[index :: number]), 12).LayoutOrder = 1
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
			-- the faction's emblem; its name until the emblems are uploaded
			local emblem = Emblem.label(chip, s.faction, 16)
			if emblem then
				emblem.LayoutOrder = 3
			else
				Ui.label(chip, Ui.label2(s.faction), "small", if s.faction == "order" then Color3.fromRGB(140, 180, 240) else Color3.fromRGB(236, 120, 100), 3)
			end
			local role = index and roles[index]
			if role then
				-- two or more AIs on a side share the work (the sim picks the same)
				local badge = Ui.label(chip, string.upper((Config.AI_ROLE_NAMES :: any)[role] or role), "small", Kit.COLOR.dim, 4)
				badge.Name = "Role"
			end
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
		colors = MatchConfig.colors(room, me)
		roles = MatchConfig.aiRoles(room)
		local hostMember = memberOf(room, room.host)
		local aiCount = 0 -- the cap counts them too (G11)
		for _, s in room.slots do
			if s.kind == "ai" then
				aiCount += 1
			end
		end
		name.Text = room.name
		sub.Text = `Hosted by {if hostMember then hostMember.name else "?"}   ·   Code <b>{room.id}</b>   ·   {Ui.label2(room.privacy)}{if room.locked then " · password" else ""}   ·   {#room.members + aiCount}/{room.maxPlayers}`
		currentRoom = room
		paintStatus()
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
				Net.send({ op = "addAi", team = team })
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
			local sides = sidesFor(room)
			top = math.min(sides, top + (if top < sides then 1 else 0))
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
							Net.send({ op = "play", team = team })
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
		mapImage.set(map)

		-- spawn boxes (Teams): each team's, in the colour of its first seat as
		-- you see it (yours for your own team)
		local shownBoxes: { BoxEditor.Team } = {}
		local teamMode = room.settings.mode == "TEAM"
		if teamMode then
			local teams = SpawnBoxes.teams(room.slots)
			local boxes = SpawnBoxes.forTeams(map and map.geo, teams, room.settings.boxes)
			for _, team in teams do
				local seatOf: number? = if mySlot and room.slots[mySlot].team == team then mySlot else nil
				for i, s in room.slots do
					if seatOf == nil and s.team == team then
						seatOf = i
					end
				end
				if boxes[team] and seatOf then
					table.insert(shownBoxes, { team = team, box = boxes[team], color = Ui.rgb(colors[seatOf]) })
				end
			end
		end
		boxEditor.set(shownBoxes, host and setup and teamMode)
		resetBoxes.Visible = host and setup and teamMode and SpawnBoxes.touched(SpawnBoxes.teams(room.slots), room.settings.boxes)

		-- rules: BAR's rows, editable for the host while the room is open
		Ui.clear(rules)
		local canEdit = host and setup
		local function choice(label: string, order2: number, opts: { { string } }, value: string, shown: string, key: string)
			local cell = Ui.field(rules, label, order2, RULE_H)
			if canEdit then
				Ui.fieldDropdown(cell, opts, value, function(x)
					Net.send({ op = "set", key = key, value = x })
				end)
			else
				Ui.fieldText(cell, shown)
			end
		end
		-- the map: a panel with the list, a preview and the map's facts (G12);
		-- the host chooses there, everyone else can look
		local mapCell = Ui.field(rules, "Map", 1, RULE_H)
		Ui.fieldText(mapCell, room.mapName)
		Ui.chevron(mapCell)
		local openMaps = Instance.new("TextButton")
		openMaps.Name = "Maps"
		openMaps.BackgroundTransparency = 1
		openMaps.Text = ""
		openMaps.Size = UDim2.fromScale(1, 1)
		openMaps.ZIndex = 5
		openMaps.Parent = mapCell
		openMaps.MouseButton1Click:Connect(function()
			MapPicker.open(gui, room.settings.mapId, if canEdit then function(id: string)
				Net.send({ op = "set", key = "mapId", value = id })
			end else nil)
		end)
		choice("Mode", 2, options(Config.MODES), room.settings.mode, Ui.label2(room.settings.mode), "mode")
		choice("Win rule", 3, options(Config.WINS), room.settings.win, Ui.label2(room.settings.win), "win")
		Ui.fieldToggle(Ui.field(rules, "Friendly fire", 4, RULE_H), room.settings.friendlyFire, if canEdit then function(on)
			Net.send({ op = "set", key = "friendlyFire", value = on })
		end else nil)
		Ui.fieldToggle(Ui.field(rules, "Cheats", 5, RULE_H), room.settings.cheats, if canEdit then function(on)
			Net.send({ op = "set", key = "cheats", value = on })
		end else nil, "On (not counted)", "Off")
		if mySlot then
			local s = room.slots[mySlot]
			local cell = Ui.field(rules, "You", 6, RULE_H)
			local you = Ui.frame(cell, "You", UDim2.fromScale(1, 1))
			Kit.pad(you, Kit.SPACE.m, 0, Kit.SPACE.m, 0)
			local yl = Kit.list(you, Kit.SPACE.s, true)
			yl.VerticalAlignment = Enum.VerticalAlignment.Center
			Ui.swatch(you, Ui.rgb(colors[mySlot]), 14).LayoutOrder = 1
			local emblem = Emblem.label(you, s.faction, 16)
			if emblem then
				emblem.LayoutOrder = 2
			end
			Ui.label(you, `{Ui.label2(s.faction)}{if room.settings.mode == "TEAM" then ` · Team {s.team}` else ""}`, "label", nil, 3)
			if setup then
				Ui.chevron(cell)
				local hit = Instance.new("TextButton")
				hit.Name = "Change"
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Size = UDim2.fromScale(1, 1)
				hit.ZIndex = 5
				hit.Parent = cell
				hit.MouseButton1Click:Connect(function()
					editSeat(gui, mySlot)
				end)
			end
		else
			Ui.fieldText(Ui.field(rules, "You", 6, RULE_H), "Spectating", Kit.COLOR.dim)
		end

		-- actions
		Ui.clear(actions)
		local myMember = memberOf(room, me)
		Ui.button(actions, "Leave", "stop", function()
			Net.send({ op = "leave" })
		end, 110, 40).LayoutOrder = 1
		Ui.button(actions, "Invite", "ghost", function()
			invite(room)
		end, 110, 40).LayoutOrder = 2
		if room.phase == "match" then
			if myMember and not myMember.away then
				Ui.button(actions, "Rejoin match", "go", function()
					Net.send({ op = "rejoin" })
				end, 170, 40).LayoutOrder = 3
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

--!strict
-- Lobby and results screens (C-70; seats since C-77, guide 16.3; on the UI
-- kit since C-105): the server's lobby (src/roblox/Lobby) arrives as the
-- Remotes folder's "Lobby" attribute (JSON); changes go back through the
-- "Lobby" remote.
-- Lobby: a kit panel "Skirmish" with the map (dropdown; the named maps
-- with their starts), mode (Free for all / Teams), win rule (Command Ends /
-- Annihilation) and friendly fire, then a row per seat: who plays it (you,
-- another human, an AI with Easy / Normal / Hard, or open for a human to
-- join), its faction and, in Teams, its ally team. The host (seat 1)
-- changes everything and starts; every human picks their own faction.
-- Results: the statistics panel (UI/Statistics): victory or defeat, the
-- scoreboard, charts over match time, and the replays (C-79): Save replay
-- keeps your view of the match for this server session, Watch replay
-- plays it (or one saved earlier). Hidden while the match runs.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Kit = require("./Kit")
local Statistics = require("./Statistics")

local LobbyUI = {}

local WIN_NAMES = { COMMAND_ENDS = "Command Ends", ANNIHILATION = "Annihilation" }

export type UI = {
	gui: ScreenGui,
	panel: Kit.Panel,
	body: ScrollingFrame,
	stats: Statistics.UI,
	remote: RemoteEvent,
	last: string?,
	host: boolean,
	replay: RemoteEvent?,
	status: string,
	saved: { string },
	data: any,
}

local function cap(text: string): string
	return string.upper(string.sub(text, 1, 1)) .. string.sub(text, 2)
end

local function clear(ui: UI)
	for _, c in ui.body:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

local function results(ui: UI, r: any, send: (any) -> (), match: any?, returnAt: number?)
	local actions: Statistics.Actions = {
		back = if ui.host
			then function()
				send({ op = "lobby" })
			end
			else nil,
	}
	if match then
		-- a lobby match (C-173): anyone goes back now, or everyone after the countdown
		actions.back = function()
			send({ op = "return" })
		end
		actions.backLabel = "Return to lobby"
		actions.returnAt = returnAt
	end
	if r.replays and ui.replay then
		local replay = ui.replay :: RemoteEvent
		actions.save = function()
			replay:FireServer({ op = "save" })
		end
		actions.watch = function(index: number?)
			replay:FireServer({ op = "watch", index = index })
		end
	end
	Statistics.show(ui.stats, r, ui.last or "", actions, ui.status, ui.saved)
end

-- A seat row: its name on the left, its controls on the right.
local function seatRow(ui: UI, data: any, s: any, i: number, sl: any, me: number, send: (any) -> ())
	local host = ui.host
	local who = if sl.kind == "human" then (if sl.user == me then "You" else sl.name or "Player") elseif sl.kind == "open" then "Open seat" else "AI"
	local r = Kit.row(ui.body, `{i}.  {who}`, 10 + i)
	-- faction: your own seat, or the host for AI and open seats
	if (sl.kind == "human" and sl.user == me) or (host and sl.kind ~= "human") then
		Kit.segmented(r, { { "order", "Order" }, { "chaos", "Chaos" } }, sl.faction, function(f)
			send({ op = "faction", index = i, value = f })
		end, 70).frame.LayoutOrder = 1
	else
		local l = Kit.text(r, cap(sl.faction), "label", Kit.COLOR.dim)
		l.Size = UDim2.fromOffset(70, 28)
		l.LayoutOrder = 1
	end
	if host and i > 1 and sl.kind ~= "human" then
		local opts = {}
		for _, l in data.levels do
			table.insert(opts, { l, cap(l) })
		end
		table.insert(opts, { "open", "Open" })
		Kit.segmented(r, opts, if sl.kind == "ai" then sl.level else "open", function(v)
			if v == "open" then
				send({ op = "slot", index = i, kind = "open" })
			else
				send({ op = "slot", index = i, kind = "ai", level = v })
			end
		end, 62).frame.LayoutOrder = 2
		if #s.slots > 2 then
			Kit.button(r, "×", "ghost", function()
				send({ op = "slot", index = i, kind = nil })
			end, 28).LayoutOrder = 3
		end
	elseif sl.kind == "ai" then
		local l = Kit.text(r, cap(sl.level), "label", Kit.COLOR.dim)
		l.Size = UDim2.fromOffset(62, 28)
		l.LayoutOrder = 2
	end
	if s.mode == "TEAM" then
		if host then
			Kit.segmented(r, { { "1", "Team 1" }, { "2", "Team 2" } }, tostring(sl.ally), function(v)
				send({ op = "ally", index = i, value = tonumber(v) })
			end, 66).frame.LayoutOrder = 4
		else
			local l = Kit.text(r, `Team {sl.ally}`, "label", Kit.COLOR.dim)
			l.Size = UDim2.fromOffset(66, 28)
			l.LayoutOrder = 4
		end
	end
end

local function render(ui: UI, data: any)
	clear(ui)
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
	ui.panel.root.Visible = s.phase == "lobby"
	if s.phase == "results" then
		results(ui, s.results or {}, send, s.match, s.returnAt)
		return
	end
	Statistics.hide(ui.stats)
	if s.phase ~= "lobby" then
		return
	end
	local host = ui.host
	ui.panel.title.Text = if host then "Skirmish" elseif mySeat then "Skirmish · waiting for the host" else "Skirmish · no free seat"
	Kit.section(ui.body, "Match", 1)
	local mapRow = Kit.row(ui.body, "Map", 2)
	local maps, starts = {}, 2
	for _, m in data.maps do
		table.insert(maps, { m.id, `{m.name} ({m.starts})` })
		if m.id == s.mapId then
			starts = m.starts
		end
	end
	if host then
		Kit.dropdown(mapRow, maps, s.mapId, function(id)
			send({ op = "set", key = "mapId", value = id })
		end, 220)
	else
		for _, m in maps do
			if m[1] == s.mapId then
				Kit.text(mapRow, m[2], "label", Kit.COLOR.dim).Size = UDim2.fromOffset(220, 28)
			end
		end
	end
	Kit.segmented(Kit.row(ui.body, "Mode", 3), { { "FFA", "Free for all" }, { "TEAM", "Teams" } }, s.mode, function(v)
		send({ op = "set", key = "mode", value = v })
	end, 110)
	Kit.segmented(Kit.row(ui.body, "Win", 4), { { "COMMAND_ENDS", WIN_NAMES.COMMAND_ENDS }, { "ANNIHILATION", WIN_NAMES.ANNIHILATION } }, s.win, function(v)
		send({ op = "set", key = "win", value = v })
	end, 110)
	Kit.toggle(Kit.row(ui.body, "Friendly fire", 5), s.friendlyFire ~= false, function(on)
		send({ op = "set", key = "friendlyFire", value = on })
	end)
	-- cheat commands for allow-listed players (C-119); off by default
	Kit.toggle(Kit.row(ui.body, "Cheats", 6), s.cheats == true, function(on)
		send({ op = "set", key = "cheats", value = on })
	end)
	Kit.section(ui.body, "Seats", 10)
	for i, sl in s.slots or {} do
		seatRow(ui, data, s, i, sl, me, send)
	end
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.Size = UDim2.new(1, 0, 0, 48)
	actions.LayoutOrder = 40
	actions.Parent = ui.body
	local list = Kit.list(actions, Kit.SPACE.s, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	if host then
		if #s.slots < starts then
			Kit.button(actions, "Add AI", "ghost", function()
				send({ op = "slot", index = #s.slots + 1, kind = "ai", level = "normal" })
			end, 100).LayoutOrder = 1
			Kit.button(actions, "Add seat", "ghost", function()
				send({ op = "slot", index = #s.slots + 1, kind = "open" })
			end, 100).LayoutOrder = 2
		end
		Kit.button(actions, "Start", "primary", function()
			send({ op = "start" })
		end, 150).LayoutOrder = 3
	end
end

function LobbyUI.new(remotes: Folder): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "Lobby"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- modal: over every HUD screen and the debug overlay (C-106)
	gui.IgnoreGuiInset = true
	local panel = Kit.panel(gui, "Skirmish", Vector2.new(760, 520))
	panel.root.Visible = false
	local body = Kit.scroll(panel.content)
	local layout = Kit.list(body, Kit.SPACE.xs)
	-- the panel's height follows its rows (C-106)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		panel.setHeight(60 + layout.AbsoluteContentSize.Y + Kit.SPACE.l * 2)
	end)
	Kit.pad(body, 0, 0, Kit.SPACE.m, 0)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local me = (Players.LocalPlayer :: Player).UserId
	local ui: UI = {
		gui = gui,
		panel = panel,
		body = body,
		stats = Statistics.new(gui, me),
		remote = remotes:WaitForChild("Lobby") :: RemoteEvent,
		last = nil,
		host = false,
		replay = remotes:WaitForChild("Replay", 5) :: RemoteEvent?,
		status = "",
		saved = {},
		data = nil,
	}
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

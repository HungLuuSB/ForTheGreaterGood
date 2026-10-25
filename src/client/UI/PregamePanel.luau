--!strict
-- The pre-game screen (C-218, net.md 9b): a panel under the resource bar
-- while World.pregame is active. What to do (click inside your area, then
-- Ready), the countdown when it runs, the time until everyone counts as
-- ready, every player with its colour and state (picked, ready, AI), and
-- the Ready toggle. A pick the server didn't take (blocked ground, too
-- close to another start) says so. Spectators get the list only. A
-- placeholder look in the UI kit.

local Players = game:GetService("Players")

local Kit = require("./Kit")
local Pregame = require("../Core/Pregame")
local World = require("../Core/World")
local PregameMarks = require("../Render/PregameMarks")
local TeamColors = require("../Render/TeamColors")

local PregamePanel = {}

PregamePanel.WIDTH = 440
PregamePanel.REFUSE_AFTER = 1.0 -- seconds: a pick not shown by then was refused
PregamePanel.NOTE_FOR = 3 -- seconds a refusal stays up

export type Panel = {
	gui: ScreenGui,
	title: TextLabel,
	help: TextLabel,
	timer: TextLabel,
	list: Frame,
	rows: { [number]: { frame: Frame, swatch: Frame, name: TextLabel, state: TextLabel } },
	ready: TextButton,
	unready: TextButton,
	readyOn: boolean,
	pending: { x: number, z: number, at: number }?,
	note: string?,
	noteUntil: number,
	shown: string,
}

function PregamePanel.new(onReady: (boolean) -> ()): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggPregame"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	local root = Instance.new("Frame")
	root.Name = "Pregame"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 56) -- under the resource bar
	root.Size = UDim2.fromOffset(PregamePanel.WIDTH, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundColor3 = Kit.COLOR.panel
	root.BackgroundTransparency = Kit.COLOR.panelTransparency
	root.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Kit.RADIUS)
	corner.Parent = root
	Kit.pad(root, Kit.SPACE.l, Kit.SPACE.m, Kit.SPACE.l, Kit.SPACE.m)
	Kit.list(root, Kit.SPACE.s)
	root.Parent = gui

	local function line(text: string, kind: string, order: number, color: Color3?): TextLabel
		local t = Kit.text(root, text, kind, color)
		t.LayoutOrder = order
		t.Size = UDim2.new(1, 0, 0, 0)
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.TextWrapped = true
		t.TextXAlignment = Enum.TextXAlignment.Center
		return t
	end
	local title = line("CHOOSE YOUR START", "title", 1)
	local help = line("", "label", 2, Kit.COLOR.dim)
	local timer = line("", "small", 3, Kit.COLOR.faint)

	local list = Instance.new("Frame")
	list.Name = "Players"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.LayoutOrder = 4
	Kit.list(list, 2)
	list.Parent = root

	local bar = Instance.new("Frame")
	bar.Name = "Actions"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 34)
	bar.LayoutOrder = 5
	bar.Parent = root
	-- two buttons, one shown: the kit's filled buttons keep their fill
	local ready = Kit.button(bar, "READY", "go", function()
		onReady(true)
	end, 180)
	local unready = Kit.button(bar, "NOT READY", "stop", function()
		onReady(false)
	end, 180)
	for _, btn in { ready, unready } do
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.new(0.5, 0, 0, 2)
	end

	local self: Panel = {
		gui = gui,
		title = title,
		help = help,
		timer = timer,
		list = list,
		rows = {},
		ready = ready,
		unready = unready,
		readyOn = false,
		pending = nil,
		note = nil,
		noteUntil = 0,
		shown = "",
	}
	Kit.skin(gui)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return self
end

-- A START_POS went out for (x, z).
function PregamePanel.sent(ui: Panel, x: number, z: number, now: number)
	ui.pending = { x = x, z = z, at = now }
end

-- Says why a click didn't pick.
function PregamePanel.refuse(ui: Panel, text: string, now: number)
	ui.note, ui.noteUntil = text, now + PregamePanel.NOTE_FOR
end

local function row(ui: Panel, pid: number, order: number)
	local r = ui.rows[pid]
	if r then
		r.frame.LayoutOrder = order
		return r
	end
	local frame = Instance.new("Frame")
	frame.Name = `Player{pid}`
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 20)
	frame.LayoutOrder = order
	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.fromOffset(12, 12)
	swatch.Position = UDim2.fromOffset(0, 4)
	swatch.BorderSizePixel = 0
	swatch.Parent = frame
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = swatch
	local name = Kit.text(frame, "", "label")
	name.Position = UDim2.fromOffset(20, 0)
	name.Size = UDim2.new(0.62, -20, 1, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local state = Kit.text(frame, "", "small", Kit.COLOR.dim)
	state.AnchorPoint = Vector2.new(1, 0)
	state.Position = UDim2.new(1, 0, 0, 0)
	state.Size = UDim2.new(0.38, 0, 1, 0)
	state.TextXAlignment = Enum.TextXAlignment.Right
	frame.Parent = ui.list
	local made = { frame = frame, swatch = swatch, name = name, state = state }
	ui.rows[pid] = made
	return made
end

-- Once a frame.
function PregamePanel.step(ui: Panel, world: World.World, now: number)
	local pg = world.pregame
	ui.gui.Enabled = pg.active
	if not pg.active then
		ui.pending, ui.note = nil, nil
		return
	end
	local me = world.me.player
	local mine = pg.picks[me]
	-- a pick not shown in time was refused
	local pending = ui.pending
	if pending then
		if mine and mine.x and mine.z and math.abs(mine.x - pending.x) < 2 and math.abs(mine.z - pending.z) < 2 then
			ui.pending = nil
		elseif now - pending.at > PregamePanel.REFUSE_AFTER then
			ui.pending = nil
			PregamePanel.refuse(ui, "Can't start there: blocked ground, or too close to another start.", now)
		end
	end
	if ui.note and now > ui.noteUntil then
		ui.note = nil
	end
	ui.readyOn = me ~= 0 and Pregame.isReady(world, me)

	local timeLeft = math.ceil(Pregame.timeLeft(world))
	local key = `{pg.version}/{TeamColors.version}/{me}/{ui.note or ""}/{timeLeft}`
	if key == ui.shown then
		return
	end
	ui.shown = key
	if pg.countdown then
		ui.title.Text = `STARTING IN {pg.countdown}`
		ui.title.TextColor3 = Kit.COLOR.accent
	else
		ui.title.Text = if me == 0 then "PLAYERS ARE CHOOSING THEIR STARTS" else "CHOOSE YOUR START"
		ui.title.TextColor3 = Kit.COLOR.text
	end
	if ui.note then
		ui.help.Text = ui.note
		ui.help.TextColor3 = Kit.COLOR.off
	else
		ui.help.Text = if me == 0
			then "Each team starts inside its area."
			elseif mine and mine.x then "Click again inside your area to move your Commander. Ready when you're set."
			else "Click inside your area to place your Commander, then press Ready."
		ui.help.TextColor3 = Kit.COLOR.dim
	end
	ui.timer.Text = if pg.countdown then "Un-ready to stop the countdown." else `Starts on its own in {timeLeft // 60}:{string.format("%02d", timeLeft % 60)} (unplaced Commanders take a good spot)`
	ui.timer.Visible = me ~= 0 or pg.countdown == nil

	-- players by side, then ID
	local players = table.clone(TeamColors.players())
	table.sort(players, function(a, b)
		if a.allyTeam ~= b.allyTeam then
			return a.allyTeam < b.allyTeam
		end
		return a.id < b.id
	end)
	local seen = {}
	for i, p in players do
		seen[p.id] = true
		local r = row(ui, p.id, i)
		r.swatch.BackgroundColor3 = TeamColors.ofPlayer(p.id)
		r.name.Text = `{PregameMarks.nameOf(p.id)}{if p.id == me then " (you)" else ""}  ·  team {p.allyTeam}`
		local pick = pg.picks[p.id]
		local parts = {}
		if Pregame.isAI(world, p.id) then
			table.insert(parts, "AI")
		end
		table.insert(parts, if pick and pick.x then "placed" else "choosing")
		if Pregame.isReady(world, p.id) then
			table.insert(parts, "READY")
		end
		r.state.Text = table.concat(parts, " · ")
		r.state.TextColor3 = if Pregame.isReady(world, p.id) then Kit.COLOR.on else Kit.COLOR.dim
	end
	for pid, r in ui.rows do
		if not seen[pid] then
			r.frame:Destroy()
			ui.rows[pid] = nil
		end
	end
	ui.ready.Visible = me ~= 0 and not ui.readyOn
	ui.unready.Visible = me ~= 0 and ui.readyOn
end

return PregamePanel

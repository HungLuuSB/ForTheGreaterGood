--!strict
-- The pre-game's screen (C-218, net.md 9b), laid out after BAR's start
-- screen (the user's reference; text only, no panel over the map):
--   * right of centre, a big Ready / Not ready button; under it the host's
--     Start (lit once everyone is ready, PICK_CLOCK ALL_READY) and the pick
--     clock;
--   * low in the middle, above the bottom panels, the victory condition, then what to do ("Pick a
--     start spot within the green area, and click the Ready button.");
--     a pick the server didn't take says why instead;
--   * mid-screen, "Starting in n" while the countdown runs;
--   * at the bottom, next to the unit panel, "Pick your faction": each
--     faction's Commander portrait; a click switches (FACTION), only while
--     not ready.
-- Spectators get the texts only. Who picked and who is ready shows on the
-- map (Render/PregameMarks).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local Portrait = require("./Portrait")
local Pregame = require("../Core/Pregame")
local World = require("../Core/World")

local PregamePanel = {}

PregamePanel.REFUSE_AFTER = 1.0 -- seconds: a pick not shown by then was refused
PregamePanel.NOTE_FOR = 3 -- seconds a refusal stays up
PregamePanel.FACTIONS = { { "order", "Order" }, { "chaos", "Chaos" } }
local UNIT_PANEL_WIDTH = 460 -- UI/UnitPanel's width: the faction picker sits right of it

export type Actions = { ready: (boolean) -> (), faction: (string) -> (), start: () -> () }
export type FactionTile = { button: TextButton, portrait: Portrait.Portrait, stroke: UIStroke, faction: string }
export type Panel = {
	gui: ScreenGui,
	countdown: TextLabel,
	victory: TextLabel,
	help: TextLabel,
	clock: TextLabel,
	ready: TextButton,
	unready: TextButton,
	start: TextButton,
	factions: Frame,
	factionTitle: TextLabel,
	tiles: { FactionTile },
	readyOn: boolean,
	pending: { x: number, z: number, at: number }?,
	note: string?,
	noteUntil: number,
	shown: string,
}

-- Text with a dark outline, readable over any ground.
local function outlined(parent: Instance, size: number, weight: Enum.FontWeight, position: UDim2): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = position
	t.Size = UDim2.fromOffset(1000, size + 8)
	t.BackgroundTransparency = 1
	t.FontFace = Kit.font(weight)
	t.TextSize = size
	t.TextColor3 = Kit.COLOR.text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.3
	stroke.Thickness = 1.5
	stroke.Parent = t
	t.Parent = parent
	return t
end

local function bigButton(parent: Instance, text: string, kind: string, onClick: () -> (), y: number, height: number, size: number): TextButton
	local b = Kit.button(parent, text, kind, onClick, 170)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.8, 0, y, 0)
	b.Size = UDim2.fromOffset(170, height)
	b.TextSize = size
	return b
end

function PregamePanel.new(actions: Actions): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggPregame"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	local countdown = outlined(gui, 40, Enum.FontWeight.Bold, UDim2.fromScale(0.5, 0.4))
	countdown.TextColor3 = Kit.COLOR.accent
	-- above the bottom panels (the faction picker is 142 px tall)
	local victory = outlined(gui, 22, Enum.FontWeight.Medium, UDim2.new(0.5, 0, 1, -222))
	local help = outlined(gui, 26, Enum.FontWeight.Medium, UDim2.new(0.5, 0, 1, -172))
	local ready = bigButton(gui, "Ready", "go", function()
		actions.ready(true)
	end, 0.24, 48, 24)
	local unready = bigButton(gui, "Not ready", "stop", function()
		actions.ready(false)
	end, 0.24, 48, 22)
	local start = bigButton(gui, "Start", "primary", function()
		actions.start()
	end, 0.24, 36, 18)
	start.Position = UDim2.new(0.8, 0, 0.24, 46)
	local clock = outlined(gui, 14, Enum.FontWeight.Medium, UDim2.new(0.8, 0, 0.24, 80))
	clock.Size = UDim2.fromOffset(320, 20)

	-- the faction picker, right of the unit panel at the bottom
	local factions = Instance.new("Frame")
	factions.Name = "Factions"
	factions.AnchorPoint = Vector2.new(0, 1)
	factions.Position = UDim2.new(0, UNIT_PANEL_WIDTH + 8, 1, 0)
	factions.Size = UDim2.fromOffset(240, 142)
	factions.BackgroundColor3 = Kit.COLOR.panel
	factions.BackgroundTransparency = Kit.COLOR.panelTransparency
	factions.BorderSizePixel = 0
	factions.Parent = gui
	local factionTitle = Kit.text(factions, "Pick your faction", "label")
	factionTitle.Position = UDim2.fromOffset(10, 4)
	factionTitle.Size = UDim2.new(1, -20, 0, 22)
	local tiles: { FactionTile } = {}
	for i, f in PregamePanel.FACTIONS do
		local b = Instance.new("TextButton")
		b.Name = f[2]
		b.AutoButtonColor = false
		b.Text = ""
		b.Position = UDim2.fromOffset(10 + (i - 1) * 112, 30)
		b.Size = UDim2.fromOffset(104, 104)
		b.BackgroundColor3 = Kit.COLOR.box
		b.BorderSizePixel = 0
		b.Parent = factions
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Thickness = 2
		stroke.Parent = b
		local portrait = Portrait.new(b)
		local caption = Kit.text(b, f[2], "label")
		caption.AnchorPoint = Vector2.new(0.5, 1)
		caption.Position = UDim2.new(0.5, 0, 1, -2)
		caption.Size = UDim2.new(1, 0, 0, 18)
		caption.TextXAlignment = Enum.TextXAlignment.Center
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.new(0, 0, 0)
		outline.Transparency = 0.3
		outline.Parent = caption
		b.MouseButton1Click:Connect(function()
			actions.faction(f[1])
		end)
		table.insert(tiles, { button = b, portrait = portrait, stroke = stroke, faction = f[1] })
	end

	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return {
		gui = gui,
		countdown = countdown,
		victory = victory,
		help = help,
		clock = clock,
		ready = ready,
		unready = unready,
		start = start,
		factions = factions,
		factionTitle = factionTitle,
		tiles = tiles,
		readyOn = false,
		pending = nil,
		note = nil,
		noteUntil = 0,
		shown = "",
	}
end

-- A START_POS went out for (x, z).
function PregamePanel.sent(ui: Panel, x: number, z: number, now: number)
	ui.pending = { x = x, z = z, at = now }
end

-- Says why a click didn't pick.
function PregamePanel.refuse(ui: Panel, text: string, now: number)
	ui.note, ui.noteUntil = text, now + PregamePanel.NOTE_FOR
end

-- The match's win condition, from the lobby state the server publishes.
local function victoryText(): string?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local json = remotes and remotes:GetAttribute("Lobby")
	if type(json) ~= "string" then
		return nil
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	local win = ok and type(data) == "table" and type(data.state) == "table" and data.state.win
	if win == "ANNIHILATION" then
		return "Victory condition: Destroy every enemy unit"
	elseif win == "COMMAND_ENDS" then
		return "Victory condition: Kill all enemy Commanders"
	end
	return nil
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
	local faction = if me ~= 0 then Pregame.factionOf(world, me) else "order"
	for _, tile in ui.tiles do
		local def = world.defs.units[Pregame.COMMANDER[tile.faction]]
		if def then
			Portrait.set(tile.portrait, def, world.me.team)
		end
	end

	local key = `{pg.version}/{me}/{ui.note or ""}`
	if key == ui.shown then
		return
	end
	ui.shown = key
	local playing = me ~= 0
	ui.countdown.Text = if pg.countdown then `Starting in {pg.countdown}` else ""
	ui.victory.Text = victoryText() or ""
	if ui.note then
		ui.help.Text = ui.note
		ui.help.TextColor3 = Kit.COLOR.off
	else
		ui.help.Text = if not playing
			then "Players are picking their start spots."
			elseif pg.countdown then (if ui.readyOn then "Not ready stops the countdown." else "")
			elseif Pregame.allReady(world) then (if Pregame.isHost(world, me) then "Everyone is ready: press Start." else "Everyone is ready: waiting for the host to start.")
			elseif ui.readyOn then "Waiting for the other players to get ready."
			elseif mine and mine.x then "Click again to move your Commander, and click the Ready button."
			else "Pick a start spot within the green area, and click the Ready button."
		ui.help.TextColor3 = Kit.COLOR.text
	end
	ui.clock.Text = Pregame.clockText(world) or ""
	ui.ready.Visible = playing and not ui.readyOn
	ui.unready.Visible = playing and ui.readyOn
	-- the host's Start: lit once everyone is ready (/forcestart forces it)
	local host = playing and Pregame.isHost(world, me) and pg.countdown == nil
	ui.start.Visible = host
	local all = Pregame.allReady(world)
	ui.start.Text = if all then "Start" else "Start (waiting for ready)"
	ui.start.TextSize = if all then 18 else 13
	ui.start.BackgroundTransparency = if all then 0 else 0.6
	ui.factions.Visible = playing
	ui.factionTitle.Text = if ui.readyOn then "Pick your faction (Not ready to change)" else "Pick your faction"
	for _, tile in ui.tiles do
		local chosen = tile.faction == faction
		tile.stroke.Color = if chosen then Kit.COLOR.accent else Kit.COLOR.border
		tile.stroke.Transparency = if chosen then 0 else 0.8
		tile.button.BackgroundTransparency = if chosen then 0 else 0.4
	end
end

return PregamePanel

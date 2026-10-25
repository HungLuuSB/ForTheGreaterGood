--!strict
-- The pre-game's text (C-218, net.md 9b): while World.pregame is active,
-- a line of text under the resource bar, with no panel (the user: it took
-- up space): "CHOOSE YOUR START" (spectators: "PLAYERS ARE CHOOSING THEIR
-- STARTS"), "STARTING IN n" while the countdown runs; under it what to do
-- or the time until the match starts on its own, and the Ready / Not ready
-- button. A pick the server didn't take (blocked ground, too close to
-- another start) says so. Who picked and who is ready shows on the map
-- (Render/PregameMarks).

local Players = game:GetService("Players")

local Kit = require("./Kit")
local Pregame = require("../Core/Pregame")
local World = require("../Core/World")

local PregamePanel = {}

PregamePanel.REFUSE_AFTER = 1.0 -- seconds: a pick not shown by then was refused
PregamePanel.NOTE_FOR = 3 -- seconds a refusal stays up

export type Panel = {
	gui: ScreenGui,
	title: TextLabel,
	help: TextLabel,
	ready: TextButton,
	unready: TextButton,
	readyOn: boolean,
	pending: { x: number, z: number, at: number }?,
	note: string?,
	noteUntil: number,
	shown: string,
}

-- Text with a dark outline, readable over any ground.
local function outlined(parent: Instance, size: number, weight: Enum.FontWeight, y: number): TextLabel
	local t = Instance.new("TextLabel")
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.new(0.5, 0, 0, y)
	t.Size = UDim2.fromOffset(700, size + 6)
	t.BackgroundTransparency = 1
	t.FontFace = Kit.font(weight)
	t.TextSize = size
	t.TextColor3 = Kit.COLOR.text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.35
	stroke.Thickness = 1.5
	stroke.Parent = t
	t.Parent = parent
	return t
end

function PregamePanel.new(onReady: (boolean) -> ()): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggPregame"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	local title = outlined(gui, 26, Enum.FontWeight.SemiBold, 58) -- under the resource bar
	local help = outlined(gui, 14, Enum.FontWeight.Medium, 90)
	-- two buttons, one shown: the kit's filled buttons keep their fill
	local ready = Kit.button(gui, "READY", "go", function()
		onReady(true)
	end, 140)
	local unready = Kit.button(gui, "NOT READY", "stop", function()
		onReady(false)
	end, 140)
	for _, b in { ready, unready } do
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.new(0.5, 0, 0, 116)
	end
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, title = title, help = help, ready = ready, unready = unready, readyOn = false, pending = nil, note = nil, noteUntil = 0, shown = "" }
end

-- A START_POS went out for (x, z).
function PregamePanel.sent(ui: Panel, x: number, z: number, now: number)
	ui.pending = { x = x, z = z, at = now }
end

-- Says why a click didn't pick.
function PregamePanel.refuse(ui: Panel, text: string, now: number)
	ui.note, ui.noteUntil = text, now + PregamePanel.NOTE_FOR
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
	local key = `{pg.version}/{me}/{ui.note or ""}/{timeLeft}`
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
	local clock = `{timeLeft // 60}:{string.format("%02d", timeLeft % 60)}`
	if ui.note then
		ui.help.Text = ui.note
		ui.help.TextColor3 = Kit.COLOR.off
	else
		ui.help.Text = if pg.countdown then (if me == 0 then "" else "Not ready stops the countdown")
			elseif me == 0 then `Starts on its own in {clock}`
			elseif mine and mine.x then `Click to move your Commander · starts on its own in {clock}`
			else `Click inside your area to place your Commander · starts on its own in {clock}`
		ui.help.TextColor3 = Kit.COLOR.text
	end
	ui.ready.Visible = me ~= 0 and not ui.readyOn
	ui.unready.Visible = me ~= 0 and ui.readyOn
end

return PregamePanel

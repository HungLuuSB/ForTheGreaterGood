--!strict
-- The loading screen of a lobby match (C-173, the lobby stream's request
-- B-2; docs/contracts/match.md): full screen while the match server waits
-- for everyone ("waiting" in the Remotes folder's "Lobby" attribute), in
-- the layout of the user's reference (BAR) that the lobby place's own
-- pre-teleport screen uses too, so the hand-off looks continuous:
-- full-screen art (the models stream's layered key art with the lobby's
-- parallax, UI/KeyArt, C-176; a dark gradient while no art is approved), the map and
-- the players with a tick once each has loaded, a tip line, and a long
-- olive bar with this client's progress (Render/Preload). The progress goes
-- to the server every half second ({ op = "loaded", progress }); the match
-- starts once every player has loaded.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Kit = require("./Kit")
local KeyArt = require("./KeyArt")

local MatchLoading = {}

local OLIVE = Color3.fromRGB(140, 150, 70) -- the palette's olive (contract section 3)
local REPORT_EVERY = 0.5
local TIP_EVERY = 6

MatchLoading.TIPS = {
	"Right-click your own factory with builders selected: they help it produce.",
	"Hold Ctrl when you give a move order: the group keeps to its slowest unit's speed.",
	"Press I to jump to your next idle builder.",
	"Extractors on deposits give supply; generators, solar and wind give power. Watch the stall bar.",
	"Shift queues orders and keeps placing buildings.",
	"Radar shows enemies beyond sight, but shots at radar contacts miss more without Pinpointers.",
	"A shield dome turns shells and bends beams until its charge runs out.",
	"Drag with an extractor selected to cover every deposit in the circle.",
	"Settings (O) > Keys: rebind any key.",
}

export type UI = {
	gui: ScreenGui,
	bar: Frame,
	percent: TextLabel,
	title: TextLabel,
	players: TextLabel,
	tip: TextLabel,
	art: KeyArt.View,
	artShown: boolean,
	remote: RemoteEvent,
	state: any,
	lastReport: number,
	tipAt: number,
	tipIndex: number,
}

function MatchLoading.new(remotes: Instance): UI
	local gui = Instance.new("ScreenGui")
	gui.Name = "MatchLoading"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 200 -- over every HUD screen
	gui.Enabled = false
	-- the art: a dark gradient placeholder until the loading art exists
	local back = Instance.new("Frame")
	back.Name = "Art"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	back.BorderSizePixel = 0
	back.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(Color3.fromRGB(40, 44, 40), Color3.fromRGB(10, 11, 14))
	grad.Parent = back
	-- the key art over the gradient, under the text (C-176)
	local art = KeyArt.new(back, 1)
	local title = Kit.text(back, "FOR THE GREATER GOOD", "title", Kit.COLOR.text)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.22)
	title.Size = UDim2.new(0.8, 0, 0, 48)
	title.TextSize = 40
	title.TextXAlignment = Enum.TextXAlignment.Center
	local players = Kit.text(back, "", "label", Kit.COLOR.dim)
	players.AnchorPoint = Vector2.new(0.5, 0)
	players.Position = UDim2.fromScale(0.5, 0.34)
	players.Size = UDim2.new(0.8, 0, 0, 160)
	players.TextXAlignment = Enum.TextXAlignment.Center
	players.TextYAlignment = Enum.TextYAlignment.Top
	players.TextWrapped = true
	players.RichText = true
	local tip = Kit.text(back, "", "label", Kit.COLOR.text)
	tip.AnchorPoint = Vector2.new(0.5, 1)
	tip.Position = UDim2.new(0.5, 0, 1, -64)
	tip.Size = UDim2.new(0.8, 0, 0, 22)
	tip.TextXAlignment = Enum.TextXAlignment.Center
	-- the long bar
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -32)
	track.Size = UDim2.new(0.86, 0, 0, 14)
	track.BackgroundColor3 = Color3.fromRGB(30, 32, 26)
	track.BorderSizePixel = 0
	track.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = OLIVE
	stroke.Transparency = 0.4
	stroke.Parent = track
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = OLIVE
	bar.BorderSizePixel = 0
	bar.Parent = track
	local percent = Kit.text(track, "0%", "small", Kit.COLOR.text)
	percent.AnchorPoint = Vector2.new(1, 1)
	percent.Position = UDim2.new(1, 0, 0, -4)
	percent.Size = UDim2.fromOffset(80, 16)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	-- readable over bright art (the user: the text was hard to see; no
	-- card behind it, the user): a dark outline on every text, the players
	-- larger and bolder, a strip behind the tip
	local strip = Instance.new("Frame")
	strip.Name = "TipStrip"
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -60)
	strip.Size = UDim2.new(0.86, 0, 0, 30)
	strip.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
	strip.BackgroundTransparency = 0.4
	strip.BorderSizePixel = 0
	strip.ZIndex = 9
	strip.Parent = back
	local stripRound = Instance.new("UICorner")
	stripRound.CornerRadius = UDim.new(0, 6)
	stripRound.Parent = strip
	players.TextColor3 = Kit.COLOR.text
	players.TextSize = 17
	players.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	for _, t in { title, players, tip, percent } :: { TextLabel } do
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.new(0, 0, 0)
		outline.Transparency = 0.2
		outline.Thickness = if t == title then 2.5 else 1.5
		outline.Parent = t
	end
	-- the text and the bar sit over the art (its layers and bands use ZIndex 1..9)
	for _, d in { title, players, tip, track } :: { GuiObject } do
		d.ZIndex = 10
	end
	for _, d in track:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 11
		end
	end
	Kit.skin(gui)
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local remote = remotes:WaitForChild("Lobby") :: RemoteEvent
	local ui: UI = {
		gui = gui,
		bar = bar,
		percent = percent,
		title = title,
		players = players,
		tip = tip,
		art = art,
		artShown = false,
		remote = remote,
		state = nil,
		lastReport = -math.huge,
		tipAt = -math.huge,
		tipIndex = 0,
	}
	local function read()
		local json = remotes:GetAttribute("Lobby")
		local ok, data = pcall(function()
			return if type(json) == "string" then HttpService:JSONDecode(json) else nil
		end)
		ui.state = if ok and data then data.state else nil
	end
	remotes:GetAttributeChangedSignal("Lobby"):Connect(read)
	read()
	return ui
end

-- Is this a lobby match (the server's Lobby state carries `match`)?
function MatchLoading.isMatch(ui: UI): boolean
	local s = ui.state
	return s ~= nil and s.match ~= nil
end

-- Once a frame: shown while the lobby's match waits; `progress` (0..1) is
-- this client's (Render/Preload).
function MatchLoading.step(ui: UI, now: number, progress: number)
	local s = ui.state
	local waiting = s ~= nil and s.match ~= nil and s.phase == "waiting"
	ui.gui.Enabled = waiting
	if not waiting then
		if ui.artShown then
			ui.artShown = false
			ui.art.hide()
			pcall(RunService.Set3dRenderingEnabled, RunService, true)
		end
		return
	end
	if not ui.artShown then
		ui.artShown = true
		ui.art.show(nil) -- false while no art is approved: the gradient shows
		-- the screen is opaque (art or gradient): don't pay for drawing the
		-- world behind it, so the parallax stays smooth (C-184). Loading
		-- (meshes, ground, textures) is script and ContentProvider work.
		-- Game scripts may lack the capability for it (a Studio playtest
		-- refused it, 2026-10-26): then the world just keeps drawing, and
		-- the error mustn't abort the client's frame.
		pcall(RunService.Set3dRenderingEnabled, RunService, false)
	end
	ui.bar.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	ui.percent.Text = string.format("%d%%", math.floor(progress * 100))
	-- the players, each with a tick once loaded
	local lines = { string.format("<b>%s</b>  ·  %s", tostring(s.match.roomName or ""), string.gsub(tostring(s.mapId or ""), "^map:", "")) }
	for i, sl in s.slots or {} do
		local p = (s.loading or {})[tostring(i)]
		local mark = if sl.kind == "ai" then "AI" elseif p and p >= 1 then "ready" elseif p then string.format("%d%%", math.floor(p * 100)) else "joining"
		table.insert(lines, string.format("%s  —  %s", tostring(sl.name or ("Player " .. i)), mark))
	end
	ui.players.Text = table.concat(lines, "\n")
	if now - ui.tipAt >= TIP_EVERY then
		ui.tipAt = now
		ui.tipIndex = ui.tipIndex % #MatchLoading.TIPS + 1
		ui.tip.Text = "Tip: " .. MatchLoading.TIPS[ui.tipIndex]
	end
	if now - ui.lastReport >= REPORT_EVERY then
		ui.lastReport = now
		ui.remote:FireServer({ op = "loaded", progress = progress })
	end
end

return MatchLoading

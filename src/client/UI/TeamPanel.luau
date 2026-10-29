--!strict
-- The team panel (F23, the user; BAR's player list, bottom right): every
-- player by ally team in its colour, with two thin bars stacked, supply over
-- power, each its stored share of storage, where the client has them
-- (World.teamEco: its own, allies', everyone's for a spectator); hovering
-- the bars shows the numbers (income, stored / storage; the user: bars for
-- a clearer look, numbers on hover). On each ally's row:
--   Units   one click asks the allies for units; two clicks give the
--           selected units to that ally
--   ■ / ϟ   one click asks for supply / power; click and drag up: a slider
--           over the bank, giving that much to that ally on release
-- Above it, the last gifts and requests (SHARE events) for a few seconds.
-- Hidden during the pre-game. A placeholder look in the UI kit.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Api = require("../Api")
local Kit = require("./Kit")
local UiIcon = require("./UiIcon")
local Share = require("../Core/Share")
local TeamColors = require("../Render/TeamColors")

local TeamPanel = {}

TeamPanel.WIDTH = 356
TeamPanel.ROW = 20
TeamPanel.DOUBLE_CLICK = 0.35 -- seconds: two clicks on Units give the selection
TeamPanel.DRAG_PIXELS = 6 -- a drag on ■ / ϟ past this is a gift, not an ask
TeamPanel.DRAG_FULL = 150 -- pixels up for the whole bank
TeamPanel.NOTICE_SECONDS = 8

local SUPPLY = Color3.fromRGB(235, 235, 235)
local POWER = Color3.fromRGB(255, 214, 60)

type Row = { frame: Frame, swatch: Frame, name: TextLabel, bars: Frame, supply: Frame, power: Frame, buttons: Frame, team: number }
export type Panel = {
	gui: ScreenGui,
	root: Frame,
	list: Frame,
	notices: TextLabel,
	slider: TextLabel,
	tip: TextLabel, -- the hovered bars' numbers
	hovered: number?, -- the player whose bars are hovered
	rows: { [number]: Row },
	key: string,
	nextUpdate: number,
	seenShares: number,
	lines: { { text: string, at: number } },
}

local function short(n: number): string
	if n >= 10000 then
		return string.format("%.0fk", n / 1000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return string.format("%d", math.floor(n + 0.5))
end

local function nameOf(pid: number): string
	for _, p in TeamColors.players() do
		if p.id == pid and p.name then
			return p.name
		end
	end
	return `Player {pid}`
end

function TeamPanel.new(api: Api.Api): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "FtggTeamPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	local root = Instance.new("Frame")
	root.Name = "Teams"
	root.AnchorPoint = Vector2.new(1, 1)
	root.Position = UDim2.new(1, -8, 1, -8)
	root.Size = UDim2.fromOffset(TeamPanel.WIDTH, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.BackgroundColor3 = Kit.COLOR.panel
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Parent = gui
	Kit.pad(root, 6, 4, 6, 4)
	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 0, 0)
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Parent = root
	Kit.list(list, 1)
	local notices = Instance.new("TextLabel")
	notices.Name = "Notices"
	notices.AnchorPoint = Vector2.new(1, 1)
	notices.Position = UDim2.new(1, 0, 0, -4)
	notices.Size = UDim2.fromOffset(TeamPanel.WIDTH, 0)
	notices.AutomaticSize = Enum.AutomaticSize.Y
	notices.BackgroundTransparency = 1
	notices.FontFace = Kit.font(Enum.FontWeight.Medium)
	notices.TextSize = 13
	notices.TextColor3 = Kit.COLOR.accent
	notices.TextXAlignment = Enum.TextXAlignment.Right
	notices.TextYAlignment = Enum.TextYAlignment.Bottom
	notices.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.4
	stroke.Parent = notices
	notices.Parent = root
	local slider = Instance.new("TextLabel")
	slider.Name = "Slider"
	slider.AnchorPoint = Vector2.new(0.5, 1)
	slider.Size = UDim2.fromOffset(110, 22)
	slider.BackgroundColor3 = Kit.COLOR.box
	slider.BorderSizePixel = 0
	slider.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	slider.TextSize = 13
	slider.TextColor3 = Kit.COLOR.text
	slider.Visible = false
	slider.Parent = gui
	local tip = Instance.new("TextLabel")
	tip.Name = "Tip"
	tip.AnchorPoint = Vector2.new(1, 1)
	tip.AutomaticSize = Enum.AutomaticSize.XY
	tip.Size = UDim2.fromOffset(0, 0)
	tip.BackgroundColor3 = Kit.COLOR.box
	tip.BackgroundTransparency = 0.05
	tip.BorderSizePixel = 0
	tip.FontFace = Kit.font(Enum.FontWeight.Medium)
	tip.TextSize = 12
	tip.TextColor3 = Kit.COLOR.text
	tip.TextXAlignment = Enum.TextXAlignment.Left
	tip.RichText = true
	tip.Visible = false
	Kit.pad(tip, 6, 4, 6, 4)
	tip.Parent = gui
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, root = root, list = list, notices = notices, slider = slider, tip = tip, hovered = nil, rows = {}, key = "", nextUpdate = 0, seenShares = 0, lines = {} }
end

local function label(parent: Instance, x: number, width: number, color: Color3, align: Enum.TextXAlignment): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(x, 0)
	t.Size = UDim2.fromOffset(width, TeamPanel.ROW)
	t.FontFace = Kit.font(Enum.FontWeight.Medium)
	t.TextSize = 12
	t.TextColor3 = color
	t.TextXAlignment = align
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Parent = parent
	return t
end

local function small(parent: Instance, text: string, x: number, width: number, color: Color3, iconKey: string?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.Position = UDim2.fromOffset(x, 2)
	b.Size = UDim2.fromOffset(width, TeamPanel.ROW - 4)
	b.BackgroundColor3 = Kit.COLOR.control
	b.BorderSizePixel = 0
	b.FontFace = Kit.font(Enum.FontWeight.SemiBold)
	b.TextSize = 11
	b.TextColor3 = color
	b.Text = text
	-- 2D-E's icon in place of the glyph once its atlas is uploaded (C-259)
	local icon = if iconKey then UiIcon.make(iconKey, 12, color) else nil
	if icon then
		b.Text = ""
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = b
	end
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = b
	b.Parent = parent
	return b
end

-- Units: one click asks (after the double-click window), two give the selection.
local function unitsButton(panel: Panel, api: Api.Api, b: TextButton, pid: number)
	local lastAt = -math.huge
	b.MouseButton1Click:Connect(function()
		local now = os.clock()
		if now - lastAt <= TeamPanel.DOUBLE_CLICK then
			lastAt = -math.huge
			local ids = table.clone(api.state.selection)
			if #ids > 0 then
				api.send(Share.units(ids, pid))
			end
			return
		end
		lastAt = now
		task.delay(TeamPanel.DOUBLE_CLICK, function()
			if lastAt == now then
				api.send(Share.ask("units"))
			end
		end)
	end)
end

-- ■ / ϟ: a click asks; a drag up gives part of the bank.
local function resourceButton(panel: Panel, api: Api.Api, b: TextButton, pid: number, resource: string)
	b.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local startY = input.Position.Y
		local eco = api.state.economy
		local bank = if eco then (if resource == "supply" then eco.supply.stored else eco.power.stored) else 0
		local amount = 0
		local dragged = false
		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(m: InputObject)
			if m.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local up = startY - m.Position.Y
			dragged = dragged or math.abs(up) > TeamPanel.DRAG_PIXELS
			if dragged then
				amount = math.floor(bank * math.clamp(up / TeamPanel.DRAG_FULL, 0, 1))
				panel.slider.Visible = true
				panel.slider.Position = UDim2.fromOffset(m.Position.X, m.Position.Y - 12)
				panel.slider.Text = `Give {amount} {if resource == "supply" then "■" else "ϟ"}`
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(e: InputObject)
			if e.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			moveConn:Disconnect()
			endConn:Disconnect()
			panel.slider.Visible = false
			if dragged then
				if amount > 0 then
					api.send(Share.resource(pid, resource, amount))
				end
			else
				api.send(Share.ask(resource))
			end
		end)
	end)
end

local function build(panel: Panel, api: Api.Api, players: { TeamColors.Player })
	for _, r in panel.rows do
		r.frame:Destroy()
	end
	table.clear(panel.rows)
	for _, c in panel.list:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local world = api.world
	local me = world.me
	local order = 0
	local lastAlly: number? = nil
	for _, p in players do
		if p.allyTeam ~= lastAlly then
			lastAlly = p.allyTeam
			order += 1
			local head = Instance.new("TextLabel")
			head.BackgroundTransparency = 1
			head.Size = UDim2.new(1, 0, 0, 14)
			head.FontFace = Kit.font(Enum.FontWeight.SemiBold)
			head.TextSize = 10
			head.TextColor3 = Kit.COLOR.faint
			head.TextXAlignment = Enum.TextXAlignment.Left
			head.Text = if me.player ~= 0 and p.allyTeam == me.allyTeam then `YOUR TEAM` else `TEAM {p.allyTeam}`
			head.LayoutOrder = order
			head.Parent = panel.list
		end
		order += 1
		local frame = Instance.new("Frame")
		frame.Name = `Player{p.id}`
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(1, 0, 0, TeamPanel.ROW)
		frame.LayoutOrder = order
		frame.Parent = panel.list
		local swatch = Instance.new("Frame")
		swatch.Position = UDim2.fromOffset(0, 5)
		swatch.Size = UDim2.fromOffset(10, 10)
		swatch.BorderSizePixel = 0
		swatch.Parent = frame
		local name = label(frame, 14, 112, Kit.COLOR.text, Enum.TextXAlignment.Left)
		-- supply over power: thin bars of stored / storage, numbers on hover
		local bars = Instance.new("Frame")
		bars.Name = "Bars"
		bars.BackgroundTransparency = 1
		bars.Position = UDim2.fromOffset(132, 0)
		bars.Size = UDim2.fromOffset(136, TeamPanel.ROW)
		bars.Parent = frame
		local function bar(y: number, color: Color3): Frame
			local back = Instance.new("Frame")
			back.Position = UDim2.fromOffset(0, y)
			back.Size = UDim2.new(1, 0, 0, 4)
			back.BackgroundColor3 = Color3.fromRGB(45, 48, 54)
			back.BorderSizePixel = 0
			back.Parent = bars
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = color
			fill.BorderSizePixel = 0
			fill.Parent = back
			return fill
		end
		local supply = bar(5, SUPPLY)
		local power = bar(11, POWER)

		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.Position = UDim2.fromOffset(276, 0)
		buttons.Size = UDim2.fromOffset(68, TeamPanel.ROW)
		buttons.Parent = frame
		if me.player ~= 0 and p.allyTeam == me.allyTeam and p.id ~= me.player then
			unitsButton(panel, api, small(buttons, "Units", 0, 32, Kit.COLOR.text), p.id)
			resourceButton(panel, api, small(buttons, "■", 34, 16, SUPPLY, "supply"), p.id, "supply")
			resourceButton(panel, api, small(buttons, "ϟ", 52, 16, POWER, "power"), p.id, "power")
		end
		panel.rows[p.id] = { frame = frame, swatch = swatch, name = name, bars = bars, supply = supply, power = power, buttons = buttons, team = p.team }
	end
end

-- Is a match on: not the in-match lobby's preview or its results (the
-- Remotes folder's "Lobby" attribute, where there is one).
local phaseAt, phaseOk = -math.huge, true
local function matchOn(now: number): boolean
	if now - phaseAt < 1 then
		return phaseOk
	end
	phaseAt = now
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local json = remotes and remotes:GetAttribute("Lobby")
	phaseOk = true
	if type(json) == "string" then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		local phase = ok and type(data) == "table" and type(data.state) == "table" and data.state.phase
		phaseOk = phase == nil or phase == "playing" or phase == "waiting"
	end
	return phaseOk
end

-- Once a frame.
function TeamPanel.step(panel: Panel, api: Api.Api, now: number)
	local world = api.world
	panel.gui.Enabled = world.joined and not world.pregame.active and matchOn(now)
	if not panel.gui.Enabled then
		return
	end
	-- gifts and requests
	local shares = world.shares
	if #shares < panel.seenShares then
		panel.seenShares = 0 -- a rejoin cleared them
	end
	for i = panel.seenShares + 1, #shares do
		table.insert(panel.lines, { text = Share.text(shares[i], world.me.player, nameOf), at = now })
	end
	panel.seenShares = #shares
	while #panel.lines > 0 and (now - panel.lines[1].at > TeamPanel.NOTICE_SECONDS or #panel.lines > 3) do
		table.remove(panel.lines, 1)
	end
	local texts = {}
	for _, l in panel.lines do
		table.insert(texts, l.text)
	end
	panel.notices.Text = table.concat(texts, "\n")
	TeamPanel.tip(panel, api)
	if now < panel.nextUpdate then
		return
	end
	panel.nextUpdate = now + 0.25
	local players = table.clone(TeamColors.players())
	table.sort(players, function(a, b)
		if a.allyTeam ~= b.allyTeam then
			return a.allyTeam < b.allyTeam
		end
		return a.id < b.id
	end)
	local parts = { tostring(world.me.player), tostring(TeamColors.version) }
	for _, p in players do
		table.insert(parts, `{p.id}:{p.allyTeam}`)
	end
	local key = table.concat(parts, ",")
	if key ~= panel.key then
		panel.key = key
		build(panel, api, players)
	end
	for _, p in players do
		local r = panel.rows[p.id]
		if r == nil then
			continue
		end
		r.swatch.BackgroundColor3 = TeamColors.ofPlayer(p.id)
		r.name.Text = nameOf(p.id) .. (if p.id == world.me.player then " (you)" else "")
		local eco = world.teamEco[p.team]
		r.bars.Visible = eco ~= nil
		if eco then
			r.supply.Size = UDim2.fromScale(if eco.supply.storage > 0 then math.clamp(eco.supply.stored / eco.supply.storage, 0, 1) else 0, 1)
			r.power.Size = UDim2.fromScale(if eco.power.storage > 0 then math.clamp(eco.power.stored / eco.power.storage, 0, 1) else 0, 1)
		end
	end
end

-- The hovered bars' numbers by the cursor: income per second, stored /
-- storage (the wire's income is in tenths per second, as Api reads it).
function TeamPanel.tip(panel: Panel, api: Api.Api)
	-- the row whose bars are under the cursor (by position: sturdier than
	-- MouseEnter / MouseLeave across overlapping screens)
	local m = UserInputService:GetMouseLocation()
	local inset = game:GetService("GuiService"):GetGuiInset()
	local mx, my = m.X, m.Y - inset.Y
	panel.hovered = nil
	for pid, row in panel.rows do
		local p0, sz = row.bars.AbsolutePosition, row.bars.AbsoluteSize
		if row.bars.Visible and mx >= p0.X and mx <= p0.X + sz.X and my >= p0.Y and my <= p0.Y + sz.Y then
			panel.hovered = pid
		end
	end
	local r = panel.hovered and panel.rows[panel.hovered]
	local eco = r and api.world.teamEco[r.team]
	if r == nil or eco == nil then
		panel.tip.Visible = false
		return
	end
	local function line(mark: string, color: string, res: any): string
		return `<font color="{color}">{mark}</font>  +{short(res.income / 10)}/s   {short(res.stored)} / {short(res.storage)}`
	end
	panel.tip.Text = line("■", "#EBEBEB", eco.supply) .. "\n" .. line("ϟ", "#FFD63C", eco.power)
	panel.tip.Position = UDim2.fromOffset(mx - 8, my - 8)
	panel.tip.Visible = true
end

return TeamPanel

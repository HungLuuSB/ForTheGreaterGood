--!strict
-- The team panel (F23, the user; BAR's player list, bottom right): every
-- player by ally team in its colour, with its income and stored supply and
-- power where the client has them (World.teamEco: its own, allies' when the
-- server sends them, everyone's for a spectator). On each ally's row:
--   Units   one click asks the allies for units; two clicks give the
--           selected units to that ally
--   ■ / ϟ   one click asks for supply / power; click and drag up: a slider
--           over the bank, giving that much to that ally on release
-- Above it, the last gifts and requests (SHARE events) for a few seconds.
-- Hidden during the pre-game. A placeholder look in the UI kit.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Api = require("../Api")
local Kit = require("./Kit")
local Share = require("../Core/Share")
local TeamColors = require("../Render/TeamColors")

local TeamPanel = {}

TeamPanel.WIDTH = 330
TeamPanel.ROW = 20
TeamPanel.DOUBLE_CLICK = 0.35 -- seconds: two clicks on Units give the selection
TeamPanel.DRAG_PIXELS = 6 -- a drag on ■ / ϟ past this is a gift, not an ask
TeamPanel.DRAG_FULL = 150 -- pixels up for the whole bank
TeamPanel.NOTICE_SECONDS = 8

local SUPPLY = Color3.fromRGB(235, 235, 235)
local POWER = Color3.fromRGB(255, 214, 60)

type Row = { frame: Frame, swatch: Frame, name: TextLabel, supply: TextLabel, power: TextLabel, buttons: Frame }
export type Panel = {
	gui: ScreenGui,
	root: Frame,
	list: Frame,
	notices: TextLabel,
	slider: TextLabel,
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
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	return { gui = gui, root = root, list = list, notices = notices, slider = slider, rows = {}, key = "", nextUpdate = 0, seenShares = 0, lines = {} }
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

local function small(parent: Instance, text: string, x: number, width: number, color: Color3): TextButton
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
		local name = label(frame, 14, 104, Kit.COLOR.text, Enum.TextXAlignment.Left)
		local supply = label(frame, 120, 62, SUPPLY, Enum.TextXAlignment.Right)
		local power = label(frame, 184, 62, POWER, Enum.TextXAlignment.Right)
		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.Position = UDim2.fromOffset(250, 0)
		buttons.Size = UDim2.fromOffset(68, TeamPanel.ROW)
		buttons.Parent = frame
		if me.player ~= 0 and p.allyTeam == me.allyTeam and p.id ~= me.player then
			unitsButton(panel, api, small(buttons, "Units", 0, 32, Kit.COLOR.text), p.id)
			resourceButton(panel, api, small(buttons, "■", 34, 16, SUPPLY), p.id, "supply")
			resourceButton(panel, api, small(buttons, "ϟ", 52, 16, POWER), p.id, "power")
		end
		panel.rows[p.id] = { frame = frame, swatch = swatch, name = name, supply = supply, power = power, buttons = buttons }
	end
end

-- Once a frame.
function TeamPanel.step(panel: Panel, api: Api.Api, now: number)
	local world = api.world
	panel.gui.Enabled = world.joined and not world.pregame.active
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
		if eco then
			r.supply.Text = `+{short(eco.supply.income)} · {short(eco.supply.stored)}`
			r.power.Text = `+{short(eco.power.income)} · {short(eco.power.stored)}`
		else
			r.supply.Text, r.power.Text = "", ""
		end
	end
end

return TeamPanel

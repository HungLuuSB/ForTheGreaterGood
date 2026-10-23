--!strict
-- The room browser (L-3): every room you may see on this lobby server, with
-- search and filters, join by click (a password asked for locked rooms) or
-- by code (private rooms), and Create room.

local Config = require("../../shared/Config")
local Net = require("../Net")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Browser = {}

local COLUMNS = {
	{ "Room", 0.3 },
	{ "Host", 0.16 },
	{ "Map", 0.16 },
	{ "Mode", 0.12 },
	{ "Players", 0.1 },
	{ "", 0.16 },
}

-- A modal dialog in the kit's panel; returns the panel and a close function.
local function dialog(gui: Instance, title: string, size: Vector2): (any, () -> ())
	local p = Kit.panel(gui, title, size)
	p.root.ZIndex = 40
	p.scrim.ZIndex = 39
	local function close()
		p.root:Destroy()
		p.scrim:Destroy()
	end
	return p, close
end
Browser.dialog = dialog

local function passwordDialog(gui: Instance, room: any)
	local p, close = dialog(gui, `Join {room.name}`, Vector2.new(420, 220))
	Kit.list(p.content, Kit.SPACE.m)
	Kit.text(p.content, "This room has a password.", "small").LayoutOrder = 1
	local pw = Ui.input(p.content, "Password", 360)
	pw.LayoutOrder = 2
	local buttons = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 32))
	buttons.LayoutOrder = 3
	local bl = Kit.list(buttons, Kit.SPACE.s, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	Ui.button(buttons, "Cancel", "ghost", close, 100)
	local function join()
		Net.send({ op = "join", roomId = room.id, password = pw.Text })
		close()
	end
	Ui.button(buttons, "Join", "go", join, 100)
	pw.FocusLost:Connect(function(enter: boolean)
		if enter then
			join()
		end
	end)
	pw:CaptureFocus()
end

local function createDialog(gui: Instance)
	local p, close = dialog(gui, "Create room", Vector2.new(520, 400))
	Kit.list(p.content, Kit.SPACE.s)
	local nameRow = Kit.row(p.content, "Name", 1)
	local name = Ui.input(nameRow, `{(Net.view and Net.view.me.name) or "My"}'s room`, 250)
	local privacy = "public"
	Kit.segmented(Kit.row(p.content, "Who can join", 2), { { "public", "Public" }, { "friends", "Friends" }, { "private", "Private" } }, privacy, function(v)
		privacy = v
	end, 82)
	local pwRow = Kit.row(p.content, "Password (optional)", 3)
	local pw = Ui.input(pwRow, "None", 250)
	local maxPlayers = Config.DEFAULT_PLAYERS
	Kit.slider(Kit.row(p.content, "Players and spectators", 4), Config.MIN_PLAYERS, Config.MAX_PLAYERS, 1, maxPlayers, "%d", function(v)
		maxPlayers = v
	end, 190)
	local help = Kit.text(p.content, "Private rooms don't show in the browser: share the room code. The map's starts limit who plays; the rest spectate.", "small", Kit.COLOR.faint)
	help.TextWrapped = true
	help.Size = UDim2.new(1, 0, 0, 40)
	help.LayoutOrder = 5
	local buttons = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 36))
	buttons.LayoutOrder = 6
	local bl = Kit.list(buttons, Kit.SPACE.s, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	Ui.button(buttons, "Cancel", "ghost", close, 110, 34)
	Ui.button(buttons, "Create", "go", function()
		local text = if name.Text ~= "" then name.Text else name.PlaceholderText
		Net.send({ op = "create", name = text, privacy = privacy, password = if pw.Text ~= "" then pw.Text else nil, maxPlayers = maxPlayers })
		close()
	end, 130, 34)
	name:CaptureFocus()
end
Browser.createDialog = createDialog

function Browser.new(frame: Frame, _router: any): any
	local gui = frame:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui
	local title = Kit.text(frame, "Battle rooms", "title")
	title.TextSize = 40
	title.Size = UDim2.new(0, 400, 0, 52)
	local count = Kit.text(frame, "", "small", Kit.COLOR.dim)
	count.Position = UDim2.fromOffset(2, 50)

	local bar = Ui.frame(frame, "Toolbar", UDim2.new(1, 0, 0, 36), UDim2.fromOffset(0, 84))
	local bl = Kit.list(bar, Kit.SPACE.m, true)
	local search = Ui.input(bar, "Search rooms, hosts, maps", 280)
	search.LayoutOrder = 1
	local filter = "all"
	local render: () -> ()
	Kit.segmented(bar, { { "all", "All" }, { "open", "Open" }, { "free", "Has seats" } }, filter, function(v)
		filter = v
		render()
	end, 96).frame.LayoutOrder = 2
	local gap = Ui.frame(bar, "Gap", UDim2.fromOffset(24, 1))
	gap.LayoutOrder = 3
	local code = Ui.input(bar, "Room code", 120)
	code.LayoutOrder = 4
	Ui.button(bar, "Join by code", "ghost", function()
		if code.Text ~= "" then
			Net.send({ op = "join", roomId = string.upper(code.Text) })
		end
	end, 130).LayoutOrder = 5
	local create = Ui.button(bar, "Create room", "go", function()
		createDialog(gui)
	end, 150, 34)
	create.LayoutOrder = 6
	bl.VerticalAlignment = Enum.VerticalAlignment.Center

	local tableCard = Ui.card(frame, "Rooms", UDim2.new(1, 0, 1, -136), UDim2.fromOffset(0, 136), 0.1)
	Kit.pad(tableCard, Kit.SPACE.m)
	local header = Ui.frame(tableCard, "Header", UDim2.new(1, 0, 0, 26))
	local x = 0
	for _, c in COLUMNS do
		local l = Kit.text(header, string.upper(c[1]), "small", Kit.COLOR.faint)
		l.Position = UDim2.new(x, Kit.SPACE.s, 0, 0)
		l.Size = UDim2.new(c[2], -Kit.SPACE.s, 1, 0)
		x += c[2]
	end
	local listHolder = Ui.frame(tableCard, "List", UDim2.new(1, 0, 1, -30), UDim2.fromOffset(0, 30))
	local scroll = Kit.scroll(listHolder)
	Kit.list(scroll, 2)
	local empty = Kit.text(listHolder, "", "label", Kit.COLOR.dim)
	empty.Size = UDim2.fromScale(1, 1)
	empty.TextXAlignment = Enum.TextXAlignment.Center

	local rooms: { any } = {}
	function render()
		Ui.clear(scroll)
		local q = string.lower(search.Text)
		local shown = 0
		for i, r in rooms do
			local text = string.lower(`{r.name} {r.host} {r.mapName}`)
			if q ~= "" and not string.find(text, q, 1, true) then
				continue
			end
			if filter == "open" and r.phase ~= "setup" then
				continue
			end
			if filter == "free" and (r.phase ~= "setup" or r.members >= r.maxPlayers) then
				continue
			end
			shown += 1
			local row = Instance.new("TextButton")
			row.Name = r.id
			row.AutoButtonColor = false
			row.Text = ""
			row.Size = UDim2.new(1, 0, 0, 40)
			row.BackgroundColor3 = Kit.COLOR.raised
			row.BackgroundTransparency = if shown % 2 == 0 then 0.97 else 1
			row.BorderSizePixel = 0
			row.LayoutOrder = i
			row.Parent = scroll
			Ui.corner(row, 4)
			local base = row.BackgroundTransparency
			row.MouseEnter:Connect(function()
				row.BackgroundTransparency = 0.93
			end)
			row.MouseLeave:Connect(function()
				row.BackgroundTransparency = base
			end)
			local status = if r.phase == "setup" then (if r.members >= r.maxPlayers then "Full" else "Open") else (if r.phase == "starting" then "Starting" else "In match")
			local cells = {
				r.name .. (if r.locked then "   [password]" else "") .. (if r.privacy ~= "public" then `   [{Ui.label2(r.privacy)}]` else ""),
				r.host,
				r.mapName,
				Ui.label2(r.mode),
				`{r.members}/{r.maxPlayers}` .. (if r.ai > 0 then ` +{r.ai} AI` else ""),
				status,
			}
			local cx = 0
			for c, col in COLUMNS do
				local color = if c == 6 then (if status == "Open" then Kit.COLOR.on elseif status == "Full" then Kit.COLOR.dim else Kit.COLOR.accent) elseif c == 1 then Kit.COLOR.text else Kit.COLOR.dim
				local l = Kit.text(row, cells[c], "label", color)
				l.Position = UDim2.new(cx, Kit.SPACE.s, 0, 0)
				l.Size = UDim2.new(col[2], -Kit.SPACE.s, 1, 0)
				l.TextTruncate = Enum.TextTruncate.AtEnd
				cx += col[2]
			end
			row.MouseButton1Click:Connect(function()
				if r.phase ~= "setup" then
					return
				end
				if r.locked then
					passwordDialog(gui, r)
				else
					Net.send({ op = "join", roomId = r.id })
				end
			end)
		end
		empty.Text = if #rooms == 0 then "No rooms yet. Create one, or start a Skirmish." elseif shown == 0 then "No room matches." else ""
		count.Text = `{#rooms} room{if #rooms == 1 then "" else "s"} on this lobby server`
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		render()
	end)

	return {
		update = function(v: any)
			rooms = v.rooms
			render()
		end,
	}
end

return Browser

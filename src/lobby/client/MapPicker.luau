--!strict
-- The room's map picker (G12, the user: "a dedicated panel that lists
-- available maps + preview panel + information panel"), in place of the
-- Map dropdown. Three columns:
--   the maps, grouped small → large as the server sends them (F4);
--   the picked map's preview, without starts (players pick theirs in the
--   match; the user: "don't show the suggested landing points");
--   its information: size, starts, then wind, tides and features from the
--   map's `info` once the server sends it (sim-A's MapRegistry, G12).
-- The host chooses; everyone else can look.

local Config = require("../shared/Config")
local MapImage = require("./MapImage")
local Net = require("./Net")
local Ui = require("./Ui")

local Kit = Ui.Kit

local MapPicker = {}

local LIST_W = 250
local INFO_W = 270
local ROW_H = 46
local PICKED = Color3.fromRGB(128, 98, 50)

local function sizeNames(): { [string]: string }
	local out = {}
	for _, z in Config.MAP_SIZES do
		out[z.id] = z.name
	end
	return out
end

-- The information rows for `map`: { label, value }.
function MapPicker.facts(map: any): { { string } }
	local sizeName = sizeNames()
	local rows = {
		{ "Size", `{sizeName[map.size] or "Small"}` .. (if map.cells then ` · {map.cells} × {map.cells} cells` else "") },
		{ "Starts", `{map.starts} · up to {math.min(map.starts, Config.MAX_ALLY_TEAMS)} teams` },
	}
	local info = map.info
	if type(info) == "table" then
		-- (S-193: a Wind Turbine's power/s at the weakest and strongest wind; a
		-- Tidal Generator's power/s, 0 without water)
		if info.windMin ~= nil and info.windMax ~= nil then
			table.insert(rows, { "Wind", `{info.windMin} to {info.windMax} power/s per turbine` })
		end
		if info.tidal ~= nil then
			table.insert(rows, { "Tidal", if info.tidal > 0 then `{info.tidal} power/s per generator` else "None (no water)" })
		end
		if type(info.features) == "table" and #info.features > 0 then
			local names = {}
			for _, f in info.features do
				local word = tostring(f)
				table.insert(names, string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2))
			end
			table.insert(rows, { "Features", table.concat(names, ", ") })
		end
	end
	return rows
end

-- Opens the picker over `gui` on `current` (a map ID). `choose` is nil for
-- someone who can only look.
function MapPicker.open(gui: Instance, current: string, choose: ((string) -> ())?)
	local Browser = require("./Pages/Browser") :: any
	local p, close = Browser.dialog(gui, "Maps", Vector2.new(980, 580))
	local body = Ui.frame(p.content, "Body", UDim2.new(1, 0, 1, -46))
	local picked = current

	-- left: the list
	local listCard = Ui.card(body, "List", UDim2.new(0, LIST_W, 1, 0), nil, 0.25)
	local list = Kit.scroll(listCard)
	Kit.pad(list, Kit.SPACE.s)
	Kit.list(list, 4)

	-- middle: the preview
	local mid = Ui.frame(body, "Preview", UDim2.new(1, -(LIST_W + INFO_W + Kit.SPACE.m * 2), 1, 0), UDim2.fromOffset(LIST_W + Kit.SPACE.m, 0))
	local preview = MapImage.new(mid, false)

	-- right: the information
	local info = Ui.card(body, "Info", UDim2.new(0, INFO_W, 1, 0), UDim2.new(1, -INFO_W, 0, 0), 0.25)
	Kit.pad(info, Kit.SPACE.m)
	Kit.list(info, Kit.SPACE.s)

	local rows: { [string]: Frame } = {}
	local chooseButton: TextButton? = nil

	local function showInfo(map: any)
		Ui.clear(info)
		Kit.list(info, Kit.SPACE.s)
		local title = Kit.text(info, map.name, "title")
		title.TextSize = 24
		title.Size = UDim2.new(1, 0, 0, 30)
		title.TextWrapped = true
		title.LayoutOrder = 1
		for i, f in MapPicker.facts(map) do
			local row = Ui.frame(info, f[1], UDim2.new(1, 0, 0, 0))
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.LayoutOrder = i + 1
			local l = Kit.text(row, string.upper(f[1]), "small", Kit.COLOR.faint)
			l.Size = UDim2.new(1, 0, 0, 16)
			local v = Kit.text(row, f[2], "label", Kit.COLOR.text)
			v.Position = UDim2.fromOffset(0, 16)
			v.Size = UDim2.new(1, 0, 0, 0)
			v.AutomaticSize = Enum.AutomaticSize.Y
			v.TextWrapped = true
		end
		if map.info == nil then
			local note = Kit.text(info, "Wind, tides and terrain features show here once the server lists them.", "small", Kit.COLOR.faint)
			note.TextWrapped = true
			note.Size = UDim2.new(1, 0, 0, 34)
			note.LayoutOrder = 20
		end
	end

	local function pick(id: string)
		picked = id
		local map = Net.map(id)
		preview.set(map)
		if map then
			showInfo(map)
		end
		for rid, row in rows do
			row.BackgroundColor3 = if rid == id then PICKED else Kit.COLOR.raised
			row.BackgroundTransparency = if rid == id then 0.1 else 0.96
		end
		if chooseButton then
			Ui.enable(chooseButton, id ~= current)
		end
	end

	local sizeName = sizeNames()
	local lastSize = nil
	for i, m in Net.maps or {} do
		if m.size ~= lastSize then
			lastSize = m.size
			local h = Kit.text(list, `{string.upper(sizeName[m.size] or "Small")} MAPS`, "small", Kit.COLOR.faint)
			h.Size = UDim2.new(1, 0, 0, 22)
			h.LayoutOrder = i * 2 - 1
		end
		local row = Instance.new("TextButton")
		row.Name = m.id
		row.AutoButtonColor = false
		row.Text = ""
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.LayoutOrder = i * 2
		row.BackgroundColor3 = Kit.COLOR.raised
		row.BackgroundTransparency = 0.96
		row.BorderSizePixel = 0
		row.Parent = list
		Ui.corner(row, Kit.CONTROL_RADIUS)
		local n = Kit.text(row, m.name, "label", Kit.COLOR.text)
		n.Position = UDim2.fromOffset(Kit.SPACE.m, 4)
		n.Size = UDim2.new(1, -Kit.SPACE.m * 2, 0, 20)
		n.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = Kit.text(row, `{m.starts} starts · {sizeName[m.size] or "Small"}` .. (if m.cells then ` · {m.cells} cells` else ""), "small", Kit.COLOR.dim)
		sub.Position = UDim2.fromOffset(Kit.SPACE.m, 24)
		sub.Size = UDim2.new(1, -Kit.SPACE.m * 2, 0, 16)
		row.MouseButton1Click:Connect(function()
			pick(m.id)
		end)
		rows[m.id] = row
	end

	-- buttons
	local buttons = Ui.frame(p.content, "Buttons", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 1, -36))
	local bl = Kit.list(buttons, Kit.SPACE.s, true)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	if choose then
		Ui.button(buttons, "Cancel", "ghost", close, 110, 34).LayoutOrder = 1
		chooseButton = Ui.button(buttons, "Choose map", "go", function()
			if picked ~= current then
				choose(picked)
			end
			close()
		end, 150, 34)
		;(chooseButton :: TextButton).LayoutOrder = 2
	else
		Ui.button(buttons, "Close", "primary", close, 110, 34).LayoutOrder = 1
	end
	pick(current)
end

return MapPicker

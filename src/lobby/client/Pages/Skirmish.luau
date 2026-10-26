--!strict
-- Skirmish (BAR's scenario page): map cards on the left, grouped by size
-- (small, medium, large: F4) (greyscale, in color with a light outline
-- when hovered or chosen), the chosen map's
-- details on the right with your faction, the AI's level and faction, and
-- Launch. Launch asks the server for a private room with one AI, started at
-- once (the same start path as any room).

local Config = require("../../shared/Config")
local MapImage = require("../MapImage")
local Net = require("../Net")
local Ui = require("../Ui")

local Kit = Ui.Kit

local Skirmish = {}

local NOTES: { [string]: string } = {
	["map:canyon"] = "A long desert canyon after Classic Glitters: mesas split the ground into lanes, badlands slow the flanks. North against south.",
	["map:coastline"] = "Two shores of a narrow sea. Hold the beaches and the water between them.",
	["map:crossroads"] = "Four starts around a central sea, roads crossing the middle. Made for free for all.",
	["map:normandy"] = "Hedgerows, farmland and bluffs over a landing beach. Close fighting, few long sight lines.",
	["map:ridgeline"] = "One long ridge between the starts, with passes to fight over.",
	["map:twin_lakes"] = "Two lakes divide a 2v2 battlefield: allies start side by side.",
}

function Skirmish.new(frame: Frame, _router: any): any
	local title = Kit.text(frame, "Skirmish", "title")
	title.TextSize = 40
	title.Size = UDim2.new(0, 400, 0, 52)

	local grid = Ui.frame(frame, "Cards", UDim2.new(1, -470, 1, -70), UDim2.fromOffset(0, 66))
	local scroll = Kit.scroll(grid)
	Kit.list(scroll, Kit.SPACE.m)
	-- one group of cards per map size, under its heading
	local function group(order: number, title: string, note: string): Frame
		local head = Ui.frame(scroll, "Head", UDim2.new(1, -Kit.SPACE.m, 0, 28))
		head.LayoutOrder = order * 2 - 1
		local hl = Kit.list(head, Kit.SPACE.s, true)
		hl.VerticalAlignment = Enum.VerticalAlignment.Bottom
		local t = Ui.label(head, title, "section", nil, 1)
		t.TextSize = 20
		Ui.label(head, note, "small", Kit.COLOR.dim, 2)
		local cards = Ui.frame(scroll, "Group", UDim2.new(1, -Kit.SPACE.m, 0, 0))
		cards.LayoutOrder = order * 2
		cards.AutomaticSize = Enum.AutomaticSize.Y
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(300, 210)
		layout.CellPadding = UDim2.fromOffset(Kit.SPACE.l, Kit.SPACE.l)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = cards
		return cards
	end

	local card = Ui.card(frame, "Detail", UDim2.new(0, 450, 1, -66), UDim2.new(1, -450, 0, 66), 0.1)
	Kit.pad(card, Kit.SPACE.xl, Kit.SPACE.l)
	-- the details scroll; Launch stays at the bottom
	local detailHolder = Ui.frame(card, "Info", UDim2.new(1, 0, 1, -52))
	local detail = Kit.scroll(detailHolder)
	Kit.list(detail, Kit.SPACE.s)
	local name = Kit.text(detail, "", "title")
	name.LayoutOrder = 1
	local facts = Kit.text(detail, "", "small", Kit.COLOR.dim)
	facts.LayoutOrder = 2
	local previewHolder = Ui.frame(detail, "Preview", UDim2.new(1, -8, 0, 190))
	previewHolder.LayoutOrder = 3
	local preview = MapImage.new(previewHolder, false) -- no starts: they're picked in the match (G12)
	local note = Kit.text(detail, "", "small", Kit.COLOR.text)
	note.TextWrapped = true
	note.AutomaticSize = Enum.AutomaticSize.Y
	note.Size = UDim2.new(1, 0, 0, 0)
	note.LayoutOrder = 4
	local cond = Kit.row(detail, "Victory condition", 5, 26)
	Ui.label(cond, "Destroy the enemy Command Vehicle", "small", Kit.COLOR.text)

	local choice = { faction = "order", level = "normal", enemy = "chaos", map = nil :: any }
	local function options(list: { string }): { { string } }
		local out = {}
		for _, v in list do
			table.insert(out, { v, Ui.label2(v) })
		end
		return out
	end
	-- segmented, not dropdowns: a dropdown's list would be clipped by the scroll
	Kit.segmented(Kit.row(detail, "Your faction", 6), options(Config.FACTIONS), choice.faction, function(v)
		choice.faction = v
	end, 90)
	Kit.segmented(Kit.row(detail, "Opponent faction", 7), options(Config.FACTIONS), choice.enemy, function(v)
		choice.enemy = v
	end, 90)
	local levels = {}
	for _, v in Config.LEVELS do
		table.insert(levels, { v, (Config.LEVEL_SHORT :: any)[v] or Ui.label2(v) })
	end
	Kit.segmented(Kit.row(detail, "Difficulty", 8), levels, choice.level, function(v)
		choice.level = v
	end, 76)
	local launch = Ui.button(card, "Launch", "go", function()
		if choice.map then
			Net.send({ op = "quick", mapId = choice.map.id, faction = choice.faction, level = choice.level, enemy = choice.enemy })
		end
	end, 402, 40)
	launch.Size = UDim2.new(1, 0, 0, 42)
	launch.Position = UDim2.new(0, 0, 1, -42)
	launch.TextSize = 16

	local tiles: { [string]: Frame } = {}
	local images: { [string]: any } = {}
	local hovered: string? = nil
	local function paintTiles()
		for id, c in tiles do
			local lit = id == hovered or (choice.map and choice.map.id == id)
			images[id].setGrey(not lit)
			local s = c:FindFirstChildOfClass("UIStroke")
			if s then
				local chosen = choice.map and choice.map.id == id
				s.Color = if chosen then Kit.COLOR.accent elseif lit then Color3.new(1, 1, 1) else Kit.COLOR.border
				s.Transparency = if chosen then 0.1 elseif lit then 0.4 else 0.85
			end
		end
	end
	local function select(m: any)
		choice.map = m
		name.Text = m.name
		facts.Text = `{m.starts} starts · {m.preview.cells[1]} × {m.preview.cells[2]} cells`
		note.Text = NOTES[m.id] or ""
		preview.set(m)
		paintTiles()
	end

	local built = false
	local function build()
		if built then
			return
		end
		built = true
		local maps = Net.loadMaps()
		local groups: { [string]: Frame } = {}
		local sizeName = {}
		for k, z in Config.MAP_SIZES do
			sizeName[z.id] = z.name
			for _, m in maps do
				if (m.size or "small") == z.id then
					groups[z.id] = group(k, `{z.name} maps`, z.note)
					break
				end
			end
		end
		for i, m in maps do
			local tile = Ui.frame(groups[m.size or "small"] or scroll, m.id, UDim2.fromOffset(300, 210))
			tile.LayoutOrder = i
			tile.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
			tile.BackgroundTransparency = 0
			tile.ClipsDescendants = true
			Ui.corner(tile, 8)
			Ui.stroke(tile, 0.85)
			local img = MapImage.new(tile, false, true)
			img.setGrey(true)
			img.set(m)
			images[m.id] = img
			local fade = Ui.frame(tile, "Fade", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 1, -60))
			fade.BackgroundColor3 = Color3.new(0, 0, 0)
			fade.BackgroundTransparency = 0
			fade.ZIndex = 5
			local g = Instance.new("UIGradient")
			g.Rotation = 90
			g.Transparency = NumberSequence.new(1, 0.25)
			g.Parent = fade
			local l = Kit.text(tile, m.name, "section", Color3.new(1, 1, 1))
			l.TextSize = 20
			l.Position = UDim2.new(0, 12, 1, -38)
			l.Size = UDim2.new(1, -24, 0, 30)
			l.ZIndex = 6
			local tag = Kit.text(tile, `{m.starts} players · {sizeName[m.size or "small"] or "Small"}`, "small", Kit.COLOR.dim)
			tag.Position = UDim2.new(0, 12, 1, -38)
			tag.Size = UDim2.new(1, -24, 0, 30)
			tag.TextXAlignment = Enum.TextXAlignment.Right
			tag.ZIndex = 6
			local hit = Instance.new("TextButton")
			hit.BackgroundTransparency = 1
			hit.Text = ""
			hit.Size = UDim2.fromScale(1, 1)
			hit.ZIndex = 7
			hit.Parent = tile
			hit.MouseButton1Click:Connect(function()
				select(m)
			end)
			hit.MouseEnter:Connect(function()
				hovered = m.id
				paintTiles()
			end)
			hit.MouseLeave:Connect(function()
				if hovered == m.id then
					hovered = nil
				end
				paintTiles()
			end)
			tiles[m.id] = tile
		end
		-- a duel map first
		for _, m in maps do
			if m.starts == 2 then
				select(m)
				return
			end
		end
		select(maps[1])
	end

	return {
		show = function()
			task.spawn(build)
		end,
	}
end

return Skirmish

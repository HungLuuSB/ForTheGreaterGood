--!strict
-- The statistics panel (C-105), the results screen: a UI kit panel with a
-- sidebar (Overview, Economy, Combat, Units) and filter chips (All, You,
-- one per ally team, with its team colors).
--   Overview  VICTORY / DEFEAT, the match length, the scoreboard (units
--             built / lost / killed, supply and power gathered / spent,
--             damage dealt; the sim's Stats, S-63), replays and back
--   Economy   supply and power produced, used, stored over match time
--   Combat    damage dealt and taken, units killed
--   Units     units built and lost
-- Lines are the players' team colors; the samples come from the server's
-- StatSeries every 10 s (damage taken waits for sim request 41). Built
-- once and reused: `show` only refills it, and charts draw one per frame
-- (UI/Kit), so opening it doesn't hitch.

local TeamColors = require("../Render/TeamColors")
local Chart = require("../Core/Chart")
local Kit = require("./Kit")

local Statistics = {}

local PAGES = { "Overview", "", "Economy", "Combat", "Units" }
local CHARTS = {
	Economy = {
		{ "supplyGathered", "Supply · Produced" },
		{ "supplySpent", "Supply · Used" },
		{ "supplyStored", "Supply · Stored" },
		{ "powerGathered", "Power · Produced" },
		{ "powerSpent", "Power · Used" },
		{ "powerStored", "Power · Stored" },
	},
	Combat = {
		{ "damageDealt", "Damage · Dealt" },
		{ "damageTaken", "Damage · Taken" },
		{ "unitsKilled", "Units · Killed" },
	},
	Units = {
		{ "unitsBuilt", "Units · Built" },
		{ "unitsLost", "Units · Lost" },
	},
}

export type Actions = {
	back: (() -> ())?, -- nil: not the host
	save: (() -> ())?, -- nil: no replays
	watch: ((index: number?) -> ())?,
}

export type UI = {
	panel: Kit.Panel,
	pages: { [string]: Frame },
	overview: ScrollingFrame,
	chipRow: Frame,
	charts: { [string]: Kit.LineChart },
	filter: string, -- "all", "you", "ally:<n>"
	data: any?,
	key: string?, -- what `data` came from (charts redraw only for new results)
	me: number,
}

local function clock(seconds: number): string
	return Chart.clock(seconds)
end

local function int(x: number?): string
	return Chart.format(math.floor((x or 0) + 0.5))
end

-- The players a filter keeps.
local function shown(ui: UI, p: any): boolean
	if ui.filter == "all" then
		return true
	elseif ui.filter == "you" then
		return p.user == ui.me
	end
	return ui.filter == `ally:{p.allyTeam}`
end

local function redrawCharts(ui: UI)
	local r = ui.data
	local series = r and r.series
	for _, list in CHARTS do
		for _, c in list do
			local chart = ui.charts[c[1]]
			if series == nil or #(series.t or {}) == 0 then
				chart.note("No samples for this match")
				continue
			end
			local lines = {}
			local any = false
			for _, p in r.players or {} do
				local values = series.players and series.players[tostring(p.id)]
				local ys = values and values[c[1]]
				if shown(ui, p) and ys and #ys > 0 then
					any = true
					local xs = table.move(series.t, 1, #ys, 1, {})
					table.insert(lines, { xs = xs, ys = ys, color = TeamColors(p.team or p.id) })
				end
			end
			if c[1] == "damageTaken" and not any then
				chart.note("Damage taken comes with sim request 41")
			elseif not any then
				chart.note("No player in this filter")
			else
				chart.set(lines, series.t[#series.t])
			end
		end
	end
end

local function fillOverview(ui: UI, actions: Actions, status: string?, saved: { string }?)
	local o = ui.overview
	for _, c in o:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
	local r = ui.data or {}
	local mine
	for _, p in r.players or {} do
		if p.user == ui.me then
			mine = p
		end
	end
	local won = mine ~= nil and mine.won
	local title = if won then "VICTORY" elseif r.over then "DEFEAT" elseif mine and mine.outAt then "ELIMINATED" else "MATCH OVER"
	local head = Kit.text(o, title, "title", if won then Kit.COLOR.victory else Kit.COLOR.defeat)
	head.TextSize = 34
	head.Size = UDim2.new(1, 0, 0, 44)
	head.LayoutOrder = 1
	local length = Kit.text(o, `Match length {clock(r.seconds or 0)}`, "label", Kit.COLOR.dim)
	length.LayoutOrder = 2
	local rows = {}
	for _, p in r.players or {} do
		local st = p.stats or {}
		local out = if p.won then "won" elseif p.outAt then `out {clock(p.outAt)}` else "standing"
		local color = TeamColors(p.team or p.id)
		local name = p.name .. (if p.user == ui.me then " (you)" else "")
		table.insert(rows, {
			function(cell: Frame)
				local sw = Instance.new("Frame")
				sw.AnchorPoint = Vector2.new(0, 0.5)
				sw.Position = UDim2.fromScale(0, 0.5)
				sw.Size = UDim2.fromOffset(12, 12)
				sw.BackgroundColor3 = color
				sw.BorderSizePixel = 0
				sw.Parent = cell
				local l = Kit.text(cell, name, "label")
				l.Position = UDim2.fromOffset(20, 0)
				l.Size = UDim2.new(1, -20, 1, 0)
				l.TextTruncate = Enum.TextTruncate.AtEnd
			end,
			p.faction,
			tostring(p.allyTeam),
			out,
			`{st.unitsBuilt or p.units or 0} / {st.unitsLost or 0} / {st.unitsKilled or 0}`,
			`{int(st.supplyGathered)} / {int(st.supplySpent)}`,
			`{int(st.powerGathered)} / {int(st.powerSpent)}`,
			int(st.damageDealt),
		})
	end
	Kit.table(o, {
		{ title = "Player", width = 0.22 },
		{ title = "Faction", width = 0.09 },
		{ title = "Team", width = 0.06 },
		{ title = "End", width = 0.1 },
		{ title = "Built / lost / kills", width = 0.15, align = "right" },
		{ title = "Supply in / out", width = 0.15, align = "right" },
		{ title = "Power in / out", width = 0.14, align = "right" },
		{ title = "Damage", width = 0.09, align = "right" },
	}, rows, 32, 3)
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, 40)
	bar.LayoutOrder = 4
	bar.Parent = o
	Kit.list(bar, Kit.SPACE.s, true)
	if actions.save and actions.watch then
		local watch = actions.watch :: (number?) -> ()
		Kit.button(bar, "Save replay", "ghost", actions.save, 130).LayoutOrder = 1
		Kit.button(bar, "Watch replay", nil, function()
			watch(nil)
		end, 130).LayoutOrder = 2
		for i, name in saved or {} do
			if i > 3 then
				break
			end
			local b = Kit.button(bar, `▶ {name}`, "ghost", function()
				watch(i)
			end, 150)
			b.TextTruncate = Enum.TextTruncate.AtEnd
			b.LayoutOrder = 2 + i
		end
	end
	if status and status ~= "" then
		local s = Kit.text(o, status, "small", Kit.COLOR.on)
		s.LayoutOrder = 5
	end
	local backRow = Instance.new("Frame")
	backRow.BackgroundTransparency = 1
	backRow.Size = UDim2.new(1, 0, 0, 40)
	backRow.LayoutOrder = 6
	backRow.Parent = o
	if actions.back then
		Kit.button(backRow, "Back to lobby", "primary", actions.back, 160)
	else
		Kit.text(backRow, "The host returns to the lobby", "small").Size = UDim2.fromScale(1, 1)
	end
end

local function fillChips(ui: UI)
	for _, c in ui.chipRow:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
	local r = ui.data or {}
	local chips: { [string]: Kit.Chip } = {}
	local function add(key: string, label: string, swatches: { Color3 }, order: number)
		local chip = Kit.chip(ui.chipRow, label, swatches, function()
			ui.filter = key
			for k, c in chips do
				c.set(k == key)
			end
			redrawCharts(ui)
		end)
		chip.button.LayoutOrder = order
		chips[key] = chip
	end
	add("all", "All", {}, 1)
	local mine, allies = nil, {}
	for _, p in r.players or {} do
		if p.user == ui.me then
			mine = p
		end
		allies[p.allyTeam] = allies[p.allyTeam] or {}
		table.insert(allies[p.allyTeam], TeamColors(p.team or p.id))
	end
	if mine then
		add("you", "You", { TeamColors(mine.team or mine.id) }, 2)
	end
	local teams = {}
	for a in allies do
		table.insert(teams, a)
	end
	table.sort(teams)
	for i, a in teams do
		add(`ally:{a}`, `Team {a}`, allies[a], 2 + i)
	end
	if chips[ui.filter] == nil then
		ui.filter = "all"
	end
	chips[ui.filter].set(true)
end

-- Builds the panel (hidden) in `gui`.
function Statistics.new(gui: ScreenGui, me: number): UI
	local ui: UI
	local panel = Kit.panel(gui, "Statistics", Vector2.new(1120, 580), PAGES, function(name)
		for n, f in ui.pages do
			f.Visible = n == name
		end
		ui.chipRow.Visible = name ~= "Overview"
	end)
	panel.root.Visible = false
	local content = panel.content
	local chipRow = Instance.new("Frame")
	chipRow.Name = "Chips"
	chipRow.BackgroundTransparency = 1
	chipRow.Size = UDim2.new(1, 0, 0, 34)
	chipRow.Parent = content
	Kit.list(chipRow, Kit.SPACE.s, true)
	ui = { panel = panel, pages = {}, overview = nil :: any, chipRow = chipRow, charts = {}, filter = "all", data = nil, key = nil, me = me }
	for _, name in PAGES do
		if name == "" then
			continue
		end
		local f = Instance.new("Frame")
		f.Name = name
		f.BackgroundTransparency = 1
		f.Visible = false
		f.Parent = content
		ui.pages[name] = f
		if name == "Overview" then
			f.Size = UDim2.fromScale(1, 1)
			local sc = Kit.scroll(f)
			Kit.list(sc, Kit.SPACE.s)
			Kit.pad(sc, 0, Kit.SPACE.l, Kit.SPACE.m, 0)
			ui.overview = sc
		else
			f.Position = UDim2.fromOffset(0, 44)
			f.Size = UDim2.new(1, 0, 1, -44)
			local sc = Kit.scroll(f)
			local grid = Instance.new("UIGridLayout")
			grid.CellSize = UDim2.fromOffset(Kit.PLOT.X + 48, Kit.PLOT.Y + 54)
			grid.CellPadding = UDim2.fromOffset(Kit.SPACE.s, Kit.SPACE.m)
			grid.SortOrder = Enum.SortOrder.LayoutOrder
			grid.Parent = sc
			for i, c in CHARTS[name] do
				ui.charts[c[1]] = Kit.chart(sc, c[2], i)
			end
		end
	end
	panel.select("Overview")
	return ui
end

-- Fills the panel with match results `r` (decoded from `key`, the
-- lobby's JSON) and shows it. `actions`: the buttons (nil hides one);
-- `status` and `saved`: the replay state.
function Statistics.show(ui: UI, r: any, key: string, actions: Actions, status: string?, saved: { string }?)
	local fresh = ui.key ~= key
	ui.data, ui.key = r, key
	fillOverview(ui, actions, status, saved)
	if fresh then
		fillChips(ui)
		redrawCharts(ui)
	end
	ui.panel.root.Visible = true
end

function Statistics.hide(ui: UI)
	ui.panel.root.Visible = false
end

return Statistics

--!strict
-- The build ghost (guide 15.6): a translucent copy of the structure's model
-- on its snapped spot, over a footprint plate, tinted green (valid) or red
-- (the client's placement check fails). Follows Api.state.placement.
-- Upgrades in place (C-121): while the ghost (or the Upgrade extractors
-- command) can upgrade, every own extractor it upgrades gets a pulsing
-- green disc; an area drag (extractor drags, Upgrade extractors) draws its
-- circle. The build grid (C-166, Settings > Interface "Build grid"): the
-- 8-stud build cells round the ghost as thin lines on the ground, fading
-- out with distance, so footprints line up.
-- Facing (C-206, reference 7): a factory's ghost has an arrow on its exit
-- side, and turning the placement (R) shows "Buildings set to face East"
-- over it for a moment. The ghost turns as the built frame will (heading =
-- facing × 90°, Core/Facing).
-- A row being dragged (G14) shows every building it will place: a ghost on
-- each spot, green where it can go and red where not, as Api's placeRow
-- checks them. Planned buildings are highlighted on top of everything
-- (Highlight AlwaysOnTop, G15), so hills and units don't hide them.

local Players = game:GetService("Players")

local Api = require("../Api")
local Facing = require("../Core/Facing")
local Placement = require("../Core/Placement")
local Upgrades = require("../Core/Upgrades")
local World = require("../Core/World")
local Models = require("./Models")

local PlacementGhost = {}

local VALID = Color3.fromRGB(90, 230, 110)
local INVALID = Color3.fromRGB(235, 70, 60)

export type Ghost = {
	folder: Folder,
	plate: Part,
	highlight: Highlight,
	model: Model?,
	defId: string?,
	marks: Folder, -- upgrade target discs and the area circle (outside the ghost: shown without placing too)
	row: { ok: Model, bad: Model, shown: { Model }, free: { Model }, defId: string?, key: string }, -- a dragged row's ghosts (G14)
	discs: { Part },
	area: Part,
	grid: Folder, -- the build grid's line segments (outside the ghost: its Highlight would tint them)
	lines: { Part },
	gridKey: string, -- the cell and map the grid was laid for
	arrow: { Part }, -- shaft and the two bars of the head (C-206)
	labelGui: ScreenGui, -- "Buildings set to face …" over the ghost: a screen-space label like IdleMarks (no BillboardGuis)
	label: TextLabel,
	facing: number?, -- the facing last drawn
	labelUntil: number,
}

local LABEL_SECONDS = 4

local MARK_POOL = 40
PlacementGhost.GRID = true -- Settings > Interface: the build grid round the ghost
PlacementGhost.GRID_CELLS = 6 -- cells from the ghost's centre to the grid's edge
local CELL = 8
local GRID_COLOR = Color3.fromRGB(220, 235, 255)

local function flatPart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = VALID
	p.Parent = parent
	return p
end

function PlacementGhost.new(): Ghost
	local folder = Instance.new("Folder")
	folder.Name = "Ghost"
	local plate = Instance.new("Part")
	plate.Name = "Footprint"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Material = Enum.Material.Neon
	plate.Transparency = 0.6
	plate.Parent = folder
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.45
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = folder
	local marks = Instance.new("Folder")
	marks.Name = "UpgradeMarks"
	local discs = {}
	for i = 1, MARK_POOL do
		local d = flatPart(`Target{i}`, marks)
		d.Transparency = 1
		discs[i] = d
	end
	local area = flatPart("Area", marks)
	area.Transparency = 1
	marks.Parent = workspace
	local grid = Instance.new("Folder")
	grid.Name = "BuildGrid"
	-- the facing arrow: a shaft and a chevron, flat on the ground
	local arrow = {}
	for i, name in { "Shaft", "HeadL", "HeadR" } do
		local a = Instance.new("Part")
		a.Name = name
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.CastShadow = false
		a.Material = Enum.Material.Neon
		a.Transparency = 0.15
		a.Size = if i == 1 then Vector3.new(3, 0.3, 9) else Vector3.new(2.6, 0.3, 7)
		a.Parent = folder
		arrow[i] = a
	end
	local labelGui = Instance.new("ScreenGui")
	labelGui.Name = "FtggFacingLabel"
	labelGui.ResetOnSpawn = false
	labelGui.IgnoreGuiInset = true -- positions come from WorldToViewportPoint
	labelGui.DisplayOrder = -1 -- under the HUD panels
	labelGui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.Name = "Facing"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 24)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold)
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(240, 244, 248)
	label.Visible = false
	label.Parent = labelGui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = label
	-- a dragged row: its spots' ghosts in two models, one highlight each (green, red)
	local function rowModel(name: string, color: Color3): Model
		local m = Instance.new("Model")
		m.Name = name
		local h = Instance.new("Highlight")
		h.FillColor, h.OutlineColor = color, color
		h.FillTransparency, h.OutlineTransparency = 0.5, 0.2
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.Parent = m
		m.Parent = folder
		return m
	end
	local row = { ok = rowModel("RowOk", VALID), bad = rowModel("RowBad", INVALID), shown = {}, free = {}, defId = nil, key = "" }
	return { folder = folder, plate = plate, highlight = highlight, model = nil, defId = nil, marks = marks, discs = discs, area = area, grid = grid, lines = {}, gridKey = "", arrow = arrow, labelGui = labelGui, label = label, facing = nil, labelUntil = 0, row = row }
end

-- Lays the arrow on the exit side of a footprint `size` studs wide at
-- (x, z), pointing out, each part on the ground under it (C-206).
local function layArrow(g: Ghost, world: World.World, def: any, x: number, z: number, size: number, facing: number, color: Color3, shown: boolean)
	local ex, ez = Facing.exit(facing)
	local dir = Vector3.new(ex, 0, ez)
	local side = Vector3.new(-ez, 0, ex)
	local floats = World.floats(def)
	local function onGround(p: Vector3): Vector3
		return Vector3.new(p.X, World.groundY(world, p.X, p.Z, floats) + 0.6, p.Z)
	end
	local base = Vector3.new(x, 0, z) + dir * (size / 2 + 2)
	local tip = base + dir * 12
	local shaftMid = onGround(base + dir * 4.5)
	g.arrow[1].CFrame = CFrame.lookAt(shaftMid, shaftMid + dir)
	for i, sign in { 1, -1 } do
		local from = tip - dir * 4.5 + side * (sign * 4.5)
		local mid = onGround((from + tip) / 2)
		g.arrow[i + 1].CFrame = CFrame.lookAt(mid, mid + (tip - from).Unit)
	end
	for _, a in g.arrow do
		a.Color = color
		a.Transparency = if shown then 0.15 else 1
	end
end

local function setModel(g: Ghost, def: any)
	if g.defId == def.id then
		return
	end
	if g.model then
		g.model:Destroy()
	end
	local model = Models.template(def):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = math.max(d.Transparency, 0.45)
			d.CastShadow = false
		end
	end
	model.Parent = g.folder
	g.model, g.defId = model, def.id
	g.highlight.Adornee = model
end

-- The upgrade discs and the area circle (`areaFrom` / `areaTo`: Controls').
local function marks(g: Ghost, api: Api.Api, now: number, areaFrom: Vector3?, areaTo: Vector3?)
	local world = api.world
	local p = api.state.placement
	local upgrader = nil
	if p then
		local def = world.defs.unitByIndex[p.defIndex]
		if Upgrades.isUpgrade(world.defs, def) then
			upgrader = def
		end
	elseif api.state.commandMode == "upgrade" then
		local defs = {}
		for _, id in api.state.selection do
			local u = world.units[id]
			local d = u and World.def(world, u)
			if d then
				table.insert(defs, d)
			end
		end
		upgrader = Upgrades.upgraderFor(world.defs, defs)
	end
	local n = 0
	if upgrader then
		local pulse = 0.45 + 0.15 * math.sin(now * 5)
		local under = p and p.valid and p.replaces -- the ghost draws over that one instead
		for _, id in Upgrades.targets(world, upgrader) do
			if n >= MARK_POOL then
				break
			end
			if id == under then
				continue
			end
			local u = world.units[id]
			local udef = World.def(world, u)
			n += 1
			local d = g.discs[n]
			local size = (udef and udef.footprint or 1) * 8 + 3
			local y = World.groundY(world, u.x, u.z)
			d.Size = Vector3.new(0.15, size, size)
			d.CFrame = CFrame.new(u.x, y + 0.15, u.z) * CFrame.Angles(0, 0, math.pi / 2)
			d.Transparency = pulse
		end
	end
	for i = n + 1, MARK_POOL do
		g.discs[i].Transparency = 1
	end
	if areaFrom and areaTo then
		local r = math.max(math.sqrt((areaTo.X - areaFrom.X) ^ 2 + (areaTo.Z - areaFrom.Z) ^ 2), 1)
		local y = World.groundY(world, areaFrom.X, areaFrom.Z)
		g.area.Size = Vector3.new(0.1, 2 * r, 2 * r)
		g.area.CFrame = CFrame.new(areaFrom.X, y + 0.25, areaFrom.Z) * CFrame.Angles(0, 0, math.pi / 2)
		g.area.Transparency = 0.92
	else
		g.area.Transparency = 1
	end
end

-- Lays the build grid round cell boundary (bx, bz) (the corner nearest
-- the ghost's centre): every cell edge within GRID_CELLS, one segment per
-- cell so the lines follow the ground.
local function layGrid(g: Ghost, world: World.World, bx: number, bz: number)
	local grid = world.grid
	local r = PlacementGhost.GRID_CELLS
	local n = 0
	local function segment(x0: number, z0: number, x1: number, z1: number)
		local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
		local d = math.max(math.abs(mx - bx), math.abs(mz - bz)) / (r * CELL)
		if d > 1 then
			return
		end
		n += 1
		local part = g.lines[n]
		if part == nil then
			local made = Instance.new("Part")
			made.Name = "Line"
			made.Anchored = true
			made.CanCollide = false
			made.CanQuery = false
			made.CanTouch = false
			made.CastShadow = false
			made.Material = Enum.Material.Neon
			made.Color = GRID_COLOR
			made.Parent = g.grid
			g.lines[n] = made
			part = made
		end
		local a = Vector3.new(x0, World.groundY(world, x0, z0) + 0.12, z0)
		local b = Vector3.new(x1, World.groundY(world, x1, z1) + 0.12, z1)
		part.Size = Vector3.new(0.12, 0.04, (b - a).Magnitude)
		part.CFrame = CFrame.lookAt((a + b) / 2, b)
		part.Transparency = 0.45 + 0.5 * d -- fades toward the edge
	end
	for i = -r, r do
		for j = -r, r - 1 do
			local x, z = bx + i * CELL, bz + j * CELL
			if grid:inBounds(grid:cellAt(x, z + 1)) or grid:inBounds(grid:cellAt(x - 1, z + 1)) then
				segment(x, z, x, z + CELL) -- along z
			end
			local x2, z2 = bx + j * CELL, bz + i * CELL
			if grid:inBounds(grid:cellAt(x2 + 1, z2)) or grid:inBounds(grid:cellAt(x2 + 1, z2 - 1)) then
				segment(x2, z2, x2 + CELL, z2) -- along x
			end
		end
	end
	for i = n + 1, #g.lines do
		g.lines[i].Transparency = 1
	end
end

PlacementGhost.ROW_MAX = 40 -- ghosts drawn for one row

local function rowGhost(g: Ghost, def: any): Model
	local m = table.remove(g.row.free)
	if m == nil then
		m = Models.template(def):Clone()
		for _, d in (m :: Model):GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = math.max(d.Transparency, 0.45)
				d.CastShadow = false
			end
		end
	end
	return m :: Model
end

-- The row from `from` to `to` (Controls' drag; nil when not dragging one):
-- a ghost on each spot Placement.row gives, checked as Api's placeRow does.
-- Redrawn only when the row's spots change. True while a row shows.
local function drawRow(g: Ghost, api: Api.Api, def: any, facing: number, from: Vector3?, to: Vector3?): boolean
	local r = g.row
	local world = api.world
	local spots = if from and to then Placement.row(world, def, from.X, from.Z, to.X, to.Z) else {}
	if #spots < 2 then
		spots = {}
	end
	local n = math.min(#spots, PlacementGhost.ROW_MAX)
	local keys = {}
	for i = 1, n do
		keys[i] = `{spots[i][1]},{spots[i][2]}`
	end
	local key = `{def.id}/{facing}/{table.concat(keys, ";")}`
	if key == r.key then
		return n > 0
	end
	r.key = key
	for _, m in r.shown do
		m.Parent = nil
		table.insert(r.free, m)
	end
	table.clear(r.shown)
	if r.defId ~= def.id then
		for _, m in r.free do
			m:Destroy() -- another structure: its ghosts are another model
		end
		table.clear(r.free)
		r.defId = def.id
	end
	local planned = Placement.planned(world, api.waypoints.byUnit)
	for i = 1, n do
		local check = Placement.check(world, def, spots[i][1], spots[i][2], planned)
		local m = rowGhost(g, def)
		local y = World.groundY(world, check.x, check.z, World.floats(def))
		local offset = (m:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
		m:PivotTo(CFrame.new(check.x, y, check.z) * CFrame.Angles(0, Facing.heading(facing) + math.pi, 0) * offset)
		m.Parent = if check.ok then r.ok else r.bad
		table.insert(r.shown, m)
	end
	return n > 0
end

function PlacementGhost.step(g: Ghost, api: Api.Api, now: number?, areaFrom: Vector3?, areaTo: Vector3?, rowFrom: Vector3?, rowTo: Vector3?)
	marks(g, api, now or os.clock(), areaFrom, areaTo)
	local p = api.state.placement
	if p == nil or not PlacementGhost.GRID then
		if g.grid.Parent ~= nil then
			g.grid.Parent = nil
		end
	end
	if p == nil then
		if g.folder.Parent ~= nil then
			g.folder.Parent = nil
		end
		g.facing, g.labelUntil = nil, 0 -- the next placement starts quiet
		g.label.Visible = false
		return
	end
	if PlacementGhost.GRID then
		local grid = api.world.grid
		-- the cell corner nearest the ghost's centre
		local bx = grid.originX + math.floor((p.x - grid.originX) / CELL + 0.5) * CELL
		local bz = grid.originZ + math.floor((p.z - grid.originZ) / CELL + 0.5) * CELL
		local key = `{bx},{bz},{api.world.mapVersion}`
		if key ~= g.gridKey then
			g.gridKey = key
			layGrid(g, api.world, bx, bz)
		end
		if g.grid.Parent == nil then
			g.grid.Parent = workspace
		end
	end
	local world = api.world
	local def = world.defs.unitByIndex[p.defIndex]
	setModel(g, def)
	local model = g.model :: Model
	-- a dragged row: its ghosts stand in for the single one (G14)
	local rowing = drawRow(g, api, def, p.facing, rowFrom, rowTo)
	model.Parent = if rowing then nil else g.folder
	g.plate.Transparency = if rowing then 1 else 0.6
	local color = if p.valid then VALID else INVALID
	local y = World.groundY(world, p.x, p.z, World.floats(def)) -- on the water for a water structure (C-192)
	local size = def.footprint * 8
	g.plate.Size = Vector3.new(size, 0.2, size)
	g.plate.CFrame = CFrame.new(p.x, y + 0.1, p.z)
	g.plate.Color = color
	g.highlight.FillColor = color
	g.highlight.OutlineColor = color
	-- an upgrade sits on the old extractor: drawn through it, the plate over its base
	local upgrading = p.valid and p.replaces ~= nil
	g.highlight.FillTransparency = if upgrading then 0.65 else 0.45
	if upgrading then
		g.plate.CFrame = CFrame.new(p.x, y + 0.35, p.z)
		g.plate.Size = Vector3.new(size + 2, 0.2, size + 2)
	end
	local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
	-- PivotTo: blockout parts are anchored, not welded (moving the root alone left them behind);
	-- turned as the renderer turns the built frame: heading + π (C-206: it was π - heading, flipped for 0 and 2)
	model:PivotTo(CFrame.new(p.x, y, p.z) * CFrame.Angles(0, Facing.heading(p.facing) + math.pi, 0) * offset)
	-- the exit arrow on factories, and the message when the facing turns
	local factory = def.buildOptions ~= nil and #def.buildOptions > 0
	layArrow(g, world, def, p.x, p.z, size, p.facing, color, factory)
	local t = now or os.clock()
	if g.facing ~= nil and g.facing ~= p.facing then
		g.labelUntil = t + LABEL_SECONDS
		g.label.Text = Facing.message(p.facing)
	end
	g.facing = p.facing
	local shown = false
	local cam = workspace.CurrentCamera
	if t < g.labelUntil and cam then
		local v, onScreen = cam:WorldToViewportPoint(Vector3.new(p.x, y + size / 2 + 6, p.z))
		shown = onScreen
		g.label.Position = UDim2.fromOffset(v.X, v.Y)
	end
	g.label.Visible = shown
	if g.folder.Parent == nil then
		g.folder.Parent = workspace
	end
end

return PlacementGhost

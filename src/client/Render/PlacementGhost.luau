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

local Api = require("../Api")
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
	discs: { Part },
	area: Part,
	grid: Folder, -- the build grid's line segments (outside the ghost: its Highlight would tint them)
	lines: { Part },
	gridKey: string, -- the cell and map the grid was laid for
}

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
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
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
	return { folder = folder, plate = plate, highlight = highlight, model = nil, defId = nil, marks = marks, discs = discs, area = area, grid = grid, lines = {}, gridKey = "" }
end

-- Facing 0..3 (Schema.Facing: north, east, south, west) as a sim heading
-- (forward = (sin h, cos h); north is -Z).
local function headingOf(facing: number): number
	return math.pi - facing * math.pi / 2
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

function PlacementGhost.step(g: Ghost, api: Api.Api, now: number?, areaFrom: Vector3?, areaTo: Vector3?)
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
	local color = if p.valid then VALID else INVALID
	local y = World.groundY(world, p.x, p.z)
	local size = def.footprint * 8
	g.plate.Size = Vector3.new(size, 0.2, size)
	g.plate.CFrame = CFrame.new(p.x, y + 0.1, p.z)
	g.plate.Color = color
	g.highlight.FillColor = color
	g.highlight.OutlineColor = color
	-- an upgrade sits on the old extractor: drawn through it, the plate over its base
	local upgrading = p.valid and p.replaces ~= nil
	g.highlight.DepthMode = if upgrading then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	g.highlight.FillTransparency = if upgrading then 0.65 else 0.45
	if upgrading then
		g.plate.CFrame = CFrame.new(p.x, y + 0.35, p.z)
		g.plate.Size = Vector3.new(size + 2, 0.2, size + 2)
	end
	local offset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
	-- PivotTo: blockout parts are anchored, not welded (moving the root alone left them behind)
	model:PivotTo(CFrame.new(p.x, y, p.z) * CFrame.Angles(0, headingOf(p.facing) + math.pi, 0) * offset)
	if g.folder.Parent == nil then
		g.folder.Parent = workspace
	end
end

return PlacementGhost

--!strict
-- Draws a map's layers for maps without baked place terrain (guide 5.4):
-- the ground and water (workspace.Map). Supply deposits are Render/Deposits'
-- (C-123; gold plates until then). Two ways to draw the ground (C-28):
--   "terrain"  Roblox Terrain voxels on Core/Terrain's smooth surface
--              (Render/Terrain; the default: see C-28 for the measurements)
--   "parts"    anchored columns, one height per cell: cells merge into
--              rectangles of equal height inside 8 × 8-cell blocks, so a flat
--              map is a checkerboard of 64-stud tiles
-- A named map with baked mesh ground in the models stream's manifest
-- (C-167, docs/contracts/map-ground.md) draws those tiles instead
-- (Render/MeshGround): the default for every map since S-192, the voxels
-- staying only for maps without an approved bake. Water is flat planes at
-- each water surface (Ground.WATER "mesh", C-236), or terrain water.
-- Units are placed on the smooth surface either way (World.groundY).
-- Materials follow the sim's terrain types, or a hand-made map's features
-- (`feature`, e.g. Normandy.feature: hedgerows, roads, bridges); its house
-- cells get brick houses with slate roofs as parts (C-66).

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local CoreTerrain = require("../Core/Terrain")
local RenderTerrain = require("./Terrain")
local GroundMeshes = require("../Core/GroundMeshes")
local MeshGround = require("./MeshGround")

local Ground = {}

Ground.MODE = "terrain" :: "terrain" | "parts"
Ground.WATER = "mesh" :: "mesh" | "terrain" -- C-236; Studio: Invoke("water", "terrain") to compare
-- the last build, for Invoke("ground"): mode, parts, seconds (terrain: filled in when its build finishes)
Ground.last = {} :: { [string]: any }

local BLOCK = 8 -- cells per tile side
local THICKNESS = 4

local function landColor(h: number, checker: boolean): Color3
	local t = math.clamp((h + 10) / 40, 0, 1)
	local base = Color3.fromRGB(96, 122, 74):Lerp(Color3.fromRGB(150, 140, 110), t)
	return if checker then base:Lerp(Color3.new(0, 0, 0), 0.08) else base
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true -- the camera and input raycast the ground
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	return p
end

-- Anchored columns from the map's lowest ground up to each cell's height.
local function buildParts(layers: Layers.Layers, folder: Folder): number
	local g = layers.grid
	local cell = Grid.CELL_SIZE
	local base = CoreTerrain.bounds(layers) - THICKNESS
	local parts = 0
	local function heightAt(cx: number, cz: number): (number, number)
		local i = g:index(cx, cz)
		return Layers.getHeight(layers, i), Layers.getWater(layers, i)
	end

	for bz = 0, g.cellsZ - 1, BLOCK do
		for bx = 0, g.cellsX - 1, BLOCK do
			local checker = ((bx // BLOCK) + (bz // BLOCK)) % 2 == 1
			local maxX, maxZ = math.min(bx + BLOCK, g.cellsX) - 1, math.min(bz + BLOCK, g.cellsZ) - 1
			local done: { [number]: boolean } = {}
			for cz = bz, maxZ do
				for cx = bx, maxX do
					if done[cz * g.cellsX + cx] then
						continue
					end
					local h, water = heightAt(cx, cz)
					-- grow right, then down, while cells match
					local ex = cx
					while ex + 1 <= maxX and not done[cz * g.cellsX + ex + 1] do
						local h2, w2 = heightAt(ex + 1, cz)
						if h2 ~= h or w2 ~= water then
							break
						end
						ex += 1
					end
					local ez = cz
					local grow = true
					while grow and ez + 1 <= maxZ do
						for x = cx, ex do
							local h2, w2 = heightAt(x, ez + 1)
							if done[(ez + 1) * g.cellsX + x] or h2 ~= h or w2 ~= water then
								grow = false
								break
							end
						end
						if grow then
							ez += 1
						end
					end
					for z = cz, ez do
						for x = cx, ex do
							done[z * g.cellsX + x] = true
						end
					end
					local x0, z0 = g.originX + cx * cell, g.originZ + cz * cell
					local sx, sz = (ex - cx + 1) * cell, (ez - cz + 1) * cell
					local tall = math.max(h - base, THICKNESS)
					local center = Vector3.new(x0 + sx / 2, h - tall / 2, z0 + sz / 2)
					newPart("Land", Vector3.new(sx, tall, sz), CFrame.new(center), landColor(h, checker)).Parent = folder
					parts += 1
					if water > 0 then
						local w = newPart("Water", Vector3.new(sx, water, sz), CFrame.new(center.X, h + water / 2, center.Z), Color3.fromRGB(52, 108, 168))
						w.Transparency = 0.35
						w.CanQuery = false
						w.Parent = folder
						parts += 1
					end
				end
			end
		end
	end
	return parts
end

-- The water as flat see-through planes (C-236): one per Core/Terrain
-- water rectangle (they run on under the shore, where the ground hides
-- them), and under each a darker plane DEPTH studs down for every depth
-- step: the ground covers them where the water is shallower, so deep water
-- reads darker, as terrain water did.
local WATER_TOP = { color = Color3.fromRGB(58, 104, 118), transparency = 0.32, material = Enum.Material.Glass }
local WATER_DEPTHS = { { depth = 2.5, color = Color3.fromRGB(34, 70, 86), transparency = 0.55 }, { depth = 7, color = Color3.fromRGB(18, 40, 56), transparency = 0.45 } }
local MAX_PART = 2048 -- studs: a Part's largest side
-- Ripples: a tileable pattern of thin bright crests drawn once into an
-- EditableImage, laid twice on each surface and scrolled two ways on
-- endless tweens (an offset of one whole tile loops seamlessly). Without
-- EditableImage (an experience that doesn't allow it, C-214) the water is
-- plain.
local RIPPLE_SIZE = 256
-- (whole tiles per loop in both directions, or the loop would jump)
local RIPPLES = { { tile = 56, seconds = 34, dx = 1, dz = 1, transparency = 0.55 }, { tile = 34, seconds = 21, dx = -1, dz = 0, transparency = 0.7 } }
local rippleContent: any = nil
local rippleTried = false
local function ripples(): any
	if rippleTried then
		return rippleContent
	end
	rippleTried = true
	local ok, content = pcall(function()
		local AssetService = game:GetService("AssetService")
		local img = (AssetService :: any):CreateEditableImage({ Size = Vector2.new(RIPPLE_SIZE, RIPPLE_SIZE) })
		local buf = buffer.create(RIPPLE_SIZE * RIPPLE_SIZE * 4)
		-- whole-number wave vectors: the pattern tiles
		local waves = { { 3, 1, 0.0 }, { -2, 3, 1.7 }, { 1, -4, 3.1 }, { 5, 2, 4.4 }, { -4, -3, 2.2 } }
		for y = 0, RIPPLE_SIZE - 1 do
			for x = 0, RIPPLE_SIZE - 1 do
				local u, v = x / RIPPLE_SIZE, y / RIPPLE_SIZE
				local sum = 0
				for _, w in waves do
					sum += math.sin(2 * math.pi * (w[1] * u + w[2] * v) + w[3])
				end
				-- crests: thin bright lines where the sum crosses zero
				local crest = math.clamp(1 - math.abs(sum) / 0.6, 0, 1) ^ 2
				local o = (y * RIPPLE_SIZE + x) * 4
				buffer.writeu8(buf, o, 255)
				buffer.writeu8(buf, o + 1, 255)
				buffer.writeu8(buf, o + 2, 255)
				buffer.writeu8(buf, o + 3, math.floor(crest * 200))
			end
		end
		img:WritePixelsBuffer(Vector2.zero, img.Size, buf)
		return (Content :: any).fromObject(img)
	end)
	rippleContent = if ok then content else nil
	return rippleContent
end
local TweenService = game:GetService("TweenService")
local function addRipples(p: BasePart, x0: number, z0: number)
	local content = ripples()
	if content == nil then
		return
	end
	for _, r in RIPPLES do
		local t = Instance.new("Texture")
		t.Face = Enum.NormalId.Top
		;(t :: any).ColorMapContent = content
		t.StudsPerTileU, t.StudsPerTileV = r.tile, r.tile
		t.Transparency = r.transparency
		-- tiles counted from the world origin, so neighbouring planes meet without a seam
		local u0, v0 = x0 % r.tile, z0 % r.tile
		t.OffsetStudsU, t.OffsetStudsV = u0, v0
		t.Parent = p
		local goal = { OffsetStudsU = u0 + r.dx * r.tile, OffsetStudsV = v0 + r.dz * r.tile }
		TweenService:Create(t, TweenInfo.new(r.seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), goal):Play()
	end
end
local function buildWater(layers: Layers.Layers, folder: Folder): number
	local water = Instance.new("Folder")
	water.Name = "Water"
	local n = 0
	local function plane(name: string, x0: number, z0: number, x1: number, z1: number, y: number, color: Color3, transparency: number, material: Enum.Material): { Part }
		-- (split along a side longer than a Part can be)
		local made = {}
		for px = x0, x1 - 1e-6, MAX_PART do
			for pz = z0, z1 - 1e-6, MAX_PART do
				local sx, sz = math.min(MAX_PART, x1 - px), math.min(MAX_PART, z1 - pz)
				local p = newPart(name, Vector3.new(sx, 0.2, sz), CFrame.new(px + sx / 2, y - 0.1, pz + sz / 2), color)
				p.Material = material
				p.Transparency = transparency
				p.CastShadow = false
				p.CanQuery = false -- clicks march the sim's heights (C-209)
				p.Parent = water
				n += 1
				table.insert(made, p)
			end
		end
		return made
	end
	for _, r in CoreTerrain.waterRects(layers) do
		for _, p in plane("Surface", r.x0, r.z0, r.x1, r.z1, r.level, WATER_TOP.color, WATER_TOP.transparency, WATER_TOP.material) do
			addRipples(p, p.Position.X - p.Size.X / 2, p.Position.Z - p.Size.Z / 2)
		end
		for _, layer in WATER_DEPTHS do
			plane("Depth", r.x0, r.z0, r.x1, r.z1, r.level - layer.depth, layer.color, layer.transparency, Enum.Material.SmoothPlastic)
		end
	end
	water.Parent = folder
	return n
end

-- Builds the ground for `layers` and returns its folder (replacing an old
-- one). A terrain build continues in its own thread (it yields).
-- Houses over a map's "house" cells: each connected group of house cells
-- becomes one brick block of the cells' height with a slate roof (C-66).
local HOUSE_WALL = Color3.fromRGB(150, 118, 92)
local HOUSE_ROOF = Color3.fromRGB(78, 74, 72)
local function buildHouses(layers: Layers.Layers, feature: CoreTerrain.Feature, folder: Folder): number
	local g = layers.grid
	local cell = Grid.CELL_SIZE
	local seen: { [number]: boolean } = {}
	local n = 0
	for cz = 0, g.cellsZ - 1 do
		for cx = 0, g.cellsX - 1 do
			local i = g:index(cx, cz)
			if seen[i] or feature(cx, cz) ~= "house" then
				continue
			end
			-- flood the group: its cell bounds and top
			local x0, x1, z0, z1, top, base = cx, cx, cz, cz, -math.huge, math.huge
			local stack = { { cx, cz } }
			seen[i] = true
			while #stack > 0 do
				local c = table.remove(stack) :: { number }
				x0, x1, z0, z1 = math.min(x0, c[1]), math.max(x1, c[1]), math.min(z0, c[2]), math.max(z1, c[2])
				top = math.max(top, Layers.getHeight(layers, g:index(c[1], c[2])))
				for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nx, nz = c[1] + d[1], c[2] + d[2]
					if nx >= 0 and nz >= 0 and nx < g.cellsX and nz < g.cellsZ then
						local j = g:index(nx, nz)
						if not seen[j] then
							if feature(nx, nz) == "house" then
								seen[j] = true
								table.insert(stack, { nx, nz })
							else
								base = math.min(base, Layers.getHeight(layers, j)) -- the street around it
							end
						end
					end
				end
			end
			if base == math.huge then
				base = top - 8
			end
			local sx, sz = (x1 - x0 + 1) * cell, (z1 - z0 + 1) * cell
			local wallH = math.max(top - base, 4)
			local mx, mz = g.originX + x0 * cell + sx / 2, g.originZ + z0 * cell + sz / 2
			local walls = newPart("House", Vector3.new(sx, wallH + 1, sz), CFrame.new(mx, base - 1 + (wallH + 1) / 2, mz), HOUSE_WALL)
			walls.Material = Enum.Material.Brick
			walls.Parent = folder
			-- a pitched roof: two wedges along the longer side
			local ridge = math.min(sx, sz) * 0.35
			local alongX = sx >= sz
			local len, half = if alongX then sx else sz, (if alongX then sz else sx) / 2
			for side = -1, 1, 2 do
				local w = Instance.new("WedgePart")
				w.Name = "Roof"
				w.Anchored, w.CanCollide, w.CanTouch, w.CanQuery = true, false, false, false
				w.Material = Enum.Material.Slate
				w.Color = HOUSE_ROOF
				w.Size = Vector3.new(len + 1, ridge, half + 0.5)
				local y = base + wallH + ridge / 2
				local cf = if alongX
					then CFrame.new(mx, y, mz + side * half / 2) * CFrame.Angles(0, if side > 0 then 0 else math.pi, 0)
					else CFrame.new(mx + side * half / 2, y, mz) * CFrame.Angles(0, if side > 0 then math.pi / 2 else -math.pi / 2, 0)
				w.CFrame = cf
				w.Parent = folder
			end
			n += 1
		end
	end
	return n
end

-- `mapId`: a named map with baked mesh ground (Core/GroundMeshes, C-167)
-- draws its tiles; the water is mesh planes (or terrain water, C-236).
function Ground.build(layers: Layers.Layers, mode: ("terrain" | "parts")?, feature: CoreTerrain.Feature?, mapId: string?): Folder
	mode = mode or Ground.MODE
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	local last: { [string]: any } = { mode = mode, ground = mode } -- `ground` stays: Terrain's build stats bring their own `mode`
	Ground.last = last
	local t0 = os.clock()
	local baked = if mode ~= "parts" then GroundMeshes.entryFor(mapId) else nil
	local meshWater = mode ~= "parts" and Ground.WATER == "mesh"
	if meshWater then
		last.water = buildWater(layers, folder)
	end
	if baked then
		last.ground = "mesh"
		last.parts = 0
		if meshWater then
			RenderTerrain.clear()
		end
		task.spawn(function()
			if not meshWater then
				RenderTerrain.build(layers, feature, true) -- the water
			end
			local stats = MeshGround.build(baked :: any, folder)
			if Ground.last == last then
				last.mesh = stats
				last.seconds = os.clock() - t0
			end
		end)
	elseif mode == "parts" then
		RenderTerrain.clear()
		last.parts = buildParts(layers, folder)
		last.seconds = os.clock() - t0
	else
		last.parts = 0
		task.spawn(function()
			local stats = RenderTerrain.build(layers, feature, false, meshWater)
			if Ground.last == last and stats then
				for k, v in stats do
					last[k] = v
				end
			end
		end)
	end

	if feature then
		last.houses = buildHouses(layers, feature, folder)
	end
	folder.Parent = workspace
	return folder
end

return Ground

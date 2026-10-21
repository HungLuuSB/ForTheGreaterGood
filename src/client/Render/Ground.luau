--!strict
-- Draws a map's layers for maps without baked place terrain (guide 5.4):
-- the ground and water, and a gold plate on each supply deposit
-- (workspace.Map). Two ways to draw the ground (C-28):
--   "terrain"  Roblox Terrain voxels on Core/Terrain's smooth surface
--              (Render/Terrain; the default: see C-28 for the measurements)
--   "parts"    anchored columns, one height per cell: cells merge into
--              rectangles of equal height inside 8 × 8-cell blocks, so a flat
--              map is a checkerboard of 64-stud tiles
-- Units are placed on the smooth surface either way (World.groundY).
-- Materials follow the sim's terrain types, or a hand-made map's features
-- (`feature`, e.g. Normandy.feature: hedgerows, roads, bridges); its house
-- cells get brick houses with slate roofs as parts (C-66).

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local CoreTerrain = require("../Core/Terrain")
local RenderTerrain = require("./Terrain")

local Ground = {}

Ground.MODE = "terrain" :: "terrain" | "parts"
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

function Ground.build(layers: Layers.Layers, mode: ("terrain" | "parts")?, feature: CoreTerrain.Feature?): Folder
	mode = mode or Ground.MODE
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Map"
	local g = layers.grid
	local cell = Grid.CELL_SIZE
	local last: { [string]: any } = { mode = mode }
	Ground.last = last
	local t0 = os.clock()
	if mode == "parts" then
		RenderTerrain.clear()
		last.parts = buildParts(layers, folder)
		last.seconds = os.clock() - t0
	else
		last.parts = 0
		task.spawn(function()
			local stats = RenderTerrain.build(layers, feature)
			if Ground.last == last and stats then
				for k, v in stats do
					last[k] = v
				end
			end
		end)
	end

	-- supply deposits: a gold plate on each deposit cell, where an extractor
	-- must stand (brighter for richer deposits)
	for cz = 0, g.cellsZ - 1 do
		for cx = 0, g.cellsX - 1 do
			local i = g:index(cx, cz)
			local supply = Layers.getSupply(layers, i)
			if supply > 0 then
				-- over the drawn ground, which may tilt slightly under a deposit on a slope
				local h = Layers.getHeight(layers, i) + Layers.getWater(layers, i) + CoreTerrain.DEPOSIT_LIFT
				local x0, z0 = g.originX + cx * cell, g.originZ + cz * cell
				local plate = newPart("Deposit", Vector3.new(cell - 1.2, 0.3, cell - 1.2), CFrame.new(x0 + cell / 2, h - 0.1, z0 + cell / 2), Color3.fromRGB(235, 190, 60):Lerp(Color3.fromRGB(255, 230, 120), math.clamp((supply - 3) / 4, 0, 1)))
				plate.Material = Enum.Material.Neon
				plate.Transparency = 0.15
				plate.CanQuery = false
				plate:SetAttribute("Supply", supply)
				plate.Parent = folder
			end
		end
	end
	if feature then
		last.houses = buildHouses(layers, feature, folder)
	end
	folder.Parent = workspace
	return folder
end

return Ground

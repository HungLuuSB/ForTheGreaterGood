--!strict
-- Fog of war (C-100, BAR style; replaces the C-32 point-light fog and its
-- plates): normal daylight and atmosphere everywhere, and a "fog blanket"
-- darkening what the team can't see. The blanket is a mesh draped over the
-- terrain, a vertex every STEP grid cells (a sensor cell) LIFT studs above
-- the highest of the sim's ground (or water) and the drawn terrain within
-- half a step of it, in chunks of CHUNK × CHUNK vertex steps. EditableMesh
-- memory has a per-device budget that a mesh can't give back while it is
-- shown (the MeshPart needs it alive), and the Studio client ran out after
-- about 7,600 vertices at a vertex per grid cell; this way a 128-cell map is
-- 4 chunks of 33 × 33 vertices. All chunks show one
-- EditableImage with a pixel per grid cell (Core/FogBlanket: visible clear,
-- explored grey, never seen dark) as their TextureContent, by UVs. A
-- MeshPart blends its texture's alpha only when the part itself is a little
-- transparent (Transparency 0 shows the part's colour under clear pixels),
-- so it is at TRANSPARENCY. The texture's smoothing softens the edges.
-- (A SurfaceAppearance in transparency mode also works but game scripts
-- can't set its ColorMapContent: Plugin capability.) The minimap shows the
-- same image (Image API content can be shared).
--
-- Vision is read and changed pixels uploaded at most at the sim rate
-- (UPDATE); only the rectangle that changed is written. Needs the
-- experience's Mesh / Image APIs setting (Game Settings, Security); without
-- it (or with the device's editable-memory budget used up) there is no
-- blanket and `stats.mode` says why. Client-side only.

local AssetService = game:GetService("AssetService")

local Grid = require("@shared/Grid/Grid")
local Core = require("../Core/FogBlanket")
local Vision = require("../Core/Vision")
local World = require("../Core/World")

local FogBlanket = {}

FogBlanket.ENABLED = true -- the settings menu's "Fog of war"
FogBlanket.UPDATE = 1 / 15 -- seconds between vision reads and uploads (the sim rate)
FogBlanket.STEP = 2 -- grid cells between vertices
FogBlanket.CHUNK = 32 -- vertex steps per chunk side
FogBlanket.LIFT = 1 -- studs over the highest ground near a vertex
FogBlanket.TRANSPARENCY = 0.02 -- the chunks' own (see above)
FogBlanket.frozen = false -- debug: no updates (a test pattern stays)

export type FogBlanket = {
	core: Core.Blanket?,
	vision: Vision.Vision?,
	image: EditableImage?,
	content: Content?,
	folder: Folder,
	parts: { MeshPart },
	meshes: { EditableMesh },
	building: boolean,
	acc: number,
	stats: { mode: string, chunks: number, triangles: number, pixels: number, uploads: number, written: number, ms: number, msMax: number, buildMs: number, imageBytes: number },
}

function FogBlanket.new(): FogBlanket
	local folder = Instance.new("Folder")
	folder.Name = "FogBlanket"
	folder.Parent = workspace
	return {
		core = nil,
		vision = nil,
		image = nil,
		content = nil,
		folder = folder,
		parts = {},
		meshes = {},
		building = false,
		acc = 0,
		stats = { mode = "none", chunks = 0, triangles = 0, pixels = 0, uploads = 0, written = 0, ms = 0, msMax = 0, buildMs = 0, imageBytes = 0 },
	}
end

local function clear(f: FogBlanket)
	for _, p in f.parts do
		p:Destroy()
	end
	for _, m in f.meshes do
		m:Destroy()
	end
	table.clear(f.parts)
	table.clear(f.meshes)
	if f.image then
		f.image:Destroy()
	end
	f.image, f.content, f.core, f.vision = nil, nil, nil, nil
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- The ground at a world point: the sim's ground or water, or the drawn
-- terrain, whichever is higher.
local function groundAt(world: World.World, x: number, z: number): number
	local y = World.groundY(world, x, z, true)
	local hit = workspace:Raycast(Vector3.new(x, y + 400, z), Vector3.new(0, -800, 0), terrainOnly)
	return if hit then math.max(y, hit.Position.Y) else y
end

-- The blanket's height at a vertex: over the highest ground within half a
-- vertex step (`r` studs), so ridges between vertices stay under it.
local function heightAt(world: World.World, x: number, z: number, r: number): number
	local y = -math.huge
	for dz = -1, 1 do
		for dx = -1, 1 do
			y = math.max(y, groundAt(world, x + dx * r, z + dz * r))
		end
	end
	return y + FogBlanket.LIFT
end

-- One chunk's mesh: vertex steps [cx0, cx1) × [cz0, cz1), in world space,
-- UVs onto the whole image (u east, v south) kept half a pixel in from its
-- edges (no wrap-around bleed).
local function buildChunk(f: FogBlanket, world: World.World, grid: any, cx0: number, cz0: number, cx1: number, cz1: number)
	local em = (AssetService :: any):CreateEditableMesh()
	if em == nil then
		f.stats.mode = "no editable-mesh memory"
		return
	end
	local cell = grid.sizeX / grid.cellsX * FogBlanket.STEP -- studs between vertices
	local ids, uvs = {}, {}
	local W, D = grid.cellsX, grid.cellsZ
	local cols = cx1 - cx0 + 1
	for j = cz0, cz1 do
		for i = cx0, cx1 do
			local x, z = grid.originX + i * cell, grid.originZ + j * cell
			local p = Vector3.new(x, heightAt(world, x, z, cell / 2), z)
			local k = (j - cz0) * cols + (i - cx0)
			ids[k] = em:AddVertex(p)
			local u, v = (x - grid.originX) / grid.sizeX, (z - grid.originZ) / grid.sizeZ
			uvs[k] = em:AddUV(Vector2.new(math.clamp(u, 0.5 / W, 1 - 0.5 / W), math.clamp(v, 0.5 / D, 1 - 0.5 / D)))
		end
	end
	local tris = 0
	for j = 0, cz1 - cz0 - 1 do
		for i = 0, cx1 - cx0 - 1 do
			local a, b, c, d = j * cols + i, j * cols + i + 1, (j + 1) * cols + i + 1, (j + 1) * cols + i
			local f1 = em:AddTriangle(ids[a], ids[c], ids[b])
			em:SetFaceUVs(f1, { uvs[a], uvs[c], uvs[b] })
			local f2 = em:AddTriangle(ids[a], ids[d], ids[c])
			em:SetFaceUVs(f2, { uvs[a], uvs[d], uvs[c] })
			tris += 2
		end
	end
	local ok, part = pcall(function()
		return (AssetService :: any):CreateMeshPartAsync((Content :: any).fromObject(em))
	end)
	if not ok or part == nil then
		em:Destroy()
		f.stats.mode = `mesh failed: {part}`
		return
	end
	local mp = part :: MeshPart
	mp.Name = "Chunk"
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	mp.CanTouch = false
	mp.CastShadow = false
	mp.Material = Enum.Material.Fabric -- matte: no sun glints on slopes (and the map may have no sun at all)
	mp.Reflectance = 0
	mp.Transparency = FogBlanket.TRANSPARENCY
	mp.Position = Vector3.zero -- a MeshPart from an EditableMesh keeps the mesh's origin: the vertices are in world space
	;(mp :: any).TextureContent = f.content
	mp.Parent = f.folder
	table.insert(f.parts, mp)
	table.insert(f.meshes, em) -- kept: the MeshPart shows it
	f.stats.chunks += 1
	f.stats.triangles += tris
end

-- A new map: the image and the draped chunks (built in their own thread:
-- making a MeshPart yields).
function FogBlanket.setMap(f: FogBlanket, world: World.World, layers: any)
	clear(f)
	local grid = layers.grid
	f.stats.chunks, f.stats.triangles = 0, 0
	local ok, img = pcall(function()
		return (AssetService :: any):CreateEditableImage({ Size = Vector2.new(grid.cellsX, grid.cellsZ) })
	end)
	if not ok or img == nil then
		f.stats.mode = if ok then "no editable-image memory" else `images unavailable: {img}`
		return
	end
	f.image = img
	f.content = (Content :: any).fromObject(img)
	f.core = Core.new(grid.cellsX, grid.cellsZ, Grid.SENSOR_CELL_SIZE // Grid.CELL_SIZE)
	f.vision = Vision.new(grid)
	f.stats.pixels = grid.cellsX * grid.cellsZ
	f.stats.imageBytes = f.stats.pixels * 4
	f.stats.mode = "building"
	f.building = true
	task.spawn(function()
		local t0 = os.clock()
		local C = FogBlanket.CHUNK
		local vx, vz = math.ceil(grid.cellsX / FogBlanket.STEP), math.ceil(grid.cellsZ / FogBlanket.STEP)
		for cz = 0, vz - 1, C do
			for cx = 0, vx - 1, C do
				if f.image ~= img then
					return -- a newer map
				end
				buildChunk(f, world, grid, cx, cz, math.min(cx + C, vx), math.min(cz + C, vz))
			end
		end
		f.stats.buildMs = (os.clock() - t0) * 1000
		if f.stats.mode == "building" then
			f.stats.mode = "blanket"
		end
		f.building = false
	end)
end

-- The image for the minimap (nil until made).
function FogBlanket.content(f: FogBlanket): Content?
	return f.content
end

-- Per frame. `show`: false for spectators (no fog) or when switched off.
function FogBlanket.step(f: FogBlanket, world: World.World, dt: number, show: boolean)
	local on = show and FogBlanket.ENABLED
	local parent = if on then workspace else nil
	if f.folder.Parent ~= parent then
		f.folder.Parent = parent
	end
	local core, v, img = f.core, f.vision, f.image
	if core == nil or v == nil or img == nil or FogBlanket.frozen then
		return
	end
	f.acc += dt
	if f.acc < FogBlanket.UPDATE then
		return
	end
	local t0 = os.clock()
	local elapsed = f.acc
	f.acc = 0
	if Vision.update(v, world) or core.visionVersion < 0 then
		Core.apply(core, v)
	end
	local r = Core.step(core, elapsed)
	if r then
		img:WritePixelsBuffer(Vector2.new(r.x, r.y), Vector2.new(r.w, r.h), Core.region(core, r))
		f.stats.uploads += 1
		f.stats.written += r.w * r.h
	end
	local ms = (os.clock() - t0) * 1000
	f.stats.ms = ms
	f.stats.msMax = math.max(f.stats.msMax, ms)
end

return FogBlanket

--!strict
-- Fog of war in 3D (C-32) from Core/Vision and Core/Fog, two ways by zoom:
--   * near (camera within LIGHT_MAX_ZOOM): the scene is darkened (a
--     ColorCorrection and dimmer Lighting, client-side only) and a point
--     light per 32-stud light cell lights what the team sees, its brightness
--     fading toward the cell's share in sight (after Astra Force's light
--     fog);
--   * far: Roblox stops rendering point lights a few hundred studs from the
--     camera, so the Lighting goes back to normal and dark translucent
--     plates cover the unseen cells instead (rebuilt per changed block,
--     within a frame budget).
-- Vision updates UPDATE times a second. Looks are placeholders ("Needs my
-- review").

local Lighting = game:GetService("Lighting")

local Fog = require("../Core/Fog")
local Terrain = require("../Core/Terrain")
local Vision = require("../Core/Vision")
local World = require("../Core/World")

local FogOfWar = {}

FogOfWar.LIGHT_MAX_ZOOM = 330 -- camera distance: lights up to here (back at 300)
FogOfWar.LIGHT_BACK_ZOOM = 300
FogOfWar.UPDATE = 0.25 -- seconds between vision updates
FogOfWar.LIGHT_RANGE = 40
FogOfWar.LIGHT_HEIGHT = 12 -- studs over the ground
FogOfWar.LIGHT_BRIGHTNESS = 1.4
FogOfWar.LIGHT_COLOR = Color3.fromRGB(255, 246, 228)
FogOfWar.FADE_SECONDS = 0.4 -- a light goes from off to full in this long
FogOfWar.PLATE_COLOR = Color3.fromRGB(8, 10, 18)
FogOfWar.PLATE_TRANSPARENCY = 0.4
FogOfWar.PLATE_OVERLAP = 0.3 -- studs added to each plate's length and width (more shows as darker seams)
FogOfWar.PLATE_THICKNESS = 1.2
FogOfWar.REBUILD_BUDGET = 0.002 -- seconds of plate rebuilding per frame
-- the darkened scene for the light fog (Lighting values are restored when it ends)
FogOfWar.DARK = { Brightness = 0.6, Ambient = Color3.fromRGB(30, 33, 42), OutdoorAmbient = Color3.fromRGB(40, 44, 56) }
FogOfWar.CC = { Brightness = -0.05, Contrast = 0.08, Saturation = -0.2, TintColor = Color3.fromRGB(215, 222, 240) }

type Light = { part: Part, light: PointLight, cur: number, target: number }

export type FogOfWar = {
	layers: any?,
	vision: Vision.Vision?,
	mode: "lights" | "overlay",
	nextUpdate: number,
	lights: { [number]: Light }, -- light cell index → its light (made the first time it's lit)
	fading: { [number]: boolean }, -- lights whose brightness still moves
	blocks: { [number]: { BasePart } }, -- block index → its plates
	dirty: { [number]: boolean }, -- blocks to rebuild
	lightFolder: Folder,
	plateFolder: Folder,
	cc: ColorCorrectionEffect,
	saved: { [string]: any }?, -- Lighting before the light fog darkened it
	stats: { plates: number, lights: number, lit: number, rebuildMs: number },
}

function FogOfWar.new(): FogOfWar
	local lightFolder = Instance.new("Folder")
	lightFolder.Name = "FogLights"
	lightFolder.Parent = workspace
	local plateFolder = Instance.new("Folder")
	plateFolder.Name = "FogPlates"
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FtggFog"
	cc.Enabled = false
	for k, v in FogOfWar.CC do
		(cc :: any)[k] = v
	end
	cc.Parent = Lighting
	return {
		layers = nil,
		vision = nil,
		mode = "overlay",
		nextUpdate = 0,
		lights = {},
		fading = {},
		blocks = {},
		dirty = {},
		lightFolder = lightFolder,
		plateFolder = plateFolder,
		cc = cc,
		saved = nil,
		stats = { plates = 0, lights = 0, lit = 0, rebuildMs = 0 },
	}
end

-- A new map: everything starts over.
function FogOfWar.setMap(f: FogOfWar, layers: any)
	f.layers = layers
	f.vision = Vision.new(layers.grid)
	f.lightFolder:ClearAllChildren()
	f.plateFolder:ClearAllChildren()
	table.clear(f.lights)
	table.clear(f.fading)
	table.clear(f.blocks)
	table.clear(f.dirty)
	local bw, bd = Fog.blocks(f.vision :: Vision.Vision)
	for b = 0, bw * bd - 1 do
		f.dirty[b] = true -- every block starts covered
	end
	f.nextUpdate = 0
end

local function darken(f: FogOfWar, on: boolean)
	if on and f.saved == nil then
		local saved = {}
		for k, v in FogOfWar.DARK do
			saved[k] = (Lighting :: any)[k]
			;(Lighting :: any)[k] = v
		end
		f.saved = saved
	elseif not on and f.saved then
		for k, v in f.saved :: { [string]: any } do
			(Lighting :: any)[k] = v
		end
		f.saved = nil
	end
	f.cc.Enabled = on
end

local function lightAt(f: FogOfWar, v: Vision.Vision, index: number, lw: number): Light
	local l = f.lights[index]
	if l == nil then
		local lx, lz = index % lw, index // lw
		local x, z = Fog.lightCenter(v, lx, lz)
		local part = Instance.new("Part")
		part.Name = "FogLight"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = Vector3.new(x, Terrain.surfaceY(f.layers, x, z) + FogOfWar.LIGHT_HEIGHT, z)
		local light = Instance.new("PointLight")
		light.Range = FogOfWar.LIGHT_RANGE
		light.Color = FogOfWar.LIGHT_COLOR
		light.Shadows = false
		light.Brightness = 0
		light.Enabled = false
		light.Parent = part
		part.Parent = f.lightFolder
		l = { part = part, light = light, cur = 0, target = 0 }
		f.lights[index] = l
		f.stats.lights += 1
	end
	return l :: Light
end

local function plateCFrame(p: Fog.Plate): (CFrame, Vector3)
	local right = Vector3.new(1, p.slopeX, 0).Unit
	local back = Vector3.new(0, p.slopeZ, 1).Unit
	local up = back:Cross(right).Unit
	local cf = CFrame.fromMatrix(Vector3.new(p.x, p.y, p.z), right, up)
	-- overlap the neighbors and give the plate depth, so no ground shows
	-- between plates at different heights when seen at an angle
	local o = FogOfWar.PLATE_OVERLAP
	return cf, Vector3.new(p.sx * math.sqrt(1 + p.slopeX * p.slopeX) + o, FogOfWar.PLATE_THICKNESS, p.sz * math.sqrt(1 + p.slopeZ * p.slopeZ) + o)
end

local function rebuildBlock(f: FogOfWar, v: Vision.Vision, b: number, bw: number)
	for _, part in f.blocks[b] or {} do
		part:Destroy()
	end
	local parts = {}
	for _, p in Fog.blockPlates(v, f.layers, b % bw, b // bw) do
		local part = Instance.new("Part")
		part.Name = "Fog"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = FogOfWar.PLATE_COLOR
		part.Transparency = FogOfWar.PLATE_TRANSPARENCY
		local cf, size = plateCFrame(p)
		part.Size = size
		part.CFrame = cf
		part.Parent = f.plateFolder
		table.insert(parts, part)
	end
	f.stats.plates += #parts - #(f.blocks[b] or {})
	f.blocks[b] = parts
end

-- Per frame: vision (at UPDATE), the mode by camera distance, light fades,
-- plate rebuilds. Call before the frame clears world.died.
function FogOfWar.step(f: FogOfWar, world: World.World, now: number, dt: number, cameraDistance: number)
	local v = f.vision
	if v == nil or f.layers == nil then
		return
	end
	local lw = Fog.lightSize(v)
	local bw = Fog.blocks(v)
	if now >= f.nextUpdate then
		f.nextUpdate = now + FogOfWar.UPDATE
		if Vision.update(v, world) then
			local touched: { [number]: boolean } = {}
			for _, cell in v.changed do
				local cx, cz = cell % v.width, cell // v.width
				local k = Fog.LIGHT_CELL // 16
				touched[(cz // k) * lw + cx // k] = true
				local bx, bz = Fog.blockOf(v, cell)
				f.dirty[bz * bw + bx] = true
			end
			for index in touched do
				local level = Fog.lightLevel(v, index % lw, index // lw)
				local l = if level > 0 then lightAt(f, v, index, lw) else f.lights[index]
				if l then
					l.target = level * FogOfWar.LIGHT_BRIGHTNESS
					f.fading[index] = true
				end
			end
		end
	end

	local wantLights = if f.mode == "lights" then cameraDistance <= FogOfWar.LIGHT_MAX_ZOOM else cameraDistance <= FogOfWar.LIGHT_BACK_ZOOM
	local mode = if wantLights then "lights" else "overlay"
	if mode ~= f.mode then
		f.mode = mode
		darken(f, mode == "lights")
		f.plateFolder.Parent = if mode == "overlay" then workspace else nil
		f.lightFolder.Parent = if mode == "lights" then workspace else nil
	end

	if mode == "lights" then
		local step = FogOfWar.LIGHT_BRIGHTNESS / FogOfWar.FADE_SECONDS * dt
		for index in f.fading do
			local l = f.lights[index]
			local d = l.target - l.cur
			l.cur = if math.abs(d) <= step then l.target else l.cur + (if d > 0 then step else -step)
			l.light.Brightness = l.cur
			l.light.Enabled = l.cur > 0
			if l.cur == l.target then
				f.fading[index] = nil
			end
		end
	else
		local t0 = os.clock()
		for b in f.dirty do
			rebuildBlock(f, v, b, bw)
			f.dirty[b] = nil
			if os.clock() - t0 > FogOfWar.REBUILD_BUDGET then
				break
			end
		end
		f.stats.rebuildMs = (os.clock() - t0) * 1000
	end
	local lit = 0
	for _, l in f.lights do
		if l.cur > 0 then
			lit += 1
		end
	end
	f.stats.lit = lit
end

return FogOfWar

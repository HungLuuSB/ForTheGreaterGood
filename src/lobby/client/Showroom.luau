--!strict
-- The unit encyclopedia's 3D showroom (L-18): the game's own unit models
-- (the client's Render/Models, read-only: the BAR mesh when it's approved
-- and built, else the blockout) on a place picked for the unit, under the
-- lobby's light. Places, built once and far from the menu's battle:
--   pad    a concrete pad with markings and lamps (ground units)
--   field  a patch of grass and dirt (structures)
--   water  open water (ships and water structures; ships at their waterline)
--   shore  sand running into the water (amphibious units)
--   underwater  deep water over a sandy seabed, the camera under the
--          surface: submarines float mid-water, amphibious units drive on
--          the seabed, ships show their hulls from below
--   sky    a runway far below (aircraft hover, bobbing)
-- "auto" picks by the unit (client-B's Core/PortraitStage, as the build
-- menu's portraits do; submarines and amphibious units go underwater). The camera orbits the unit: it turns by itself
-- (turntable), the mouse drags it round and the wheel zooms. Compare puts
-- several units side by side. While the showroom is open the battle
-- behind the menu is away (Scene.setAway). Units play their own piece
-- animations, and Fire puts up a firing range for their weapons (Range).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Models = require("@client/Render/Models")
local MeshModels = require("@client/Render/MeshModels")
local PortraitStage = require("@client/Core/PortraitStage")
local Range = require("./Range")
local Scene = require("./Scene")

local Showroom = {}

local ORIGIN = Vector3.new(-6000, 0, 3000)
local FOV = 40
local GAP = 8 -- studs between compared units
local TEAM_TAG = "TeamColor"

Showroom.ORDER = Color3.fromRGB(64, 132, 230)
Showroom.CHAOS = Color3.fromRGB(222, 70, 62)

Showroom.PLACES = { "auto", "pad", "field", "water", "shore", "underwater", "sky" }
local CENTERS: { [string]: Vector3 } = {
	pad = ORIGIN,
	field = ORIGIN + Vector3.new(600, 0, 0),
	water = ORIGIN + Vector3.new(1200, 0, 0),
	shore = ORIGIN + Vector3.new(1800, 0, 0),
	sky = ORIGIN + Vector3.new(2400, 0, 0),
	underwater = ORIGIN + Vector3.new(3000, 0, 0),
}
local DEPTH = 44 -- underwater: the seabed this far below the surface

local folder = Instance.new("Folder")
folder.Name = "LobbyShowroom"
local stagesFolder = Instance.new("Folder")
stagesFolder.Name = "Places"
stagesFolder.Parent = folder
local unitsFolder = Instance.new("Folder")
unitsFolder.Name = "Units"
unitsFolder.Parent = folder

local built: { [string]: boolean } = {}
local open = false
local defs: any = nil

type Shown = { id: number, def: any, color: Color3, model: Model?, base: CFrame, size: Vector3, kind: string }
local nextId = 0
local firing = false -- the firing range is up
local shown: { Shown } = {}
local place = "auto"
local placeNow = "pad" -- what "auto" resolved to
local turntable = true
local lightMode = "dusk"

-- camera
local yaw, pitch = 0.65, 0.32
local zoom = 1
local fitDistance = 30
local target = ORIGIN
local region: GuiObject? = nil -- the part of the screen the unit should sit in
local dragging = false
local lastMouse = Vector2.zero
local idleSince = 0

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or stagesFolder
	return p
end

local function rng(a: number, b: number): number
	return a + math.random() * (b - a)
end

-- places --------------------------------------------------------------------

local function far(c: Vector3, color: Color3)
	-- low hills on the horizon behind the place
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		part({
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng(120, 220),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 420, -60, math.sin(a) * 420)),
			Material = Enum.Material.Ground,
			Color = color,
		})
	end
end

local function buildPad(c: Vector3)
	part({ Name = "Ground", Size = Vector3.new(700, 2, 700), CFrame = CFrame.new(c + Vector3.new(0, -1.5, 0)), Material = Enum.Material.Ground, Color = Color3.fromRGB(70, 66, 58) })
	part({ Name = "Pad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 60, 60), CFrame = CFrame.new(c + Vector3.new(0, -0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Concrete, Color = Color3.fromRGB(120, 120, 116) })
	-- a hazard ring and four bars
	part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 56, 56), CFrame = CFrame.new(c + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(214, 172, 54) })
	part({ Name = "Inner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.14, 52, 52), CFrame = CFrame.new(c + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), Material = Enum.Material.Concrete, Color = Color3.fromRGB(116, 116, 112) })
	for i = 0, 3 do
		local a = i * math.pi / 2
		part({ Name = "Mark", Size = Vector3.new(1.2, 0.1, 8), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 22, 0.06, math.sin(a) * 22)) * CFrame.Angles(0, -a, 0), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 230, 224) })
		local lampAt = c + Vector3.new(math.cos(a + math.pi / 4) * 46, 0, math.sin(a + math.pi / 4) * 46)
		part({ Name = "Post", Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(lampAt + Vector3.new(0, 4.5, 0)), Material = Enum.Material.Metal, Color = Color3.fromRGB(50, 52, 56) })
		local lamp = part({ Name = "Lamp", Size = Vector3.new(1.4, 0.6, 1.4), CFrame = CFrame.new(lampAt + Vector3.new(0, 9.2, 0)), Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 226, 170) })
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 80
		light.Range = 40
		light.Brightness = 2
		light.Color = Color3.fromRGB(255, 220, 170)
		light.Parent = lamp
	end
	far(c, Color3.fromRGB(86, 76, 62))
end

local function buildField(c: Vector3)
	part({ Name = "Ground", Size = Vector3.new(700, 2, 700), CFrame = CFrame.new(c + Vector3.new(0, -1, 0)), Material = Enum.Material.Grass, Color = Color3.fromRGB(84, 104, 58) })
	part({ Name = "Dirt", Size = Vector3.new(70, 0.2, 60), CFrame = CFrame.new(c + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0.3, 0), Material = Enum.Material.Ground, Color = Color3.fromRGB(110, 92, 68) })
	for _ = 1, 40 do
		local a, d = rng(0, math.pi * 2), rng(55, 220)
		local s = rng(1.5, 6)
		part({
			Name = if math.random() < 0.5 then "Rock" else "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s * rng(1, 1.8), s, s * rng(1, 1.6)),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * d, s * 0.2, math.sin(a) * d)),
			Material = Enum.Material.Rock,
			Color = if math.random() < 0.5 then Color3.fromRGB(96, 92, 84) else Color3.fromRGB(62, 84, 44),
		})
	end
	far(c, Color3.fromRGB(70, 88, 52))
end

local function water(c: Vector3, size: Vector3)
	local t = workspace.Terrain
	t.WaterTransparency = 0.05 -- the user's choice: water that reads as water, above and below
	t:FillBlock(CFrame.new(c + Vector3.new(0, -size.Y / 2, 0)), size, Enum.Material.Water)
	t:FillBlock(CFrame.new(c + Vector3.new(0, -size.Y - 2, 0)), Vector3.new(size.X, 4, size.Z), Enum.Material.Sand)
end

local function buildWater(c: Vector3)
	water(c, Vector3.new(520, 24, 520))
	far(c, Color3.fromRGB(96, 86, 70))
end

local function buildShore(c: Vector3)
	water(c + Vector3.new(-130, 0, 0), Vector3.new(260, 16, 520))
	-- the beach rises out of the water to the east
	local t = workspace.Terrain
	for i = 0, 12 do
		local x = 4 + i * 10
		local top = math.min(6, -3 + i * 1.1)
		t:FillBlock(CFrame.new(c + Vector3.new(x, (top - 20) / 2, 0)), Vector3.new(10, top + 20, 520), Enum.Material.Sand)
	end
	t:FillBlock(CFrame.new(c + Vector3.new(-6, -10, 0)), Vector3.new(12, 12, 520), Enum.Material.Sand)
	far(c, Color3.fromRGB(110, 98, 74))
end

local function buildSky(c: Vector3)
	local below = c + Vector3.new(0, -140, 0)
	part({ Name = "Ground", Size = Vector3.new(1400, 2, 1400), CFrame = CFrame.new(below), Material = Enum.Material.Grass, Color = Color3.fromRGB(78, 94, 58) })
	part({ Name = "Runway", Size = Vector3.new(36, 0.4, 600), CFrame = CFrame.new(below + Vector3.new(30, 1, 0)), Material = Enum.Material.Asphalt, Color = Color3.fromRGB(46, 46, 48) })
	for i = -12, 12 do
		part({ Name = "Dash", Size = Vector3.new(1, 0.1, 10), CFrame = CFrame.new(below + Vector3.new(30, 1.25, i * 24)), Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(230, 230, 224) })
	end
	far(below, Color3.fromRGB(80, 90, 66))
end

local function buildUnderwater(c: Vector3)
	water(c, Vector3.new(520, DEPTH + 4, 520))
	-- the seabed: flat sand where the units are, rocks and weed around
	part({ Name = "Seabed", Size = Vector3.new(520, 2, 520), CFrame = CFrame.new(c + Vector3.new(0, -DEPTH - 1, 0)), Material = Enum.Material.Sand, Color = Color3.fromRGB(150, 136, 104) })
	for _ = 1, 60 do
		local a, d = rng(0, math.pi * 2), rng(40, 200)
		local s = rng(2, 9)
		local weed = math.random() < 0.4
		part({
			Name = if weed then "Weed" else "Rock",
			Shape = if weed then Enum.PartType.Block else Enum.PartType.Ball,
			Size = if weed then Vector3.new(0.6, s * 1.6, 0.6) else Vector3.new(s * rng(1, 1.8), s, s * rng(1, 1.6)),
			CFrame = CFrame.new(c + Vector3.new(math.cos(a) * d, -DEPTH + (if weed then s * 0.8 else s * 0.2), math.sin(a) * d)) * CFrame.Angles(rng(-0.2, 0.2), rng(0, 6.28), rng(-0.2, 0.2)),
			Material = if weed then Enum.Material.Grass else Enum.Material.Rock,
			Color = if weed then Color3.fromRGB(58, 96, 52) else Color3.fromRGB(88, 92, 90),
		})
	end
end

local BUILDERS: { [string]: (Vector3) -> () } = { pad = buildPad, field = buildField, water = buildWater, shore = buildShore, underwater = buildUnderwater, sky = buildSky }

local function ensurePlace(name: string)
	if built[name] then
		return
	end
	built[name] = true
	BUILDERS[name](CENTERS[name])
end

-- The place "auto" picks for a def.
function Showroom.placeFor(def: any): string
	if def.moveClass == "SUB" or def.moveClass == "AMPHIB" then
		return "underwater"
	end
	local kind = PortraitStage.kind(def)
	if kind == "air" then
		return "sky"
	elseif kind == "water" then
		return "water"
	elseif kind == "shore" then
		return "shore"
	end
	return if def.domain == "structure" then "field" else "pad"
end

-- light ---------------------------------------------------------------------

local function applyLight()
	if lightMode == "dusk" then
		Scene.relight()
	else
		Lighting.ClockTime = 13.2
		Lighting.Brightness = 3
		Lighting.Ambient = Color3.fromRGB(78, 80, 86)
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 146)
		Lighting.ExposureCompensation = 0.1
		local atmosphere = Lighting:FindFirstChild("LobbyAtmosphere") :: Atmosphere?
		if atmosphere then
			atmosphere.Density = 0.28
			atmosphere.Color = Color3.fromRGB(199, 206, 214)
			atmosphere.Decay = Color3.fromRGB(106, 120, 140)
			atmosphere.Haze = 0.8
		end
		local grade = Lighting:FindFirstChild("LobbyGrade") :: ColorCorrectionEffect?
		if grade then
			grade.TintColor = Color3.new(1, 1, 1)
		end
	end
	local focus = Lighting:FindFirstChild("LobbyFocus") :: DepthOfFieldEffect?
	if focus then
		focus.Enabled = not open
	end
	-- the firing range's far targets: thinner haze while it's up
	local air = Lighting:FindFirstChild("LobbyAtmosphere") :: Atmosphere?
	if air and open and firing then
		air.Density = math.min(air.Density, 0.12)
		air.Haze = math.min(air.Haze, 0.4)
	end
	-- under the surface the sea's own colour, whatever the light
	local grade = Lighting:FindFirstChild("LobbyGrade") :: ColorCorrectionEffect?
	if grade and open and placeNow == "underwater" then
		grade.TintColor = if lightMode == "dusk" then Color3.fromRGB(150, 205, 225) else Color3.fromRGB(190, 225, 235)
	end
end

-- units ---------------------------------------------------------------------

local function paint(m: Model, color: Color3)
	-- anchoring stays the template's (its base; the pieces hang on joints
	-- the animations turn)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if CollectionService:HasTag(d, TEAM_TAG) then
				d.Color = color
			end
		end
	end
end

local function clearUnits()
	for _, s in shown do
		Range.detach(s.id)
		if s.model then
			s.model:Destroy()
		end
	end
	table.clear(shown)
end

-- The top of the floor dressing a unit stands on, above the place's level:
-- the pad's disc and marks, the field's dirt patch (their parts sit on the
-- place's level, so a model at 0 sank into them).
local FLOOR: { [string]: number } = { pad = 0.11, field = 0.12 }

-- Where a unit's lowest point sits on a place (its base CFrame's
-- position is the model's bounding box bottom center).
local function bottomFor(kind: string, size: Vector3, def: any): number
	if placeNow == "underwater" then
		if def.moveClass == "SUB" then
			return -DEPTH / 2 - size.Y / 2 -- mid-water
		elseif kind == "water" then
			return -size.Y * PortraitStage.WATERLINE -- ships: their hulls from below
		elseif kind == "air" then
			return 4
		end
		return -DEPTH -- amphibious (and anything else) on the seabed
	elseif placeNow == "sky" then
		return 4 -- hovering above the place's level; the ground is far below
	elseif placeNow == "water" or (placeNow == "shore" and kind ~= "ground") then
		local line = if def.moveClass == "SUB" then 0.55 else PortraitStage.WATERLINE
		if kind == "water" or kind == "shore" then
			return -size.Y * line
		end
	end
	return FLOOR[placeNow] or 0
end

-- The place's levels for the firing range.
local function placeInfo(): Range.Place
	local c = CENTERS[placeNow]
	if placeNow == "sky" then
		return { floor = c.Y + 4, sky = true, underwater = false }
	elseif placeNow == "water" then
		return { floor = c.Y, water = c.Y, seabed = c.Y - 24, sky = false, underwater = false }
	elseif placeNow == "shore" then
		return { floor = c.Y, water = c.Y, seabed = c.Y - 16, sky = false, underwater = false }
	elseif placeNow == "underwater" then
		return { floor = c.Y - DEPTH, water = c.Y, seabed = c.Y - DEPTH, sky = false, underwater = true }
	end
	return { floor = c.Y + (FLOOR[placeNow] or 0), sky = false, underwater = false }
end

local function layout()
	-- side by side along x, centered on the place
	local widths = {}
	local total = 0
	for i, s in shown do
		widths[i] = math.max(s.size.X, s.size.Z * 0.6)
		total += widths[i]
	end
	total += GAP * math.max(0, #shown - 1)
	local center = CENTERS[placeNow]
	local x = -total / 2
	local radius = 0
	local top = 0
	local low, high = math.huge, -math.huge -- the units' own extent (underwater)
	for i, s in shown do
		local mx = x + widths[i] / 2
		x += widths[i] + GAP
		local m = s.model
		if m then
			local bottom = bottomFor(s.kind, s.size, s.def)
			local want = CFrame.new(center + Vector3.new(mx, bottom, 0))
			-- bounding box bottom center -> the model's pivot
			local bb, size = m:GetBoundingBox()
			local bbBottom = bb.Position - Vector3.new(0, size.Y / 2, 0)
			local delta = want.Position - bbBottom
			m:PivotTo(m:GetPivot() + delta)
			s.base = m:GetPivot()
			top = math.max(top, bottom + size.Y)
			low = math.min(low, bottom)
			high = math.max(high, bottom + size.Y)
		end
		radius = math.max(radius, s.size.Magnitude / 2)
	end
	local span = math.max(total, radius * 2)
	-- the firing range: its targets join the view
	local reach: Vector3? = nil
	if firing and shown[1] and shown[1].model then
		local points = Range.setFiring(true, shown[1].base, placeInfo())
		if #points > 0 then
			-- a box round the unit, its targets and its missiles' climb: the
			-- camera looks at its middle from far enough for its width or height
			local lo, hi = center - Vector3.one * radius, center + Vector3.new(radius, top, radius)
			for _, p in points do
				lo, hi = lo:Min(p), hi:Max(p)
			end
			local size = hi - lo
			span = math.max(span, Vector2.new(size.X, size.Z).Magnitude, size.Y * 1.6)
			reach = (lo + hi) / 2
		end
	end
	-- (with targets out, the whole scene matters more than a margin round the unit)
	fitDistance = math.max(14, span / 2 / math.tan(math.rad(FOV / 2)) * (if reach then 1.1 else 1.5))
	-- aircraft: their middle; on the ground a little below the top;
	-- underwater the middle of what's below the surface
	if placeNow == "underwater" and low < math.huge then
		target = center + Vector3.new(0, (low + math.min(high, -2)) / 2, 0)
	else
		target = center + Vector3.new(0, if placeNow == "sky" then top - (top - 4) / 2 else math.max(2, top * 0.45), 0)
	end
	if reach then
		target = reach
	end
end

local function spawn(s: Shown)
	local template = Models.template(s.def)
	local m = template:Clone()
	m.Name = s.def.id
	paint(m, s.color)
	m:PivotTo(CFrame.new(CENTERS[placeNow]))
	local _, size = m:GetBoundingBox()
	s.size = size
	m.Parent = unitsFolder
	if s.model then
		Range.detach(s.id)
		s.model:Destroy()
	end
	s.model = m
	nextId += 1
	s.id = nextId
	Range.attach(s.id, m, s.def)
end

-- Shows these units (`list`: { { def, color } }), side by side.
function Showroom.show(list: { { def: any, color: Color3 } })
	clearUnits()
	if #list == 0 then
		return
	end
	local was = placeNow
	placeNow = if place == "auto" then Showroom.placeFor(list[1].def) else place
	ensurePlace(placeNow)
	if open and (was == "underwater") ~= (placeNow == "underwater") then
		applyLight() -- in or out of the sea's tint
	end
	for _, item in list do
		MeshModels.want(item.def.id, 1000)
		local s: Shown = { id = 0, def = item.def, color = item.color, model = nil, base = CFrame.new(), size = Vector3.one * 8, kind = PortraitStage.kind(item.def) }
		table.insert(shown, s)
		spawn(s)
	end
	layout()
	pitch = if placeNow == "sky" or placeNow == "underwater" then 0.12 else 0.32
end

function Showroom.setPlace(name: string)
	place = name
	local list = {}
	for _, s in shown do
		table.insert(list, { def = s.def, color = s.color })
	end
	Showroom.show(list)
end

-- The firing range on or off: targets for the shown units' weapons.
function Showroom.setFiring(on: boolean)
	firing = on
	if not on then
		Range.setFiring(false)
	end
	layout()
	if open then
		applyLight() -- the haze thins for the range, and back
	end
end

-- How many of a unit's weapons the firing range shows (0: Fire is off).
function Showroom.firingWeapons(def: any): number
	return Range.shownWeapons(def, placeNow == "water" or placeNow == "shore" or placeNow == "underwater")
end

function Showroom.setTurntable(on: boolean)
	turntable = on
end

function Showroom.setLight(mode: string)
	lightMode = mode
	if open then
		applyLight()
	end
end

-- Repaints every shown unit (`color` nil: each its faction's color).
function Showroom.setColors(colors: { Color3 })
	for i, s in shown do
		s.color = colors[i] or s.color
		if s.model then
			paint(s.model, s.color)
		end
	end
end

-- The screen area the unit sits in the middle of; drags and the wheel over
-- it turn and zoom the camera.
function Showroom.setRegion(g: GuiObject)
	region = g
	g.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			lastMouse = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	g.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom * (if input.Position.Z > 0 then 0.88 else 1.14), 0.45, 2.6)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local p = Vector2.new(input.Position.X, input.Position.Y)
			local d = p - lastMouse
			lastMouse = p
			yaw -= d.X * 0.008
			-- underwater the camera may look up at the surface from below
			pitch = math.clamp(pitch + d.Y * 0.006, if placeNow == "underwater" then -0.7 else -0.05, 1.2)
			idleSince = os.clock()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			idleSince = os.clock()
		end
	end)
end

-- the camera and the bobbing -------------------------------------------------

local function step(dt: number)
	if not open then
		return
	end
	local cam = workspace.CurrentCamera
	if cam == nil then
		return
	end
	local now = os.clock()
	if turntable and not dragging and now - idleSince > 1.5 then
		yaw += dt * 0.25
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = FOV
	local dist = fitDistance * zoom
	local offset = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)) * dist
	local eye = target + offset
	if placeNow == "underwater" then
		-- stay under the surface, however far out the wheel zooms
		eye = Vector3.new(eye.X, math.min(eye.Y, CENTERS.underwater.Y - 2), eye.Z)
	end
	local cf = CFrame.lookAt(eye, target)
	-- slide the camera so the unit sits in the middle of the free area
	local r = region
	local vp = cam.ViewportSize
	if r and vp.X > 0 then
		local cx = (r.AbsolutePosition.X + r.AbsoluteSize.X / 2) / vp.X
		local halfWidth = math.tan(math.rad(FOV / 2)) * dist * vp.X / math.max(vp.Y, 1)
		cf = cf * CFrame.new(-(cx - 0.5) * 2 * halfWidth, 0, 0)
	end
	cam.CFrame = cf
	for i, s in shown do
		local m = s.model
		if m and (placeNow == "sky" or placeNow == "water") then
			local amp = if placeNow == "sky" then 0.8 else 0.15
			m:PivotTo(s.base * CFrame.new(0, math.sin(now * 1.3 + i) * amp, 0) * CFrame.Angles(math.sin(now * 0.9 + i) * 0.015, 0, math.sin(now * 1.1 + i) * 0.02))
		end
	end
	Range.step(dt)
end

-- open / close -----------------------------------------------------------------

-- The showroom takes the screen: the battle goes away, the camera is ours.
-- `allDefs` (Defs.load) starts every approved mesh model building.
function Showroom.enter(allDefs: any)
	if defs == nil then
		defs = allDefs
		MeshModels.start(allDefs)
		MeshModels.onReady(function(id: string)
			for _, s in shown do
				if s.def.id == id then
					spawn(s)
					layout()
				end
			end
		end)
		RunService.RenderStepped:Connect(step)
		Range.init(allDefs, folder)
		Range.setGround(function(p: Vector3): number
			local c = CENTERS[placeNow]
			if placeNow == "sky" then
				return c.Y - 139 -- the runway's field far below
			elseif placeNow == "pad" or placeNow == "field" then
				return c.Y + (FLOOR[placeNow] or 0)
			end
			return c.Y -- the water's surface
		end)
	end
	open = true
	folder.Parent = workspace
	Scene.setAway(true)
	applyLight()
end

function Showroom.leave()
	if not open then
		return
	end
	open = false
	Range.stop() -- (Fire stays as the switch says: back on the page, the range comes back)
	folder.Parent = nil
	Scene.setAway(false)
	Scene.relight()
	local focus = Lighting:FindFirstChild("LobbyFocus") :: DepthOfFieldEffect?
	if focus then
		focus.Enabled = true
	end
end

function Showroom.isOpen(): boolean
	return open
end

return Showroom

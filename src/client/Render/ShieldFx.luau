--!strict
-- Shield domes (C-90; first a prototype, C-87 to C-89). The look:
--   - a translucent neutral white dome (no team colour, the user's call)
--     whose opacity follows strength: invisible at 0%, full from 50%;
--   - a bright edge on its outline as the camera sees it (two camera-facing
--     ring adornments);
--   - thin glowing rings flowing from the top down the dome;
--   - a curved beam rising from the emitter to the top, a swirling vortex
--     at the top, floating specks inside, a slow subtle pulse;
--   - the emitter's plasma core (green full, orange, red empty) and a
--     capacity bar above the dome;
--   - hits: a ripple at the impact point on the dome, red-hot hexagon plates
--     round it (Core/Shield) and a brief brightness pulse.
-- Timings, flicker, ring flow, detail and culling are Core/ShieldLook's.
--
--   local s = ShieldFx.new(emitter, radius, teamColor)  -- an Attachment or a Vector3
--   s:deploy()  s:setStrength(0.6)  s:hit(worldPos, intensity)  s:collapse()  s:destroy()
--
-- Performance (the user's hard rules): every instance a shield uses is made
-- in new() and only hidden or moved afterwards (rings are a fixed pool of
-- ShieldLook.RINGS; the hexagon plates one shared pool made with the first
-- shield). ONE render loop updates every shield and skips those off
-- screen; at strategic distance only the dome and its edge are drawn.
-- Client-side only.
--
-- Placeholder parts and Studio textures for now; C's assets replace them
-- when they merge (docs/contracts/fx.md, assets/fx/shield/roblox_assets.json).
-- Ring and edge adornments keep the default ZIndex and culling off.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shield = require("../Core/Shield")
local ShieldLook = require("../Core/ShieldLook")

local ShieldFx = {}

ShieldFx.DOME_COLOR = Color3.fromRGB(225, 232, 240)
ShieldFx.DOME_OPACITY = 0.2 -- the dome ball at full strength (1 - transparency)
ShieldFx.RING_COLOR = Color3.fromRGB(235, 245, 255)
ShieldFx.RING_OPACITY = 0.55
ShieldFx.EDGE_OPACITY = 0.95
ShieldFx.RIPPLES = 4 -- per shield, a fixed pool
ShieldFx.RIPPLE_SECONDS = 0.6
ShieldFx.PLATE_POOL = 160 -- hexagon plates shared by every shield
ShieldFx.PLATE_THICKNESS = 0.12
ShieldFx.SWIRL_ARCS = 3 -- per shield: glowing arcs turning under the top (the vortex)

local WHITE = Color3.new(1, 1, 1)

type Ripple = { adorn: CylinderHandleAdornment, at: Vector3, normal: Vector3, born: number, size: number }

export type ShieldFx = {
	radius: number,
	teamColor: Color3, -- kept for the interface; the look is neutral
	strength: number,
	state: ShieldLook.State,
	since: number, -- the effect clock when the state began
	phase: number, -- ring flow
	pulse: number, -- a hit's brightness pulse, 0..1
	strategic: boolean,
	visible: boolean,
	emitter: Attachment?,
	position: Vector3,
	model: Shield.Dome, -- hit patches (Core/Shield)
	folder: Folder,
	anchor: Part, -- invisible, at the centre: the adornee
	dome: Part,
	specks: ParticleEmitter,
	core: Part,
	coreLight: PointLight,
	beam: Beam,
	beamTop: Attachment,
	beamBase: Attachment,
	swirl: Part,
	swirlEmitter: ParticleEmitter,
	arcs: { CylinderHandleAdornment },
	edge: CylinderHandleAdornment,
	edgeGlow: CylinderHandleAdornment,
	rings: { CylinderHandleAdornment },
	flash: CylinderHandleAdornment,
	ripples: { Ripple },
	bar: Frame?,
	barFill: Frame?,
	barText: TextLabel?,
	-- methods
	deploy: (ShieldFx, boolean?) -> (),
	collapse: (ShieldFx) -> (),
	setStrength: (ShieldFx, number) -> (),
	hit: (ShieldFx, Vector3, number) -> (),
	destroy: (ShieldFx) -> (),
}

local shields: { ShieldFx } = {}
-- the effects' own clock: real time × timeScale (slow motion for screenshots)
local clock = 0
ShieldFx.timeScale = 1
local loop: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local root: Folder? = nil

-- shared hexagon plates
type Plate = { parts: { BasePart } }
local plates: { Plate } = {}
local platesLit = 0

ShieldFx.stats = { shields = 0, drawn = 0, culled = 0, strategic = 0, ms = 0, msMax = 0, frames = 0, plates = "", platesLit = 0 }

local function bare(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function adornment(parent: Instance, adornee: BasePart, color: Color3): CylinderHandleAdornment
	local a = Instance.new("CylinderHandleAdornment")
	a.Adornee = adornee
	a.AlwaysOnTop = false
	a.AdornCullingMode = Enum.AdornCullingMode.Never
	a.Color3 = color
	a.Height = 0.15
	a.Visible = false
	a.Parent = parent
	return a
end

-- A hexagon prism (flats across X) where EditableMesh is allowed, else nil.
local function hexMesh(): MeshPart?
	local ok, result = pcall(function()
		local em = (AssetService :: any):CreateEditableMesh()
		local top, bottom = {}, {}
		for k = 0, 5 do
			local a = math.rad(30 + 60 * k)
			top[k + 1] = em:AddVertex(Vector3.new(math.cos(a), 0.5, math.sin(a)))
			bottom[k + 1] = em:AddVertex(Vector3.new(math.cos(a), -0.5, math.sin(a)))
		end
		local ct, cb = em:AddVertex(Vector3.new(0, 0.5, 0)), em:AddVertex(Vector3.new(0, -0.5, 0))
		local function tri(a: number, b: number, c: number)
			em:AddTriangle(a, b, c)
			em:AddTriangle(a, c, b)
		end
		for k = 1, 6 do
			local n = k % 6 + 1
			tri(ct, top[k], top[n])
			tri(cb, bottom[n], bottom[k])
			tri(top[k], bottom[k], bottom[n])
			tri(top[k], bottom[n], top[n])
		end
		return (AssetService :: any):CreateMeshPartAsync((Content :: any).fromObject(em))
	end)
	if ok and result then
		local mp = result :: MeshPart
		bare(mp)
		mp.Material = Enum.Material.Neon
		return mp
	end
	return nil
end

-- The shared plate pool, made once with the first shield, in its own
-- thread: making the hexagon mesh yields (CreateMeshPartAsync), and new()
-- must not (the frame loop would carry on and make a second dome). Hit
-- plates show once it is ready.
local function makePlates(folder: Folder)
	local w = Shield.PLATE
	local template = hexMesh()
	ShieldFx.stats.plates = if template then "hexagon mesh" else "three rectangles"
	for _ = 1, ShieldFx.PLATE_POOL do
		local parts: { BasePart } = {}
		if template then
			local p = template:Clone()
			p.Size = Vector3.new(w, ShieldFx.PLATE_THICKNESS, w * 2 / math.sqrt(3))
			p.Transparency = 1
			p.Parent = folder
			parts[1] = p
		else
			for _ = 1, 3 do
				local p = Instance.new("Part")
				bare(p)
				p.Material = Enum.Material.Neon
				p.Size = Vector3.new(w / math.sqrt(3), ShieldFx.PLATE_THICKNESS, w)
				p.Transparency = 1
				p.Parent = folder
				table.insert(parts, p)
			end
		end
		table.insert(plates, { parts = parts })
	end
end

local Methods = {}
Methods.__index = Methods

local function setState(s: ShieldFx, state: ShieldLook.State)
	s.state = state
	s.since = clock
end

-- `instant`: already up (a dome that comes into view standing), no deploy animation.
function Methods.deploy(s: ShieldFx, instant: boolean?)
	setState(s, if instant then "up" else "deploying")
end

function Methods.collapse(s: ShieldFx)
	if s.state ~= "down" then
		setState(s, "collapsing")
	end
end

function Methods.setStrength(s: ShieldFx, strength: number)
	s.strength = math.clamp(strength, 0, 1)
end

-- A hit at `worldPos` (projected onto the dome); `intensity` 1 = a typical shell.
function Methods.hit(s: ShieldFx, worldPos: Vector3, intensity: number)
	if s.state ~= "up" and s.state ~= "deploying" then
		return
	end
	local now = clock
	local center = s.position
	local d = worldPos - center
	local n = if d.Magnitude > 1e-6 then d.Unit else Vector3.yAxis
	-- the oldest ripple is reused
	local oldest = s.ripples[1]
	for _, r in s.ripples do
		if r.born < oldest.born then
			oldest = r
		end
	end
	oldest.at = center + n * s.radius
	oldest.normal = n
	oldest.born = now
	oldest.size = math.clamp(intensity, 0.3, 4)
	Shield.hit(s.model, { x = worldPos.X, y = worldPos.Y, z = worldPos.Z }, intensity, now)
	s.pulse = math.min(1, s.pulse + 0.3 * intensity)
end

function Methods.destroy(s: ShieldFx)
	local i = table.find(shields, s)
	if i then
		table.remove(shields, i)
	end
	s.folder:Destroy()
	if s.bar then
		s.bar:Destroy()
	end
	ShieldFx.stats.shields = #shields
	if #shields == 0 and loop then
		loop:Disconnect()
		loop = nil
		local st = ShieldFx.stats
		st.ms, st.drawn, st.culled, st.strategic = 0, 0, 0, 0
	end
end

local step: (dt: number) -> ()

-- A shield dome round `emitter` (an Attachment, followed each frame, or a
-- position): `radius` studs, down until deploy().
function ShieldFx.new(emitter: Attachment | Vector3, radius: number, teamColor: Color3?): ShieldFx
	if root == nil then
		local f = Instance.new("Folder")
		f.Name = "ShieldFx"
		f.Parent = workspace
		root = f
		task.spawn(makePlates, f)
	end
	local player = Players.LocalPlayer
	local playerGui = if player then player:FindFirstChildOfClass("PlayerGui") else nil -- never wait: new() runs in the frame loop
	if gui == nil and playerGui then
		local g = Instance.new("ScreenGui")
		g.Name = "ShieldBars"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true -- placed in viewport pixels
		g.Parent = playerGui
		gui = g
	end
	local position = if typeof(emitter) == "Vector3" then emitter else (emitter :: Attachment).WorldPosition
	local folder = Instance.new("Folder")
	folder.Name = "Shield"
	folder.Parent = root
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	bare(anchor)
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = folder
	-- the dome
	local dome = Instance.new("Part")
	dome.Name = "Dome"
	bare(dome)
	dome.Shape = Enum.PartType.Ball
	dome.Material = Enum.Material.SmoothPlastic
	dome.Color = ShieldFx.DOME_COLOR
	dome.Transparency = 1
	dome.Size = Vector3.one * 2 * radius
	dome.Position = position
	dome.Parent = folder
	local specks = Instance.new("ParticleEmitter")
	specks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	specks.Shape = Enum.ParticleEmitterShape.Sphere
	specks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	specks.Rate = math.clamp(radius / 3, 4, 40)
	specks.Lifetime = NumberRange.new(3, 6)
	specks.Speed = NumberRange.new(0.3, 1)
	specks.SpreadAngle = Vector2.new(180, 180)
	specks.LightEmission = 1
	specks.Color = ColorSequence.new(WHITE)
	specks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.8, 0.35), NumberSequenceKeypoint.new(1, 0) })
	specks.Transparency = NumberSequence.new(0.3)
	specks.Enabled = false
	specks.Parent = dome
	-- the emitter's core
	local core = Instance.new("Part")
	core.Name = "Core"
	bare(core)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Size = Vector3.one * math.clamp(radius / 12, 1.5, 6)
	core.Position = position + Vector3.new(0, core.Size.Y * 0.6, 0)
	core.Parent = folder
	local coreLight = Instance.new("PointLight")
	coreLight.Range = math.clamp(radius / 4, 8, 20)
	coreLight.Brightness = 2
	coreLight.Parent = core
	-- the beam: from the emitter, bending, to the top (its top end climbs on deploy)
	local beamBase = Instance.new("Attachment")
	beamBase.Position = Vector3.new(0, core.Size.Y, 0)
	beamBase.Parent = anchor
	local beamTop = Instance.new("Attachment")
	beamTop.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = beamBase
	beam.Attachment1 = beamTop
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 230, 255))
	beam.Width0 = math.clamp(radius / 60, 0.4, 2)
	beam.Width1 = math.clamp(radius / 100, 0.25, 1.2)
	beam.Texture = "" -- solid; C's beam texture replaces it
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.25) })
	beam.CurveSize0 = radius * 0.25
	beam.CurveSize1 = -radius * 0.1
	beam.Segments = 20
	beam.Enabled = false
	beam.Parent = anchor
	-- the vortex at the top: a disc of particles that turns with its part
	local swirl = Instance.new("Part")
	swirl.Name = "Swirl"
	bare(swirl)
	swirl.Transparency = 1
	swirl.Size = Vector3.new(radius * 0.5, 0.2, radius * 0.5)
	swirl.Position = position + Vector3.new(0, radius * 0.97, 0)
	swirl.Parent = folder
	local swirlEmitter = Instance.new("ParticleEmitter")
	swirlEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirlEmitter.Shape = Enum.ParticleEmitterShape.Disc
	swirlEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	swirlEmitter.LockedToPart = true
	swirlEmitter.Rate = 30
	swirlEmitter.Lifetime = NumberRange.new(1.2, 2)
	swirlEmitter.Speed = NumberRange.new(0)
	swirlEmitter.RotSpeed = NumberRange.new(60, 120)
	swirlEmitter.Rotation = NumberRange.new(0, 360)
	swirlEmitter.LightEmission = 1
	swirlEmitter.Color = ColorSequence.new(WHITE, Color3.fromRGB(190, 220, 255))
	swirlEmitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, math.clamp(radius * 0.03, 0.5, 3)), NumberSequenceKeypoint.new(1, 0) })
	swirlEmitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1) })
	swirlEmitter.Enabled = false
	swirlEmitter.Parent = swirl
	-- the edge, the rings, the ground flash, the ripples: adornments on the anchor
	local edge = adornment(folder, anchor, WHITE)
	local edgeGlow = adornment(folder, anchor, ShieldFx.DOME_COLOR)
	local rings = {}
	for i = 1, ShieldLook.RINGS do
		rings[i] = adornment(folder, anchor, ShieldFx.RING_COLOR)
	end
	local arcs = {}
	for i = 1, ShieldFx.SWIRL_ARCS do
		local a = adornment(folder, anchor, WHITE)
		a.Angle = 130
		arcs[i] = a
	end
	local flash = adornment(folder, anchor, WHITE)
	local ripples = {}
	for i = 1, ShieldFx.RIPPLES do
		ripples[i] = { adorn = adornment(folder, anchor, WHITE), at = position, normal = Vector3.yAxis, born = -math.huge, size = 1 }
	end
	-- the capacity bar
	local bar, fill, text = nil, nil, nil
	if gui then
		local b = Instance.new("Frame")
		b.Name = "Capacity"
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(120, 28)
		b.Visible = false
		b.Parent = gui
		local back = Instance.new("Frame")
		back.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
		back.BackgroundTransparency = 0.25
		back.BorderSizePixel = 0
		back.Position = UDim2.fromOffset(0, 17)
		back.Size = UDim2.new(1, 0, 0, 9)
		back.Parent = b
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.Parent = back
		local mark = Instance.new("Frame") -- the 25% a collapsed shield needs to rise again
		mark.BackgroundColor3 = WHITE
		mark.BorderSizePixel = 0
		mark.Position = UDim2.fromScale(Shield.RAISE_AT, 0)
		mark.Size = UDim2.new(0, 1, 1, 0)
		mark.Parent = back
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Font = Enum.Font.GothamMedium
		tl.TextSize = 12
		tl.TextColor3 = WHITE
		tl.TextStrokeTransparency = 0.4
		tl.Size = UDim2.new(1, 0, 0, 15)
		tl.Parent = b
		bar, fill, text = b, f, tl
	end
	local s: ShieldFx = setmetatable({
		radius = radius,
		teamColor = teamColor or WHITE,
		strength = 1,
		state = "down" :: ShieldLook.State,
		since = clock,
		phase = 0,
		pulse = 0,
		strategic = false,
		visible = true,
		emitter = if typeof(emitter) == "Instance" then emitter :: Attachment else nil,
		position = position,
		model = Shield.newDome({ x = position.X, y = position.Y, z = position.Z }, radius),
		folder = folder,
		anchor = anchor,
		dome = dome,
		specks = specks,
		core = core,
		coreLight = coreLight,
		beam = beam,
		beamTop = beamTop,
		beamBase = beamBase,
		swirl = swirl,
		swirlEmitter = swirlEmitter,
		arcs = arcs,
		edge = edge,
		edgeGlow = edgeGlow,
		rings = rings,
		flash = flash,
		ripples = ripples,
		bar = bar,
		barFill = fill,
		barText = text,
	}, Methods) :: any
	table.insert(shields, s)
	ShieldFx.stats.shields = #shields
	if loop == nil then
		loop = RunService.RenderStepped:Connect(step)
	end
	return s
end

-- a CylinderHandleAdornment's cylinder lies along its CFrame's Z axis: this
-- turns it upright (a horizontal ring)
local FLAT = CFrame.Angles(math.pi / 2, 0, 0)

local function hideDetail(s: ShieldFx)
	for _, r in s.rings do
		r.Visible = false
	end
	for _, r in s.ripples do
		r.adorn.Visible = false
	end
	s.flash.Visible = false
	for _, a in s.arcs do
		a.Visible = false
	end
	s.beam.Enabled = false
	s.specks.Enabled = false
	s.swirlEmitter.Enabled = false
end

-- One shield's frame; false if it was skipped (down or off screen). Hit
-- plates go into `plateParts` / `plateCFrames` for one BulkMoveTo.
local function draw(s: ShieldFx, now: number, dt: number, cam: Camera, view: Vector2, plateParts: { BasePart }, plateCFrames: { CFrame }): boolean
	local next = ShieldLook.advance(s.state, now - s.since)
	if next ~= s.state then
		s.state = next
		s.since = now
	end
	local since = now - s.since
	if s.emitter then
		local p = s.emitter.WorldPosition
		if (p - s.position).Magnitude > 0.05 then
			s.position = p
			s.anchor.Position = p
			s.model.center = { x = p.X, y = p.Y, z = p.Z }
		end
	end
	local center = s.position
	local beamK, scale, flashK, collapseFlicker = ShieldLook.phase(s.state, since)
	local R = s.radius * scale
	-- the core shows the strength whatever the state
	local r8, g8, b8 = Shield.coreColor(s.strength)
	local coreColor = Color3.fromRGB(r8, g8, b8)
	s.core.Color = coreColor
	s.coreLight.Color = coreColor
	local camPos = cam.CFrame.Position
	local toCam = camPos - center
	local D = toCam.Magnitude
	if s.bar then
		s.bar.Visible = false
	end
	if s.state == "down" then
		s.dome.Transparency = 1
		s.edge.Visible = false
		s.edgeGlow.Visible = false
		hideDetail(s)
		return false
	end
	-- off screen? (a dome round the camera always counts as on screen)
	local sp = cam:WorldToViewportPoint(center + Vector3.new(0, s.radius * 0.5, 0))
	local radiusPx = s.radius / math.max(sp.Z, 1) * (view.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
	if not ShieldLook.onScreen(sp.X, sp.Y, sp.Z, radiusPx, view.X, view.Y, D < s.radius) then
		s.visible = false
		return false
	end
	s.visible = true
	s.strategic = ShieldLook.strategic(s.strategic, D)
	-- the dome: opacity follows strength; low strength flickers; a slow pulse; hits brighten it
	s.pulse = math.max(0, s.pulse - dt * 2.5)
	local opacity = ShieldLook.opacity(s.strength) * ShieldLook.flicker(s.strength, now) * collapseFlicker
	local breathe = 1 + 0.06 * math.sin(now * 1.6)
	local domeAlpha = math.min(1, ShieldFx.DOME_OPACITY * opacity * breathe * (1 + 1.5 * s.pulse))
	local size = Vector3.one * math.max(2 * R, 0.01)
	if s.dome.Size ~= size then
		s.dome.Size = size
	end
	s.dome.Transparency = if R > 0.05 then 1 - domeAlpha else 1
	-- the edge: the sphere's silhouette from the camera, a circle facing it,
	-- R²/D towards the camera, of radius R·√(1 − R²/D²)
	if R > 0.05 and D > R * 1.02 then
		local n = toCam / D
		local c = center + n * (R * R / D)
		local rr = R * math.sqrt(1 - (R * R) / (D * D))
		local w = math.max(0.25, D * 0.0025) -- about the same width in pixels at any zoom
		local cf = CFrame.lookAt(c, c + n) - center
		-- Neon-bright white blooms, so the edge fades on a curve
		local edgeAlpha = math.clamp(ShieldFx.EDGE_OPACITY * opacity * opacity + 0.4 * s.pulse, 0, 1)
		s.edge.CFrame = cf
		s.edge.Radius = rr
		s.edge.InnerRadius = math.max(rr - w, 0)
		s.edge.Height = 0.05
		s.edge.Transparency = 1 - edgeAlpha
		s.edge.Visible = edgeAlpha > 0.01
		s.edgeGlow.CFrame = cf
		s.edgeGlow.Radius = math.max(rr - w, 0)
		s.edgeGlow.InnerRadius = math.max(rr - 5 * w, 0)
		s.edgeGlow.Height = 0.05
		s.edgeGlow.Transparency = 1 - edgeAlpha * 0.3
		s.edgeGlow.Visible = edgeAlpha > 0.01
		-- the bar, above the outline's top
		if s.bar and s.barFill and s.barText then
			local up = cam.CFrame.UpVector - n * cam.CFrame.UpVector:Dot(n)
			local top = if up.Magnitude > 1e-3 then c + up.Unit * (rr + 2) else center + Vector3.new(0, R, 0)
			local tp, on = cam:WorldToViewportPoint(top)
			s.bar.Visible = on and not s.strategic -- strategic detail: the dome and edge only
			s.bar.Position = UDim2.fromOffset(tp.X, tp.Y)
			s.barFill.Size = UDim2.fromScale(s.strength, 1)
			s.barFill.BackgroundColor3 = coreColor
			s.barText.Text = `Shield {math.floor(s.strength * 100 + 0.5)}%`
		end
	else
		s.edge.Visible = false
		s.edgeGlow.Visible = false
	end
	if s.strategic then
		hideDetail(s)
		return true
	end
	-- the beam: its top end climbs to the dome's top on deploy
	local topY = s.radius * 0.97
	local baseY = s.beamBase.Position.Y
	s.beam.Enabled = beamK > 0.01
	s.beamTop.Position = Vector3.new(0, baseY + (topY - baseY) * beamK, 0)
	-- the rings: slide down, resized to the curve at their height, fade near the ground
	local speed, bright = ShieldLook.ringFlow(s.strength)
	s.phase += dt * speed / ShieldLook.RING_PERIOD
	local ringW = math.max(0.15, R * 0.004)
	for i, ring in s.rings do
		local _, rf, yf, a = ShieldLook.ringAt(i, #s.rings, s.phase)
		local alpha = ShieldFx.RING_OPACITY * a * bright * opacity
		if R > 0.05 and alpha > 0.01 then
			local rr = R * rf
			ring.CFrame = CFrame.new(0, R * yf, 0) * FLAT
			ring.Radius = rr
			ring.InnerRadius = math.max(rr - ringW, 0)
			ring.Transparency = 1 - alpha
			ring.Visible = true
		else
			ring.Visible = false
		end
	end
	-- the ground flash while it grows
	if flashK then
		local fr = s.radius * (0.2 + 0.95 * flashK)
		s.flash.CFrame = CFrame.new(0, 0.2, 0) * FLAT
		s.flash.Radius = fr
		s.flash.InnerRadius = math.max(fr - s.radius * 0.06, 0)
		s.flash.Transparency = 0.2 + 0.8 * flashK
		s.flash.Visible = true
	else
		s.flash.Visible = false
	end
	-- the vortex turns; specks drift
	local up = s.state == "up"
	s.swirlEmitter.Enabled = up
	s.specks.Enabled = up
	if up then
		s.swirl.CFrame = CFrame.new(center + Vector3.new(0, s.radius * 0.97, 0)) * CFrame.Angles(0, now * 1.2 * speed, 0)
	end
	-- the vortex: arcs under the top, following the curve, inner ones turning faster
	for i, a in s.arcs do
		local rr = R * (0.08 + 0.1 * i)
		local alpha = 0.75 * opacity * (if up then 1 else 0)
		if rr > 0.2 and alpha > 0.01 then
			local y = math.sqrt(math.max(R * R - rr * rr, 0)) - 0.4
			a.CFrame = CFrame.new(0, y, 0) * FLAT * CFrame.Angles(0, 0, now * speed * (2.6 - 0.5 * i) + i * 2.1)
			a.Radius = rr
			a.InnerRadius = math.max(rr - math.max(0.2, R * 0.006), 0)
			a.Transparency = 1 - alpha
			a.Visible = true
		else
			a.Visible = false
		end
	end
	-- ripples: rings growing out from the hit along the dome
	for _, r in s.ripples do
		local age = now - r.born
		if age < ShieldFx.RIPPLE_SECONDS then
			local k = age / ShieldFx.RIPPLE_SECONDS
			local rr = math.max(0.5, s.radius * 0.3 * r.size ^ 0.5 * (1 - (1 - k) ^ 2))
			r.adorn.CFrame = CFrame.lookAt(r.at, r.at + r.normal) - center
			r.adorn.Radius = rr
			r.adorn.InnerRadius = math.max(rr - math.max(0.3, rr * 0.12), 0)
			r.adorn.Transparency = 0.1 + 0.9 * k
			r.adorn.Visible = true
		else
			r.adorn.Visible = false
		end
	end
	-- this shield's hit patches, plates from the shared pool
	Shield.expire(s.model, now)
	for _, patch in s.model.patches do
		local age = now - patch.born
		for _, p in patch.plates do
			local heat, alpha, dent = Shield.plateAt(age, p.ring, patch.strength)
			if alpha > 0 and platesLit < #plates then
				platesLit += 1
				local plate = plates[platesLit]
				local nrm = Vector3.new(p.normal.x, p.normal.y, p.normal.z)
				local cf = CFrame.fromMatrix(Vector3.new(p.pos.x, p.pos.y, p.pos.z) + nrm * (0.15 - dent), Vector3.new(p.right.x, p.right.y, p.right.z), nrm)
				local hr, hg, hb = Shield.color(heat)
				local color = Color3.fromRGB(hr, hg, hb)
				for k, part in plate.parts do
					table.insert(plateParts, part)
					table.insert(plateCFrames, if #plate.parts == 1 then cf else cf * CFrame.Angles(0, math.rad(60 * (k - 1)), 0))
					part.Color = color
					part.Transparency = 1 - alpha * 0.95
				end
			end
		end
	end
	return true
end

step = function(realDt: number)
	local t0 = os.clock()
	local dt = realDt * ShieldFx.timeScale
	clock += dt
	local cam = workspace.CurrentCamera
	local view = cam.ViewportSize
	local lastLit = platesLit
	platesLit = 0
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local drawn, culled, strategic = 0, 0, 0
	for _, s in shields do
		if draw(s, clock, dt, cam, view, parts, cframes) then
			drawn += 1
			if s.strategic then
				strategic += 1
			end
		elseif s.state ~= "down" then
			culled += 1
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i = platesLit + 1, lastLit do
		for _, p in plates[i].parts do
			p.Transparency = 1
		end
	end
	local st = ShieldFx.stats
	st.drawn, st.culled, st.strategic = drawn, culled, strategic
	st.platesLit = platesLit
	local ms = (os.clock() - t0) * 1000
	st.ms = ms
	st.msMax = math.max(st.msMax, ms)
	st.frames += 1
end

-- Every shield (debug calls).
function ShieldFx.all(): { ShieldFx }
	return shields
end

return ShieldFx

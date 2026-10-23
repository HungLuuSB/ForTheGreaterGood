--!strict
-- Shield domes (C-90, on C's assets since C-94; first a prototype, C-87 to
-- C-89). The look:
--   - C's hemisphere dome, neutral white (no team colour, the user's call),
--     opacity following strength: invisible at 0%, full from 50%;
--   - a bright edge on its outline as the camera sees it (two camera-facing
--     ring adornments) and C's ring at the foot of the dome;
--   - C's thin rings (RingThin) flowing from the top down the dome (C's
--     Ring, whose tube grows with the ring, is only the foot ring);
--   - C's light beam rising from the emitter (a generator's `beam`
--     attachment) to the top, C's swirl turning at the top, C's specks
--     floating inside, a slow subtle pulse;
--   - the emitter's core (the generator's `core` piece, else a placeholder
--     ball) glowing green full, orange, red empty; a capacity bar above;
--   - hits, as a shell crosses the surface: a patch of fine honeycomb cells
--     lights round it, white-hot at the centre, fading out (BAR's plasma
--     deflector; no ripple since C-131)
--     (Core/Shield) and a brief brightness pulse.
-- Timings, flicker, ring flow, detail and culling are Core/ShieldLook's.
--
--   ShieldFx.ready()  -- C's meshes loaded (false until then: wait before new())
--   local s = ShieldFx.new(emitter, radius, teamColor, base?)  -- an Attachment or a Vector3
--   s:deploy()  s:setStrength(0.6)  s:hit(worldPos, intensity)  s:collapse()  s:destroy()
--   s:setEmitter(attachment?)  -- the beam's start (a model streamed in or out)
--
-- Assets: docs/contracts/fx.md, IDs from assets/fx/shield/roblox_assets.json.
-- The meshes are made from their IDs at runtime (CreateMeshPartAsync, once,
-- in its own thread); if that fails the dome is a ball, the flowing rings
-- adornments and there is no foot ring.
--
-- Performance (the user's hard rules): every instance a shield uses is made
-- in new() and only hidden or moved afterwards (rings are a fixed pool of
-- ShieldLook.RINGS; the hexagon plates one shared pool made with the first
-- shield). ONE render loop updates every shield and skips those off
-- screen; at strategic distance only the dome and its edge are drawn.
-- Client-side only. Adornments keep the default ZIndex and culling off.

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shield = require("../Core/Shield")
local ShieldLook = require("../Core/ShieldLook")

local ShieldFx = {}

-- C's shield assets (assets/fx/shield/roblox_assets.json)
ShieldFx.ASSETS = table.freeze({
	dome = "rbxassetid://85081416332401",
	ring = "rbxassetid://134054369788950",
	ringThin = "rbxassetid://111379471786973", -- tube 0.2% of its radius (models: C-94 request)
	swirl = "rbxassetid://113814321169730",
	beam = "rbxassetid://100117547859650",
	speck = "rbxassetid://90660161303538",
})

ShieldFx.DOME_COLOR = Color3.fromRGB(225, 232, 240)
ShieldFx.DOME_OPACITY = 0.2 -- the dome at full strength (1 - transparency)
ShieldFx.RING_COLOR = Color3.fromRGB(235, 245, 255)
ShieldFx.RING_OPACITY = 0.55
ShieldFx.RING_TUBE = 0.004 -- a flowing ring's height (RingThin) or width (adornment), × R
ShieldFx.FOOT_OPACITY = 0.8 -- the ring where the dome meets the ground
ShieldFx.EDGE_OPACITY = 0.95
ShieldFx.SWIRL_SIZE = 0.4 -- the swirl disc's diameter, × R (C's checked assembly: 16 on 40)
ShieldFx.SWIRL_OPACITY = 0.85
ShieldFx.PLATE_POOL = 800 -- honeycomb cells shared by every shield (6 patches of up to 127, C-136)
ShieldFx.PLATE_OPACITY = 0.85 -- a cell's outline at its brightest (outlines are thin: they don't bloom into a block)
ShieldFx.OUTLINE = 0.16 -- a cell's outline width, of its corner radius (C-131: outlined cells, BAR's honeycomb)
ShieldFx.PLATE_THICKNESS = 0.12

local WHITE = Color3.new(1, 1, 1)

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
	emitter: Attachment?, -- the beam's start (a generator's `beam` attachment)
	coreTarget: BasePart?, -- the emitter's part, tinted by strength (the generator's core)
	coreOriginal: Color3?, -- its own colour, put back when the dome lets go of it
	position: Vector3, -- the dome's centre: the generator's base
	model: Shield.Dome, -- hit patches (Core/Shield)
	folder: Folder,
	anchor: Part, -- invisible, at the centre: the adornee
	dome: BasePart,
	domeMesh: boolean, -- C's hemisphere (else a ball)
	specks: ParticleEmitter,
	core: Part, -- placeholder core, shown without an emitter part
	coreLight: PointLight,
	beam: Beam,
	beamTop: Attachment,
	beamBase: Attachment, -- the placeholder core's top
	swirl: Part,
	swirlDecal: Decal,
	edge: CylinderHandleAdornment,
	edgeGlow: CylinderHandleAdornment,
	rings: { any }, -- C's RingThin MeshParts, or adornments
	ringMesh: boolean,
	foot: BasePart?, -- C's ring at the dome's foot
	flash: CylinderHandleAdornment,
	bar: Frame?,
	barFill: Frame?,
	barText: TextLabel?,
	-- methods
	deploy: (ShieldFx, boolean?) -> (),
	collapse: (ShieldFx) -> (),
	setStrength: (ShieldFx, number) -> (),
	setEmitter: (ShieldFx, Attachment?) -> (),
	hit: (ShieldFx, Vector3, number) -> (),
	destroy: (ShieldFx) -> (),
}

local shields: { ShieldFx } = {}
-- the effects' own clock: real time × the sim speed (they slow and pause with
-- the shells they react to, C-99) × timeScale (debug slow motion)
local clock = 0
ShieldFx.timeScale = 1
ShieldFx.simSpeed = 1 -- set each frame by the caller
local particleScale = 1
local loop: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local root: Folder? = nil

-- shared hexagon plates
type Plate = { parts: { BasePart } }
local plates: { Plate } = {}
local platesLit = 0
local plateSize = Vector3.new(Shield.PLATE, ShieldFx.PLATE_THICKNESS, Shield.PLATE * 2 / math.sqrt(3)) -- a mesh cell at scale 1

ShieldFx.stats = { shields = 0, drawn = 0, culled = 0, strategic = 0, ms = 0, msMax = 0, frames = 0, plates = "", platesLit = 0, meshes = "" }

local function bare(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- C's meshes, made once from their IDs in their own thread (it yields)
local templates: { dome: MeshPart?, ring: MeshPart?, ringThin: MeshPart? } = {}
local templatesState = "idle"

local function loadTemplates()
	templatesState = "loading"
	for _, key in { "dome", "ring", "ringThin" } do
		local ok, part = pcall(function()
			return (AssetService :: any):CreateMeshPartAsync((Content :: any).fromUri((ShieldFx.ASSETS :: any)[key]))
		end)
		if ok and part then
			bare(part)
			part.Material = Enum.Material.SmoothPlastic
			local slots: any = templates
			slots[key] = part
		end
	end
	ShieldFx.stats.meshes = `dome {if templates.dome then "mesh" else "ball"}, foot {if templates.ring then "mesh" else "none"}, rings {if templates.ringThin then "thin mesh" else "adornments"}`
	templatesState = "done"
end

-- Whether C's meshes are loaded (or failed for good). The first call starts
-- loading them; make shields once it returns true.
function ShieldFx.ready(): boolean
	if templatesState == "idle" then
		task.spawn(loadTemplates)
	end
	return templatesState == "done"
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

-- A hexagon outline (flats across X; a frame OUTLINE wide, C-131: BAR's
-- honeycomb cells) where EditableMesh is allowed, else nil.
local function hexMesh(): MeshPart?
	local ok, result = pcall(function()
		local em = (AssetService :: any):CreateEditableMesh()
		local inner = 1 - ShieldFx.OUTLINE
		local ot, ob, it, ib = {}, {}, {}, {}
		for k = 0, 5 do
			local a = math.rad(30 + 60 * k)
			local c, s = math.cos(a), math.sin(a)
			ot[k + 1] = em:AddVertex(Vector3.new(c, 0.5, s))
			ob[k + 1] = em:AddVertex(Vector3.new(c, -0.5, s))
			it[k + 1] = em:AddVertex(Vector3.new(c * inner, 0.5, s * inner))
			ib[k + 1] = em:AddVertex(Vector3.new(c * inner, -0.5, s * inner))
		end
		local function quad(a: number, b: number, c: number, d: number)
			-- both windings: seen from either side of the dome
			em:AddTriangle(a, b, c)
			em:AddTriangle(a, c, b)
			em:AddTriangle(a, c, d)
			em:AddTriangle(a, d, c)
		end
		for k = 1, 6 do
			local n = k % 6 + 1
			quad(ot[k], ot[n], it[n], it[k]) -- top face of the frame
			quad(ob[k], ob[n], ib[n], ib[k]) -- bottom
			quad(ot[k], ob[k], ob[n], ot[n]) -- outer wall
			quad(it[k], ib[k], ib[n], it[n]) -- inner wall
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

-- The beam's start: a generator model's `beam` attachment (its parent, the
-- core, glows by strength), or nil for the placeholder core.
function Methods.setEmitter(s: ShieldFx, emitter: Attachment?)
	if s.coreTarget and s.coreOriginal then
		s.coreTarget.Color = s.coreOriginal
	end
	s.emitter = emitter
	local part = if emitter then emitter.Parent else nil
	s.coreTarget = if part and part:IsA("BasePart") then part else nil
	s.coreOriginal = if s.coreTarget then s.coreTarget.Color else nil
	s.beam.Attachment0 = emitter or s.beamBase
	local placeholder = s.coreTarget == nil
	s.core.Transparency = if placeholder then 0 else 1
	s.coreLight.Enabled = placeholder
end

-- A hit at `worldPos` (projected onto the dome); `intensity` 1 = a typical shell.
function Methods.hit(s: ShieldFx, worldPos: Vector3, intensity: number)
	if s.state ~= "up" and s.state ~= "deploying" then
		return
	end
	Shield.hit(s.model, { x = worldPos.X, y = worldPos.Y, z = worldPos.Z }, intensity, clock)
	s.pulse = math.min(1, s.pulse + 0.3 * intensity)
end

function Methods.destroy(s: ShieldFx)
	local i = table.find(shields, s)
	if i then
		table.remove(shields, i)
	end
	if s.coreTarget then
		s.setEmitter(s, nil) -- leave the generator's core as it was
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

local function ringPart(folder: Folder, template: MeshPart): MeshPart
	local p = template:Clone()
	p.Material = Enum.Material.Neon
	p.Color = ShieldFx.RING_COLOR
	p.Transparency = 1
	p.Parent = folder
	return p
end

-- A shield dome of `radius` studs round `base` (default: the emitter's
-- position), the beam rising from `emitter` (an Attachment, e.g. a
-- generator's `beam`, or a position for a placeholder core); down until
-- deploy(). Call once ShieldFx.ready() is true for C's meshes.
function ShieldFx.new(emitter: Attachment | Vector3, radius: number, teamColor: Color3?, base: Vector3?): ShieldFx
	ShieldFx.ready()
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
	local attachment = if typeof(emitter) == "Instance" then emitter :: Attachment else nil
	local position = base or (if attachment then attachment.WorldPosition else emitter :: Vector3)
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
	-- the dome: C's hemisphere (centre half-way up), else a ball
	local dome: BasePart
	local domeMesh = templates.dome ~= nil
	if templates.dome then
		local m = templates.dome:Clone()
		m.Size = Vector3.new(2 * radius, radius, 2 * radius)
		m.Position = position + Vector3.new(0, radius / 2, 0)
		dome = m
	else
		local p = Instance.new("Part")
		bare(p)
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 2 * radius
		p.Position = position
		dome = p
	end
	dome.Name = "Dome"
	dome.Material = Enum.Material.SmoothPlastic
	dome.Color = ShieldFx.DOME_COLOR
	dome.Transparency = 1
	dome.Parent = folder
	-- C's specks inside
	local specks = Instance.new("ParticleEmitter")
	specks.Texture = ShieldFx.ASSETS.speck
	specks.Shape = Enum.ParticleEmitterShape.Sphere
	specks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	specks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	specks.Rate = math.clamp(radius / 3, 4, 40)
	specks.Lifetime = NumberRange.new(3, 6)
	specks.Speed = NumberRange.new(0.3, 1)
	specks.SpreadAngle = Vector2.new(180, 180)
	specks.LightEmission = 1
	specks.Color = ColorSequence.new(WHITE)
	specks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(0.8, 0.5), NumberSequenceKeypoint.new(1, 0) })
	specks.Transparency = NumberSequence.new(0.2)
	specks.Enabled = false
	specks.TimeScale = math.max(particleScale, 0.001)
	specks.Parent = dome
	-- the placeholder core (hidden when the emitter is a generator's part)
	local core = Instance.new("Part")
	core.Name = "Core"
	bare(core)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Size = Vector3.one * math.clamp(radius / 12, 1.5, 6)
	core.Position = (if attachment then attachment.WorldPosition else position) + Vector3.new(0, core.Size.Y * 0.6, 0)
	core.Parent = folder
	local coreLight = Instance.new("PointLight")
	coreLight.Range = math.clamp(radius / 4, 8, 20)
	coreLight.Brightness = 2
	coreLight.Parent = core
	-- C's beam: from the emitter, bending, to the top (its top end climbs on deploy)
	local beamBase = Instance.new("Attachment")
	beamBase.Parent = anchor
	beamBase.WorldPosition = core.Position + Vector3.new(0, core.Size.Y / 2, 0)
	local beamTop = Instance.new("Attachment")
	beamTop.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment1 = beamTop
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(WHITE)
	beam.Width0 = math.clamp(radius / 55, 0.8, 3)
	beam.Width1 = math.clamp(radius / 100, 0.5, 1.5)
	beam.Texture = ShieldFx.ASSETS.beam
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = beam.Width0 * 2
	beam.TextureSpeed = 1
	beam.Transparency = NumberSequence.new(0)
	beam.CurveSize0 = radius * 0.4
	beam.CurveSize1 = -radius * 0.12
	beam.Segments = 24
	beam.Enabled = false
	beam.Parent = anchor
	-- C's swirl at the top: a disc with the swirl on its top face, turning
	local swirl = Instance.new("Part")
	swirl.Name = "Swirl"
	bare(swirl)
	swirl.Transparency = 1
	swirl.Size = Vector3.new(radius * ShieldFx.SWIRL_SIZE, 0.05, radius * ShieldFx.SWIRL_SIZE)
	swirl.Position = position + Vector3.new(0, radius - 0.3, 0)
	swirl.Parent = folder
	local swirlDecal = Instance.new("Decal")
	swirlDecal.Face = Enum.NormalId.Top
	swirlDecal.Texture = ShieldFx.ASSETS.swirl
	swirlDecal.Color3 = WHITE
	swirlDecal.Transparency = 1
	swirlDecal.Parent = swirl
	-- the edge and the ground flash: adornments on the anchor
	local edge = adornment(folder, anchor, WHITE)
	local edgeGlow = adornment(folder, anchor, ShieldFx.DOME_COLOR)
	local flash = adornment(folder, anchor, WHITE)
	-- the flowing rings (C's RingThin, else adornments) and C's ring at the foot
	local rings: { any } = {}
	local foot: BasePart? = nil
	local ringMesh = templates.ringThin ~= nil
	for i = 1, ShieldLook.RINGS do
		rings[i] = if templates.ringThin then ringPart(folder, templates.ringThin) else adornment(folder, anchor, ShieldFx.RING_COLOR)
	end
	if templates.ring then
		local f = ringPart(folder, templates.ring)
		f.Name = "Foot"
		f.Size = Vector3.new(2.02 * radius, math.max(0.4, radius * ShieldFx.RING_TUBE * 2), 2.02 * radius)
		f.Position = position + Vector3.new(0, 0.15, 0)
		foot = f
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
		emitter = nil,
		coreTarget = nil,
		coreOriginal = nil,
		position = position,
		model = Shield.newDome({ x = position.X, y = position.Y, z = position.Z }, radius),
		folder = folder,
		anchor = anchor,
		dome = dome,
		domeMesh = domeMesh,
		specks = specks,
		core = core,
		coreLight = coreLight,
		beam = beam,
		beamTop = beamTop,
		beamBase = beamBase,
		swirl = swirl,
		swirlDecal = swirlDecal,
		edge = edge,
		edgeGlow = edgeGlow,
		rings = rings,
		ringMesh = ringMesh,
		foot = foot,
		flash = flash,
		bar = bar,
		barFill = fill,
		barText = text,
	}, Methods) :: any
	s:setEmitter(attachment)
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

local function hideRing(s: ShieldFx, ring: any)
	if s.ringMesh then
		ring.Transparency = 1
	else
		ring.Visible = false
	end
end

local function hideDetail(s: ShieldFx)
	for _, r in s.rings do
		hideRing(s, r)
	end
	s.flash.Visible = false
	s.beam.Enabled = false
	s.specks.Enabled = false
	s.swirlDecal.Transparency = 1
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
	if s.emitter and s.emitter.Parent == nil then
		s:setEmitter(nil) -- its model went (streamed out, pooled)
	end
	local center = s.position
	local beamK, scale, flashK, collapseFlicker = ShieldLook.phase(s.state, since)
	local R = s.radius * scale
	-- the core shows the strength whatever the state
	local r8, g8, b8 = Shield.coreColor(s.strength)
	local coreColor = Color3.fromRGB(r8, g8, b8)
	if s.coreTarget then
		s.coreTarget.Color = coreColor
	else
		s.core.Color = coreColor
		s.coreLight.Color = coreColor
	end
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
		if s.foot then
			s.foot.Transparency = 1
		end
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
	local Rs = math.max(R, 0.005)
	if s.domeMesh then
		local size = Vector3.new(2 * Rs, Rs, 2 * Rs)
		if s.dome.Size ~= size then
			s.dome.Size = size
			s.dome.Position = center + Vector3.new(0, Rs / 2, 0)
		end
	else
		local size = Vector3.one * 2 * Rs
		if s.dome.Size ~= size then
			s.dome.Size = size
		end
	end
	s.dome.Transparency = if R > 0.05 then 1 - domeAlpha else 1
	if s.foot then
		local footAlpha = ShieldFx.FOOT_OPACITY * opacity
		s.foot.Transparency = if R > 0.05 then 1 - footAlpha else 1
		local size = Vector3.new(2.02 * Rs, s.foot.Size.Y, 2.02 * Rs)
		if s.foot.Size ~= size then
			s.foot.Size = size
		end
	end
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
	-- the beam: its top end climbs from the emitter to the dome's top on deploy
	local startY = (s.beam.Attachment0 :: Attachment).WorldPosition.Y - center.Y
	local topY = s.radius - 0.5
	s.beam.Enabled = beamK > 0.01
	s.beamTop.Position = Vector3.new(0, startY + (topY - startY) * beamK, 0)
	-- the rings: slide down, resized to the curve at their height, fade near the ground
	local speed, bright = ShieldLook.ringFlow(s.strength)
	s.phase += dt * speed / ShieldLook.RING_PERIOD
	local ringW = math.max(0.15, R * ShieldFx.RING_TUBE)
	for i, ring in s.rings do
		local _, rf, yf, a = ShieldLook.ringAt(i, #s.rings, s.phase)
		local alpha = ShieldFx.RING_OPACITY * a * bright * opacity
		if R > 0.05 and alpha > 0.01 then
			local rr = R * rf
			if s.ringMesh then
				-- C's RingThin: Size (2.004r, height, 2.004r) at height h, r = √(R² − h²)
				ring.Size = Vector3.new(2.004 * rr, ringW, 2.004 * rr)
				ring.CFrame = CFrame.new(center.X, center.Y + R * yf, center.Z)
				ring.Transparency = 1 - alpha
			else
				ring.CFrame = CFrame.new(0, R * yf, 0) * FLAT
				ring.Radius = rr
				ring.InnerRadius = math.max(rr - ringW, 0)
				ring.Transparency = 1 - alpha
				ring.Visible = true
			end
		else
			hideRing(s, ring)
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
	-- C's swirl turns at the top; specks drift
	local up = s.state == "up"
	s.specks.Enabled = up
	s.swirlDecal.Transparency = if up then 1 - ShieldFx.SWIRL_OPACITY * opacity else 1
	if up then
		s.swirl.CFrame = CFrame.new(center + Vector3.new(0, R - 0.3, 0)) * CFrame.Angles(0, -now * 0.9 * speed, 0)
	end
	-- this shield's hit patches, plates from the shared pool
	Shield.expire(s.model, now)
	for _, patch in s.model.patches do
		for _, p in patch.plates do
			local heat, alpha, dent = Shield.plateLook(patch, p.ring, now)
			if alpha > 0 and platesLit < #plates then
				platesLit += 1
				local plate = plates[platesLit]
				local nrm = Vector3.new(p.normal.x, p.normal.y, p.normal.z)
				local cf = CFrame.fromMatrix(Vector3.new(p.pos.x, p.pos.y, p.pos.z) + nrm * (0.15 - dent), Vector3.new(p.right.x, p.right.y, p.right.z), nrm)
				local size = plateSize * p.scale -- bigger toward the centre (C-132)
				local hr, hg, hb = Shield.color(heat)
				local color = Color3.fromRGB(hr, hg, hb)
				for k, part in plate.parts do
					table.insert(plateParts, part)
					table.insert(plateCFrames, if #plate.parts == 1 then cf else cf * CFrame.Angles(0, math.rad(60 * (k - 1)), 0))
					part.Color = color
					part.Transparency = 1 - alpha * ShieldFx.PLATE_OPACITY
					if #plate.parts == 1 then
						part.Size = size
					end
				end
			end
		end
	end
	return true
end

step = function(realDt: number)
	local t0 = os.clock()
	local scale = ShieldFx.timeScale * ShieldFx.simSpeed
	local dt = realDt * scale
	if scale ~= particleScale then
		-- particles (specks) keep the same clock
		particleScale = scale
		for _, s in shields do
			s.specks.TimeScale = math.max(scale, 0.001)
		end
	end
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

-- A clone of one of C's meshes ("dome", "ring", "ringThin"), or nil before
-- they load or if they failed.
function ShieldFx.cloneMesh(key: string): MeshPart?
	local t = (templates :: any)[key]
	return if t then t:Clone() else nil
end

-- Every shield (debug calls).
function ShieldFx.all(): { ShieldFx }
	return shields
end

return ShieldFx

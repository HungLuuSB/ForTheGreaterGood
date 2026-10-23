--!strict
-- The beam towers' shot effect (models-C's Meshes.beam, fx.md "Beam shot";
-- their reference assets/fx/beam/BeamShot.luau, C-133): a white-hot core,
-- a wide glow and jittering filaments as Beams between two attachments, a
-- charge flipbook and a star flare at the muzzle, an impact flare and a
-- scorch decal (models-C's values: widths, tip, fan, flares). Drawn
-- for the shot's whole duration (the sim's beamDuration: Radiance 3 s,
-- Inferno 1.5 s, Core/Effects.beamSeconds) with C's taper at its end; the
-- beam narrows to a point at the target end (the user).
-- Used once the entry is approved (or with ANYWAY for review); until then
-- Render/Effects draws its placeholder ray.

local ContentProvider = game:GetService("ContentProvider")

local Meshes = require("@shared/Defs/Meshes/Registry")

local BeamShots = {}

BeamShots.ANYWAY = game:GetService("RunService"):IsStudio() -- review assets show in Studio, where the user reviews them (C-142); Invoke("beamsanyway", false) turns it off
BeamShots.MAX = 8 -- shots drawn at once (the oldest is dropped)

local entry = (Meshes :: any).beam

export type Rig = {
	F: any,
	faction: string,
	anchor: Part,
	muzzle: Attachment,
	hit: Attachment,
	core: Beam,
	glow: Beam,
	filaments: { { beam: Beam, a0: Attachment, a1: Attachment } },
	charge: BillboardGui,
	flare: BillboardGui, -- the star on the emitter ball while firing
	impact: BillboardGui,
	scorch: Part,
	soot: Decal,
	embers: Decal,
	age: number, -- seconds of game time since the shot (follows the game speed)
	life: number, -- the beam's duration
	span: number, -- when (in age) the scorch is gone too
	seed: number,
}

export type State = {
	folder: Folder,
	rigs: { [any]: Rig }, -- by tracer
	free: { Rig },
	count: number,
	preloaded: boolean,
	last: number, -- the previous step's clock
}

function BeamShots.enabled(): boolean
	return entry ~= nil and (entry.status == "approved" or BeamShots.ANYWAY)
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

function BeamShots.new(parent: Instance): State
	local folder = Instance.new("Folder")
	folder.Name = "BeamShots"
	folder.Parent = parent
	return { folder = folder, rigs = {}, free = {}, count = 0, preloaded = false, last = 0 }
end

-- An unloaded Beam texture draws as a flat bar (models-C): load them first.
local function preload(s: State)
	if s.preloaded or entry == nil then
		return
	end
	s.preloaded = true
	local ids = {}
	for _, id in entry.textures do
		local d = Instance.new("Decal")
		d.Texture = id
		table.insert(ids, d)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(ids)
		end)
	end)
end

local function beam(name: string, a0: Attachment, a1: Attachment, tex: string, len: number, color: Color3, brightness: number, segments: number, parent: Instance): Beam
	local b = Instance.new("Beam")
	b.Name = name
	b.Attachment0, b.Attachment1 = a0, a1
	b.Texture = tex
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = len
	b.Color = ColorSequence.new(color)
	b.Brightness = brightness
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = segments
	b.Enabled = false
	b.Parent = parent
	return b
end

local function billboard(name: string, adornee: Attachment, image: string, color: Color3): BillboardGui
	local g = Instance.new("BillboardGui")
	g.Name = name
	g.LightInfluence = 0
	g.Brightness = 4
	g.Enabled = false
	local img = Instance.new("ImageLabel")
	img.Name = "Image"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = color
	img.Parent = g
	g.Parent = adornee
	return g
end

-- One rig for `faction` (models-C's build, on a hidden anchor of our own).
local function build(s: State, faction: string): Rig
	local raw = entry.factions[faction] or entry.factions.order
	local T = entry.textures
	local F = table.clone(raw)
	F.coreColor, F.glowColor, F.filamentColor = rgb(raw.coreColor), rgb(raw.glowColor), rgb(raw.filamentColor)
	local anchor = Instance.new("Part")
	anchor.Name = "Shot"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Parent = s.folder
	local muzzle, hit = Instance.new("Attachment"), Instance.new("Attachment")
	muzzle.Parent, hit.Parent = anchor, anchor
	local rig: Rig = {
		F = F,
		faction = faction,
		anchor = anchor,
		muzzle = muzzle,
		hit = hit,
		core = beam("Core", muzzle, hit, T.core, F.texLen.core, F.coreColor, F.brightness, 1, anchor),
		glow = beam("Glow", muzzle, hit, T.glow, F.texLen.glow, F.glowColor, F.glowBrightness, 1, anchor),
		filaments = {},
		charge = billboard("Charge", muzzle, T.charge, F.coreColor),
		flare = billboard("Flare", muzzle, T.charge, F.coreColor),
		impact = billboard("Impact", hit, T.impact, F.coreColor),
		scorch = nil :: any,
		soot = nil :: any,
		embers = nil :: any,
		age = 0,
		life = 0,
		span = 0,
		seed = if faction == "order" then 1 else 2,
	}
	rig.charge.Image.ImageRectSize = Vector2.new(256, 256)
	rig.flare.Image.ImageRectSize = Vector2.new(256, 256)
	rig.flare.Image.ImageRectOffset = Vector2.new(256, 256) -- the full star (frame 4)
	-- billboards are depth-tested: pulled toward the camera so the ball and
	-- the target's face don't hide half of each flare (models-C)
	rig.charge.StudsOffset = Vector3.new(0, 0, 1.2)
	rig.flare.StudsOffset = Vector3.new(0, 0, 1.2)
	rig.impact.StudsOffset = Vector3.new(0, 0, F.impactSize * 0.5)
	for i = 1, F.filaments do
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Parent, a1.Parent = anchor, anchor
		local ab = if i % 2 == 1 then "filamentA" else "filamentB"
		local b = beam(`Filament{i}`, a0, a1, T[ab], F.texLen[ab], F.filamentColor, F.filamentBrightness, 16, anchor)
		b.TextureSpeed = F.speed[ab]
		table.insert(rig.filaments, { beam = b, a0 = a0, a1 = a1 })
	end
	local sc = Instance.new("Part")
	sc.Name = "Scorch"
	sc.Anchored, sc.CanCollide, sc.CanQuery, sc.CanTouch = true, false, false, false
	sc.Transparency = 1
	sc.Size = Vector3.new(F.scorchSize, 0.05, F.scorchSize)
	sc.Parent = anchor
	local d = Instance.new("Decal")
	d.Face = Enum.NormalId.Top
	d.Texture = T.scorch
	d.Transparency = 1
	d.Parent = sc
	local g = Instance.new("Decal")
	g.Face = Enum.NormalId.Top
	g.Texture = T.scorchGlow
	g.Color3 = Color3.new(F.glowColor.R * 4, F.glowColor.G * 4, F.glowColor.B * 4) -- overbright: a Decal can't emit
	g.Transparency = 1
	g.ZIndex = 2
	g.Parent = sc
	rig.scorch, rig.soot, rig.embers = sc, d, g
	return rig
end

local function hide(rig: Rig)
	rig.core.Enabled, rig.glow.Enabled = false, false
	for _, f in rig.filaments do
		f.beam.Enabled = false
	end
	rig.charge.Enabled, rig.flare.Enabled, rig.impact.Enabled = false, false, false
	rig.soot.Transparency, rig.embers.Transparency = 1, 1
end

local function seq(v: number): NumberSequence
	return NumberSequence.new(math.clamp(v, 0, 1))
end

-- models-C's apply (assets/fx/beam/BeamShot.luau, synced 786d85c): the
-- charge, the beam on for the shot's duration with C's taper at its end,
-- the impact hot spot held while it burns, then the scorch.
local function apply(rig: Rig, t: number)
	local F = rig.F
	local tOn = F.charge
	local tEnd = tOn + (if rig.life > 0 then rig.life else F.duration) -- on for the shot's beamDuration (the sim's), the taper at its end
	-- charge flare: the four flipbook frames over the charge, then a quick fade
	local cf = rig.charge
	if t < tOn + 0.04 then
		local frame = math.clamp(math.floor(t / F.charge * 4), 0, 3)
		cf.Enabled = true
		cf.Image.ImageRectOffset = Vector2.new((frame % 2) * 256, math.floor(frame / 2) * 256)
		local size = F.flareSize * (0.55 + 0.45 * frame / 3)
		cf.Size = UDim2.fromScale(size, size)
		cf.Image.ImageTransparency = if t > tOn then (t - tOn) / 0.04 else 0
	else
		cf.Enabled = false
	end
	-- the beam
	local on = t >= tOn and t < tEnd
	local u = math.clamp((t - (tEnd - F.taper)) / F.taper, 0, 1)
	local frame = math.floor(t * 30) -- new jitter 30 times a second
	local pulse = 1 + 0.06 * (Random.new(rig.seed * 31 + frame):NextNumber() * 2 - 1) -- the core breathes while it holds
	rig.core.Enabled, rig.glow.Enabled = on, on
	local w = F.coreWidth * (1 - u) ^ 1.1 * pulse
	rig.core.Width0, rig.core.Width1 = w, w * F.tip -- full at the muzzle, a point at the target
	rig.core.Transparency = seq(0.7 * u ^ 1.6)
	local gw = F.glowWidth * (1 - u) ^ 0.8
	rig.glow.Width0, rig.glow.Width1 = gw, gw * F.tip
	rig.glow.Transparency = seq(0.35 + 0.65 * u)
	local p0, p1 = rig.muzzle.WorldPosition, rig.hit.WorldPosition
	local dir = if (p1 - p0).Magnitude > 1e-3 then (p1 - p0).Unit else Vector3.zAxis
	local side = if math.abs(dir.Y) < 0.99 then dir:Cross(Vector3.yAxis).Unit else Vector3.xAxis
	local up = side:Cross(dir).Unit
	for i, f in rig.filaments do
		f.beam.Enabled = on
		local fw = F.filamentWidth * (1 - u) ^ 2.2
		f.beam.Width0, f.beam.Width1 = fw, fw * F.tip
		f.beam.Transparency = seq(0.8 * u ^ 1.2)
		local rng = Random.new(rig.seed * 100000 + frame * 17 + i)
		local a = (i / #rig.filaments) * 2 * math.pi + (rng:NextNumber() - 0.5) * F.jitter * 2
		local r = F.spread * (0.6 + 0.4 * rng:NextNumber())
		local o0 = (side * math.cos(a) + up * math.sin(a)) * r
		local a2 = a + (rng:NextNumber() - 0.5) * F.jitter
		local o1 = (side * math.cos(a2) + up * math.sin(a2)) * r * F.fan
		f.a0.WorldPosition = p0 + o0
		f.a1.WorldPosition = p1 + o1
		f.beam.CurveSize0 = (rng:NextNumber() * 2 - 1) * F.curve
		f.beam.CurveSize1 = (rng:NextNumber() * 2 - 1) * F.curve
	end
	-- muzzle flare: the full star on the emitter ball while the beam is on,
	-- flickering and turning a little each frame, shrinking with the taper
	local mf = rig.flare
	mf.Enabled = on
	if on then
		local rng = Random.new(rig.seed * 7919 + frame)
		local size = F.muzzleFlareSize * (1 - u) ^ 0.8 * (0.85 + 0.3 * rng:NextNumber())
		mf.Size = UDim2.fromScale(size, size)
		mf.Image.Rotation = rng:NextNumber() * 30 - 15
		mf.Image.ImageTransparency = 0.6 * u
	end
	-- impact flare at the hit: a burst as the beam lands (impactTime), then
	-- a flickering hot spot while the beam holds, shrinking with the taper
	local im = rig.impact
	local k = (t - tOn) / F.impactTime
	im.Enabled = on
	if on then
		local rng = Random.new(rig.seed * 4241 + frame)
		local burst = if k < 1 then 0.5 + 0.7 * math.min(1, k * 4) - 0.5 * math.max(0, k - 0.25) / 0.75 else 0.7
		local size = F.impactSize * burst * (1 - u) ^ 0.7 * (0.9 + 0.2 * rng:NextNumber())
		im.Size = UDim2.fromScale(size, size)
		im.StudsOffset = Vector3.new(0, 0, size * 0.5)
		im.Image.Rotation = rng:NextNumber() * 40 - 20
		im.Image.ImageTransparency = if k < 1 then 0 else 0.15 + 0.6 * u
	end
	-- scorch: appears as the beam lands; the embers glow while it burns and
	-- fade over scorchGlowTime after it ends; the soot stays scorchTime after
	-- the beam, fading over its last 1.5 s
	local ts = t - tOn - 0.02
	local after = t - tEnd
	if ts >= 0 and after < F.scorchTime then
		rig.soot.Transparency = math.max(0, (after - (F.scorchTime - 1.5)) / 1.5)
		rig.embers.Transparency = math.clamp(after / F.scorchGlowTime, 0, 1) ^ 0.7
	else
		rig.soot.Transparency, rig.embers.Transparency = 1, 1
	end
end

-- Once a frame: a rig for each new beam tracer (Core/Effects' Tracer with
-- `beam`), each rig run to the end of its scorch, then pooled.
-- `groundY(x, z)` places the scorch; `speed` the game speed (a slowed game
-- slows the shot too).
function BeamShots.step(s: State, tracers: { any }, now: number, groundY: (number, number) -> number, speed: number?)
	local dt = math.clamp(now - s.last, 0, 0.25) * (speed or 1)
	s.last = now
	if not BeamShots.enabled() then
		return
	end
	preload(s)
	for _, t in tracers do
		if t.beam and s.rigs[t] == nil and s.count < BeamShots.MAX then
			local rig: Rig? = nil
			for i, r in s.free do
				if r.faction == t.beam then
					rig = table.remove(s.free, i)
					break
				end
			end
			local r = rig or build(s, t.beam)
			r.age, r.life = 0, t.life
			r.span = r.F.charge + t.life + r.F.scorchTime + 0.1
			r.muzzle.WorldPosition = Vector3.new(t.x0, t.y0, t.z0)
			r.hit.WorldPosition = Vector3.new(t.x1, t.y1, t.z1)
			r.scorch.CFrame = CFrame.new(t.x1, groundY(t.x1, t.z1) + 0.03, t.z1)
			s.rigs[t] = r
			s.count += 1
		end
	end
	for t, r in s.rigs do
		r.age += dt
		-- the beam's end can move (a dome dropped under it, C-144)
		local hx, hy, hz = t.x1, t.y1, t.z1
		if hx and (r.hit.WorldPosition - Vector3.new(hx, hy, hz)).Magnitude > 0.01 then
			r.hit.WorldPosition = Vector3.new(hx, hy, hz)
		end
		if r.age >= r.span then
			hide(r)
			s.rigs[t] = nil
			s.count -= 1
			table.insert(s.free, r)
		else
			apply(r, r.age)
		end
	end
end

return BeamShots

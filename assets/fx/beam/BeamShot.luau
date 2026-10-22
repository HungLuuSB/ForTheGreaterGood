--!strict
-- Reference beam shot for the beam towers (models stream; docs/contracts/fx.md
-- "Beam shot"). Everything is a pure function of the time since the shot
-- started, so the same t always gives the same frame: B can copy `build` and
-- `apply` into the client's beam effect. Textures are white, tinted here.
local RunService = game:GetService("RunService")

local BeamShot = {}

BeamShot.TEX = {
	core = "rbxassetid://84580715736855",
	glow = "rbxassetid://140653615912799",
	filamentA = "rbxassetid://130559041254740",
	filamentB = "rbxassetid://71590951128896",
	charge = "rbxassetid://95187819936446", -- 2 x 2 flipbook, 256 px frames
	impact = "rbxassetid://121983330106046",
	scorch = "rbxassetid://108024950155994", -- dark soot, not tinted
	scorchGlow = "rbxassetid://83492274682254",
}

-- recommended values (fx.md "Beam shot"): Radiance thicker and longer,
-- Inferno shorter, hotter and more ragged
BeamShot.FACTIONS = {
	order = {
		charge = 0.08, hold = 0.04, taper = 0.38, -- beam gone at 0.50 s
		coreWidth = 0.9, glowWidth = 1.1, filamentWidth = 1.1, filaments = 4, -- nothing wider than the emitter ball (1.12 studs)
		spread = 0.15, fan = 0.3, tip = 0.06, jitter = 0.45, curve = 1.6, -- tip: width at the target / at the muzzle
		coreColor = Color3.fromRGB(225, 248, 255), glowColor = Color3.fromRGB(80, 190, 255),
		filamentColor = Color3.fromRGB(165, 232, 255), brightness = 2, glowBrightness = 0.6, filamentBrightness = 3,
		texLen = { core = 30, glow = 60, filamentA = 20, filamentB = 15 },
		speed = { filamentA = 30, filamentB = 40 }, -- tiles per second: 600 studs/s
		flareSize = 4, muzzleFlareSize = 5, impactSize = 5, impactTime = 0.3, scorchSize = 7, scorchTime = 4, scorchGlowTime = 1.2,
	},
	chaos = {
		charge = 0.06, hold = 0.03, taper = 0.27, -- beam gone at 0.36 s
		coreWidth = 0.5, glowWidth = 0.6, filamentWidth = 0.6, filaments = 3, -- the emitter ball is 0.6 studs
		spread = 0.08, fan = 0.3, tip = 0.08, jitter = 0.7, curve = 2.2,
		coreColor = Color3.fromRGB(255, 205, 150), glowColor = Color3.fromRGB(255, 85, 15),
		filamentColor = Color3.fromRGB(255, 130, 35), brightness = 2.4, glowBrightness = 0.8, filamentBrightness = 3.4,
		texLen = { core = 24, glow = 50, filamentA = 16, filamentB = 12 },
		speed = { filamentA = 40, filamentB = 52 }, -- tiles per second: 640 studs/s
		flareSize = 2.5, muzzleFlareSize = 3, impactSize = 4, impactTime = 0.25, scorchSize = 6, scorchTime = 3, scorchGlowTime = 1.0,
	},
}

local function beam(name: string, a0: Attachment, a1: Attachment, tex: string, len: number, color: Color3, brightness: number, segments: number): Beam
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
	b.Parent = a0.Parent
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

-- Builds one shot's instances between `muzzle` (on the tower) and `hit` (on
-- the target); `ground` is the ground height under the hit for the scorch.
function BeamShot.build(faction: string, muzzle: Attachment, hit: Attachment, ground: number): any
	local F = (BeamShot.FACTIONS :: any)[faction]
	local rig: any = { F = F, muzzle = muzzle, hit = hit, filaments = {}, seed = faction == "order" and 1 or 2 }
	rig.core = beam("BeamCore", muzzle, hit, BeamShot.TEX.core, F.texLen.core, F.coreColor, F.brightness, 1)
	rig.glow = beam("BeamGlow", muzzle, hit, BeamShot.TEX.glow, F.texLen.glow, F.glowColor, F.glowBrightness, 1)
	for i = 1, F.filaments do
		local a0 = Instance.new("Attachment")
		a0.Name = `filament{i}_0`
		a0.Parent = muzzle.Parent
		local a1 = Instance.new("Attachment")
		a1.Name = `filament{i}_1`
		a1.Parent = hit.Parent
		local ab = i % 2 == 1 and "filamentA" or "filamentB"
		local b = beam(`BeamFilament{i}`, a0, a1, (BeamShot.TEX :: any)[ab], F.texLen[ab], F.filamentColor, F.filamentBrightness, 16)
		b.TextureSpeed = F.speed[ab]
		table.insert(rig.filaments, { beam = b, a0 = a0, a1 = a1 })
	end
	rig.charge = billboard("ChargeFlare", muzzle, BeamShot.TEX.charge, F.coreColor)
	rig.charge.Image.ImageRectSize = Vector2.new(256, 256)
	rig.flare = billboard("MuzzleFlare", muzzle, BeamShot.TEX.charge, F.coreColor)
	rig.flare.Image.ImageRectSize = Vector2.new(256, 256)
	rig.flare.Image.ImageRectOffset = Vector2.new(256, 256) -- the full star (frame 4)
	rig.impact = billboard("ImpactFlare", hit, BeamShot.TEX.impact, F.coreColor)
	-- billboards are depth-tested: pull the flares towards the camera so the
	-- emitter ball and the target's face don't hide half of them
	rig.charge.StudsOffset = Vector3.new(0, 0, 1.2)
	rig.flare.StudsOffset = Vector3.new(0, 0, 1.2)
	rig.impact.StudsOffset = Vector3.new(0, 0, F.impactSize * 0.5)
	local s = Instance.new("Part")
	s.Name = "Scorch"
	s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch = true, false, false, false
	s.Transparency = 1
	s.Size = Vector3.new(F.scorchSize, 0.05, F.scorchSize)
	s.CFrame = CFrame.new(hit.WorldPosition.X, ground + 0.03, hit.WorldPosition.Z)
	s.Parent = hit.Parent
	local d = Instance.new("Decal")
	d.Name = "Soot"
	d.Face = Enum.NormalId.Top
	d.Texture = BeamShot.TEX.scorch
	d.Transparency = 1
	d.Parent = s
	local g = Instance.new("Decal")
	g.Name = "Embers"
	g.Face = Enum.NormalId.Top
	g.Texture = BeamShot.TEX.scorchGlow
	g.Color3 = Color3.new(F.glowColor.R * 4, F.glowColor.G * 4, F.glowColor.B * 4) -- overbright: a Decal can't emit, this makes it glow
	g.Transparency = 1
	g.ZIndex = 2
	g.Parent = s
	rig.soot, rig.embers = d, g
	return rig
end

local function seq(v: number): NumberSequence
	return NumberSequence.new(math.clamp(v, 0, 1))
end

-- Sets every instance for time t (seconds since the shot started).
function BeamShot.apply(rig: any, t: number)
	local F = rig.F
	local tOn = F.charge
	local tEnd = tOn + F.hold + F.taper
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
	local u = math.clamp((t - tOn - F.hold) / F.taper, 0, 1)
	rig.core.Enabled, rig.glow.Enabled = on, on
	local w = F.coreWidth * (1 - u) ^ 1.1
	rig.core.Width0, rig.core.Width1 = w, w * F.tip -- full at the muzzle, a point at the target
	rig.core.Transparency = seq(0.7 * u ^ 1.6)
	local gw = F.glowWidth * (1 - u) ^ 0.8
	rig.glow.Width0, rig.glow.Width1 = gw, gw * F.tip
	rig.glow.Transparency = seq(0.35 + 0.65 * u)
	local p0, p1 = rig.muzzle.WorldPosition, rig.hit.WorldPosition
	local dir = (p1 - p0).Unit
	local side = dir:Cross(Vector3.yAxis).Unit
	local up = side:Cross(dir).Unit
	local frame = math.floor(t * 30) -- new jitter 30 times a second
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
	-- impact flare at the hit, as the beam lands
	local im = rig.impact
	local k = (t - tOn) / F.impactTime
	if k >= 0 and k < 1 then
		im.Enabled = true
		local size = F.impactSize * (0.5 + 0.7 * math.min(1, k * 4))
		im.Size = UDim2.fromScale(size, size)
		im.Image.ImageTransparency = k ^ 1.5
	else
		im.Enabled = false
	end
	-- scorch: soot stays, fading over its last 1.5 s; the embers glow first
	local ts = t - tOn - 0.02
	if ts >= 0 and ts < F.scorchTime then
		rig.soot.Transparency = math.max(0, (ts - (F.scorchTime - 1.5)) / 1.5)
		rig.embers.Transparency = math.clamp(ts / F.scorchGlowTime, 0, 1) ^ 0.7
	else
		rig.soot.Transparency, rig.embers.Transparency = 1, 1
	end
end

-- Loops the shot (preview): returns a function that stops it.
function BeamShot.play(rig: any, gap: number?): () -> ()
	local period = rig.F.charge + rig.F.scorchTime + (gap or 1)
	local t0 = os.clock()
	local conn = RunService.Heartbeat:Connect(function()
		BeamShot.apply(rig, (os.clock() - t0) % period)
	end)
	return function()
		conn:Disconnect()
		BeamShot.apply(rig, period)
	end
end

return BeamShot

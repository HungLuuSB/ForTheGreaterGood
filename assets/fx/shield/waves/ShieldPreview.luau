--!strict
-- Shield energy v4, the reference look (models-C; the user's v3 review
-- 2026-10-24 and the mock-up assets/reference/shield/shield_demo.html;
-- docs/contracts/fx.md "Shield energy"). Not game code: the client's
-- ShieldFx owns the shield in the game and clients-B ports this. It runs in
-- "FTGG Art" for the review frames, so a frame is a pure function of what
-- setFrame gets: new() makes every instance once (fixed pools) and setFrame
-- only moves, shows and fades them.
--
--   local s = ShieldPreview.new({ base = v3, radius = 120, tint = c3, beamFrom = attachment, seed = 1 })
--   s:setFrame({ state = "idle", tState = 2, time = 7.3, hits = { { dir = unitVector, age = 0.2 } } })
--
-- States and timings (the mock-up's): "off"; "pre" (0.22 s: the beam lights
-- and the apex flares); "raise" (1 s: the dome forms from the apex down on
-- the 20 bands, a bright broken arc on its lower edge, then the single dome
-- takes over); "idle"; "collapse" (0.85 s: the reverse, draining up into the
-- apex, a last flash; then "off" and the beam goes out in 0.25 s).
-- The energy waves run whenever the shell shows: a new one leaves the apex
-- every 0.7 s (three in flight on a 2.1 s cycle); during a raise only on the
-- part already formed.

local ShieldPreview = {}
ShieldPreview.__index = ShieldPreview

ShieldPreview.DUR = { pre = 0.22, raise = 1.0, collapse = 0.85, off = 0.25 }
ShieldPreview.BANDS = 20
ShieldPreview.STREAKS = 20
ShieldPreview.WAVES = 3
ShieldPreview.WAVE_CYCLE = 2.1 -- seconds from the apex to the ground; a new wave every WAVE_CYCLE / WAVES
ShieldPreview.RING_JOINTS = 12 -- Beam segments per wave ring (curved, so the ring stays round between joints)
ShieldPreview.EDGE_ARCS = 3
ShieldPreview.EDGE_JOINTS = 6
ShieldPreview.FILAMENTS = 2
ShieldPreview.FILAMENT_SEGMENTS = 8
ShieldPreview.JITTER_STEP = 0.1 -- seconds between re-jitters (filaments, crackle, flickering cells): "every few frames"
ShieldPreview.HITS = 4
ShieldPreview.HIT_LIFE = 0.8
ShieldPreview.PULSE_PERIOD = 0.5 -- a packet reaches the apex every 0.5 s

-- sizes in units of the radius R unless noted
ShieldPreview.SIZE = {
	coreWidth = 0.6, -- studs (the channel's core keeps its width)
	glowWidth = 0.02,
	filamentWidth = 0.18, -- studs
	filamentReach = 0.012, -- how far the zig-zags stray from the core
	flare = 0.15, -- half of v3
	streakWidth = 0.02,
	streakTile = 0.5,
	waveGlowWidth = 0.223, -- the wave_glow texture's band (its leading line at U 0.78)
	waveGlowTile = 0.255, -- one hex period along the band
	waveLineWidth = 0.035,
	waveLineTile = 0.3,
	edgeWidth = 0.03,
}
-- the meshes' bounding-box centres at radius 1 (export/energy.json)
local GRID_CENTER, CAP_CENTER = 0.477818, 0.953714

local Images = {
	pulse = "rbxassetid://140247072686648",
	glow = "rbxassetid://112656457330596",
	line = "rbxassetid://124267731373106",
	spark = "rbxassetid://92194209333839",
	flare = "rbxassetid://123552515265600",
	streak = "rbxassetid://78404950994283",
	field = "rbxassetid://128868364830447",
	wave_glow = { "rbxassetid://101230899960268", "rbxassetid://122976001906567", "rbxassetid://91679967814767" },
	wave_line = { "rbxassetid://104994993937547", "rbxassetid://73910800096425", "rbxassetid://98445617977251" },
	hit = {
		"rbxassetid://81478126700519",
		"rbxassetid://76961164632491",
		"rbxassetid://91286251098916",
		"rbxassetid://94649966504568",
		"rbxassetid://115569169076815",
		"rbxassetid://119021152259092",
		"rbxassetid://100600971567257",
		"rbxassetid://125377299320930",
	},
}
ShieldPreview.Images = Images

export type Frame = {
	state: string, -- "off" | "pre" | "raise" | "idle" | "collapse"
	tState: number, -- seconds in that state
	time: number, -- the shield's clock (waves, pulses, jitter)
	hits: { { dir: Vector3, age: number } }?,
}

local PI = math.pi

local function frac(x: number): number
	return x - math.floor(x)
end

local function ease(x: number): number
	return if x < 0.5 then 2 * x * x else 1 - (-2 * x + 2) ^ 2 / 2
end

local function hash(n: number): number
	return frac(math.sin(n) * 43758.5453)
end

-- a point on the sphere of radius r round base: theta from the apex, phi round
local function onSphere(base: Vector3, r: number, theta: number, phi: number): Vector3
	return base + Vector3.new(math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi)) * r
end

-- an attachment frame on the dome: X along `along` (a Beam curves along X), Y across it on the
-- surface (with FaceCamera off a Beam's width runs along Y, so the Beam lies on the dome)
local function surfaceFrame(pos: Vector3, normal: Vector3, along: Vector3): CFrame
	local x = (along - normal * along:Dot(normal)).Unit
	local y = normal:Cross(x).Unit
	return CFrame.fromMatrix(pos, x, y)
end

function ShieldPreview.new(params: any)
	local self = setmetatable({}, ShieldPreview) :: any
	self.p = params
	local R = params.radius
	self.R = R
	self.base = params.base
	self.seed = params.seed or 1
	local tint: Color3 = params.tint
	local RS = game:GetService("ReplicatedStorage") :: any
	local templates = RS.FX.ShieldEnergy
	local S = ShieldPreview.SIZE

	local model = Instance.new("Model")
	model.Name = "ShieldEnergy"
	self.model = model
	local holder = Instance.new("Part")
	holder.Name = "Holder"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(params.base)
	holder.Parent = model

	local function att(name: string): Attachment
		local a = Instance.new("Attachment")
		a.Name = name
		a.Parent = holder
		return a
	end
	local function beam(name: string, a0: Attachment, a1: Attachment, texture: string, width: number, faceCamera: boolean): Beam
		local b = Instance.new("Beam")
		b.Name = name
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = texture
		b.TextureMode = Enum.TextureMode.Wrap
		b.Width0, b.Width1 = width, width
		b.CurveSize0, b.CurveSize1 = 0, 0
		b.FaceCamera = faceCamera
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Color = ColorSequence.new(tint)
		b.Segments = 10
		b.Parent = holder
		return b
	end
	local function billboard(name: string, adornee: Attachment, texture: string): (BillboardGui, ImageLabel)
		local g = Instance.new("BillboardGui")
		g.Name = name
		g.Adornee = adornee
		g.LightInfluence = 0
		g.Brightness = 2
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = texture
		img.ImageColor3 = tint
		img.Parent = g
		g.Parent = holder
		return g, img
	end
	local function part(template: MeshPart, name: string, centreY: number): MeshPart
		-- the templates are the x100 import: radius 1 = 100 studs
		local m = template:Clone()
		m.Name = name
		m.Anchored, m.CanCollide, m.CanQuery, m.CanTouch, m.CastShadow = true, false, false, false, false
		m.Size = template.Size / 100 * R
		m.CFrame = CFrame.new(params.base + Vector3.new(0, centreY * R, 0))
		m.Parent = model
		return m
	end

	-- the shell: the single dome (idle) and the 20 bands (raise, collapse)
	local dome = RS.FX.Shield.Dome:Clone()
	dome.Name = "Dome"
	dome.Size = Vector3.new(2 * R, R, 2 * R)
	dome.CFrame = CFrame.new(params.base + Vector3.new(0, R / 2, 0))
	dome.Material = Enum.Material.ForceField
	dome.TextureID = Images.field
	dome.Color = params.edge or tint
	dome.Anchored, dome.CanCollide, dome.CanQuery, dome.CanTouch, dome.CastShadow = true, false, false, false, false
	dome.Parent = model
	self.dome = dome
	self.bands = {}
	local step = PI / 2 / ShieldPreview.BANDS
	for k = 1, ShieldPreview.BANDS do
		local yMid = (math.cos((k - 1) * step) + math.cos(k * step)) / 2
		local b = part(templates[`Band_{k}`], `Band_{k}`, yMid)
		b.Material = Enum.Material.ForceField
		b.TextureID = Images.field
		b.Color = params.edge or tint
		self.bands[k] = b
	end
	-- the honeycomb: even cells over the whole dome
	local grid = part(templates.HexGrid, "HexGrid", GRID_CENTER)
	grid.Material = Enum.Material.Neon
	grid.Color = tint
	self.grid = grid
	-- hits: a patch of honeycomb cells spreading in a ring, a flipbook in a Decal on the cap's top face
	-- (a Decal on a MeshPart projects onto the mesh; it draws on a fully transparent part, and a Color3
	-- above 1 makes it glow; the MeshPart's own TextureID ignores alpha in Neon and fades out in ForceField)
	self.hits = {}
	for k = 1, ShieldPreview.HITS do
		local h = part(templates.HitCap, `Hit{k}`, CAP_CENTER)
		h.Transparency = 1
		local d = Instance.new("Decal")
		d.Face = Enum.NormalId.Top
		d.Texture = Images.hit[1]
		d.Color3 = Color3.new(tint.R * 3, tint.G * 3, tint.B * 3)
		d.Transparency = 1
		d.Parent = h
		self.hits[k] = d
	end

	-- the channel: a straight core with packets scrolling up, a soft glow, two zig-zag filaments
	local apex = att("Apex")
	apex.WorldPosition = params.base + Vector3.new(0, R, 0)
	self.apex = apex
	local from: Attachment = params.beamFrom
	self.from = from
	local length = (apex.WorldPosition - from.WorldPosition).Magnitude
	self.glow = beam("ChannelGlow", from, apex, Images.glow, S.glowWidth * R, true)
	self.core = beam("ChannelCore", from, apex, Images.pulse, S.coreWidth, true)
	self.core.TextureLength = length / 3 -- three packets in flight
	self.core.TextureSpeed = 2 -- tiles per second: one packet reaches the apex every 0.5 s
	self.core.Brightness = 5
	self.core.ZOffset = 2
	self.filaments = {}
	for f = 1, ShieldPreview.FILAMENTS do
		local pts = {}
		for i = 0, ShieldPreview.FILAMENT_SEGMENTS do
			pts[i] = att(`Fil{f}_{i}`)
		end
		local segs = {}
		for i = 1, ShieldPreview.FILAMENT_SEGMENTS do
			local b = beam(`Fil{f}_{i}`, pts[i - 1], pts[i], Images.line, S.filamentWidth, true)
			b.Brightness = 3
			b.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.7))
			segs[i] = b
		end
		self.filaments[f] = { points = pts, segs = segs }
	end
	self.flicker, self.flickerImg = billboard("EmitterFlicker", from, Images.spark)
	self.flare, self.flareImg = billboard("ApexFlare", apex, Images.flare)

	-- the streaks: curved Beams down the meridians, lying on the dome, unevenly spaced
	local rng = Random.new(self.seed)
	self.streaks = {}
	for k = 1, ShieldPreview.STREAKS do
		local phi = (k - 1) / ShieldPreview.STREAKS * 2 * PI + rng:NextNumber(-0.12, 0.12)
		local a0, a1 = att(`Streak{k}_0`), att(`Streak{k}_1`)
		local b = beam(`Streak{k}`, a0, a1, Images.streak, S.streakWidth * R, false)
		b.TextureLength = S.streakTile * R * rng:NextNumber(0.8, 1.3)
		b.TextureSpeed = rng:NextNumber(0.25, 0.45)
		b.Brightness = 2.5
		b.ZOffset = -1
		b.Segments = 16
		self.streaks[k] = { phi = phi, a0 = a0, a1 = a1, beam = b }
	end

	-- the waves: rings of curved Beam segments, a wide glow band and a thin crackling line
	local function ring(name: string, joints: number, texture: string, width: number, closed: boolean)
		local pts = {}
		for j = 0, joints - 1 do
			pts[j] = att(`{name}_{j}`)
		end
		pts[joints] = if closed then pts[0] else att(`{name}_{joints}`)
		local segs = {}
		for j = 1, joints do
			local b = beam(`{name}_seg{j}`, pts[j - 1], pts[j], texture, width, false)
			b.Segments = 8
			segs[j] = b
		end
		return { points = pts, segs = segs, joints = joints, closed = closed }
	end
	self.waves = {}
	for i = 1, ShieldPreview.WAVES do
		local g = ring(`Wave{i}Glow`, ShieldPreview.RING_JOINTS, Images.wave_glow[1], S.waveGlowWidth * R, true)
		for _, b in g.segs do
			b.TextureLength = S.waveGlowTile * R
			b.Brightness = 1.6
		end
		local l = ring(`Wave{i}Line`, ShieldPreview.RING_JOINTS, Images.wave_line[1], S.waveLineWidth * R, true)
		for _, b in l.segs do
			b.TextureLength = S.waveLineTile * R
			b.Brightness = 3
			b.ZOffset = 1
			b.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.5))
		end
		self.waves[i] = { glow = g, line = l, seed = rng:NextNumber(0, 100) }
	end
	self.edges = {}
	for i = 1, ShieldPreview.EDGE_ARCS do
		local e = ring(`Edge{i}`, ShieldPreview.EDGE_JOINTS, Images.wave_line[1], S.edgeWidth * R, false)
		for _, b in e.segs do
			b.TextureLength = S.waveLineTile * R
			b.Brightness = 4
			b.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.6))
		end
		self.edges[i] = e
	end

	model.Parent = params.parent or workspace
	self:setFrame({ state = "idle", tState = 5, time = 0 })
	return self
end

-- lay a ring through joints (thetas[j], phis[j]) on the sphere of radius r, curved as a circle between them
local function layRing(self: any, ring: any, r: number, thetas: { number }, phis: { number })
	local base = self.base
	local n = ring.joints
	local count = if ring.closed then n else n + 1
	local pos = {}
	for j = 0, count - 1 do
		pos[j] = onSphere(base, r, thetas[j + 1], phis[j + 1])
	end
	for j = 0, count - 1 do
		local prev = if j > 0 then pos[j - 1] elseif ring.closed then pos[count - 1] else pos[j]
		local nxt = if j < count - 1 then pos[j + 1] elseif ring.closed then pos[0] else pos[j]
		ring.points[j].WorldCFrame = surfaceFrame(pos[j], (pos[j] - base).Unit, nxt - prev)
	end
	for j, b in ring.segs do
		local j1 = if ring.closed then j % n else j
		local dphi = (phis[j1 + 1] - phis[j]) % (2 * PI)
		local ringR = r * math.sin((thetas[j] + thetas[j1 + 1]) / 2)
		local k = 4 / 3 * math.tan(dphi / 4) * ringR -- a circular arc's Bezier handles
		b.CurveSize0, b.CurveSize1 = k, k
	end
end

function ShieldPreview.setFrame(self: any, f: Frame)
	local R, base = self.R, self.base
	local D = ShieldPreview.DUR
	local S = ShieldPreview.SIZE
	local t, st = f.time, f.state
	local beamOn, front, edge, flareBoost = 0, 0, 0, 0
	if st == "off" then
		beamOn = math.max(0, 1 - f.tState / D.off)
	elseif st == "pre" then
		beamOn = math.min(1, f.tState / D.pre)
		flareBoost = beamOn
	elseif st == "raise" then
		local p = math.min(1, f.tState / D.raise)
		beamOn, front, flareBoost = 1, ease(p) * 1.05, 0.6
		edge = 1 - math.max(0, (p - 0.85) / 0.15)
	elseif st == "idle" then
		beamOn, front = 1, 1.2
	elseif st == "collapse" then
		local p = math.min(1, f.tState / D.collapse)
		beamOn, front, edge = 1, 1.05 * (1 - ease(p)), 1
		flareBoost = if p > 0.85 then 2.4 * (p - 0.85) / 0.15 else 0.4
	end
	local step = math.floor(t / ShieldPreview.JITTER_STEP)
	local full = st == "idle"

	-- the shell
	self.dome.Transparency = if full then 0 else 1
	for k, b in self.bands do
		local bs = (k - 1) / ShieldPreview.BANDS
		local reveal = if full then 0 else math.clamp((front - bs) * ShieldPreview.BANDS / 1.6, 0, 1)
		b.Transparency = 1 - reveal
	end
	self.grid.Transparency = if full then 0.92 else 1

	-- the channel
	local from: Vector3 = self.from.WorldPosition
	local top: Vector3 = self.apex.WorldPosition
	local axis = top - from
	local show = beamOn > 0.01
	self.core.Enabled, self.glow.Enabled = show, show
	self.core.Transparency = NumberSequence.new(1 - beamOn)
	self.glow.Transparency = NumberSequence.new(1 - 0.55 * beamOn)
	local side = axis.Unit:Cross(Vector3.xAxis).Unit
	local side2 = axis.Unit:Cross(side).Unit
	for fi, fil in self.filaments do
		local rng = Random.new(step * 131 + fi * 17 + self.seed)
		local n = ShieldPreview.FILAMENT_SEGMENTS
		local ang = rng:NextNumber(0, 2 * PI)
		for i = 0, n do
			local off = Vector3.zero
			if i > 0 and i < n then
				ang += rng:NextNumber(0.9, 1.7)
				off = (side * math.cos(ang) + side2 * math.sin(ang)) * rng:NextNumber(0.4, 1) * S.filamentReach * R
			end
			fil.points[i].WorldPosition = from + axis * (i / n) + off
		end
		for _, b in fil.segs do
			b.Enabled = show
			b.Transparency = NumberSequence.new(1 - 0.9 * beamOn)
		end
	end
	local frng = Random.new(step * 7 + self.seed)
	local fs = (0.9 + 0.3 * frng:NextNumber()) * 2.4
	self.flicker.Size = UDim2.fromScale(fs, fs)
	self.flicker.Enabled = show
	self.flickerImg.ImageTransparency = 1 - 0.9 * beamOn
	local phase = frac(t / ShieldPreview.PULSE_PERIOD)
	local arrive = math.exp(-(phase / 0.1) ^ 2) + math.exp(-((phase - 1) / 0.1) ^ 2)
	local unit = S.flare * R
	local size = (if st == "idle" or st == "raise" then 1 + 0.5 * arrive else 0.8) * unit + flareBoost * unit * 1.2
	size *= math.max(beamOn, if flareBoost > 0 then 1 else 0)
	self.flare.Size = UDim2.fromScale(size, size)
	self.flare.Enabled = size > 0.01
	self.flare.Brightness = 2.2 + 1.5 * arrive + flareBoost
	self.flareImg.Rotation = math.deg(t * 0.25)

	-- the streaks: down the formed part of the dome, packets scrolling down them
	local streakTheta = math.min(1, front) * PI / 2 * 0.99
	for _, s in self.streaks do
		local on = (st == "idle" or st == "raise" or st == "collapse") and streakTheta > 0.05
		s.beam.Enabled = on
		if on then
			local r = R * 1.006
			local apexPos = onSphere(base, r, 0, s.phi)
			local endPos = onSphere(base, r, streakTheta, s.phi)
			s.a0.WorldCFrame = surfaceFrame(apexPos, Vector3.yAxis, Vector3.new(math.cos(s.phi), 0, math.sin(s.phi)))
			local tangent = Vector3.new(math.cos(streakTheta) * math.cos(s.phi), -math.sin(streakTheta), math.cos(streakTheta) * math.sin(s.phi))
			s.a1.WorldCFrame = surfaceFrame(endPos, (endPos - base).Unit, tangent)
			local k = 4 / 3 * math.tan(streakTheta / 4) * r
			s.beam.CurveSize0, s.beam.CurveSize1 = k, k
			s.beam.Transparency = if full
				then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.7, 0.7), NumberSequenceKeypoint.new(1, 1) })
				else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 0.2) })
		end
	end

	-- the waves
	local shellOn = st == "raise" or st == "idle" or st == "collapse"
	local J = ShieldPreview.RING_JOINTS
	for i, w in self.waves do
		local fi = i - 1
		local age = frac(t / ShieldPreview.WAVE_CYCLE + fi / ShieldPreview.WAVES)
		local wp = 0.04 + 0.94 * age ^ 1.3 -- accelerating down
		local fade = math.min(1, age / 0.1) * (1 - math.max(0, (age - 0.78) / 0.22))
		local vis = shellOn and wp < front - 0.02
		for _, layer in { w.glow, w.line } do
			for _, b in layer.segs do
				b.Enabled = vis
			end
		end
		if vis then
			local thetasG, thetasL, phis, alphas = {}, {}, {}, {}
			local jr = Random.new(step * 53 + i * 7 + self.seed)
			for j = 0, J - 1 do
				local phi = j / J * 2 * PI + 0.2 * fi
				local wob = 0.03 * math.sin(3 * phi + 2.1 * fi + 1.3 * t) + 0.017 * math.sin(7 * phi - 2 * t + fi) -- the mock-up's, x 1.4
				local th = math.clamp((wp + wob) * PI / 2 + jr:NextNumber(-0.01, 0.01), 0.02, PI / 2 - 0.01)
				thetasL[j + 1] = th
				thetasG[j + 1] = math.max(0.02, th - 0.062) -- the glow band's centre sits above its leading line
				phis[j + 1] = phi
				local gap = if math.sin(phi * 6 + w.seed + fi * 3 + t * 0.5) > 0.7 then 0.12 else 1
				alphas[j + 1] = fade * gap * (0.45 + 0.55 * math.max(0, math.sin(phi * 4 + fi * 1.7 + t * 0.8)))
			end
			layRing(self, w.glow, R * 1.008, thetasG, phis)
			layRing(self, w.line, R * 1.01, thetasL, phis)
			local pick = (step + i) % 3 + 1
			for j, b in w.glow.segs do
				b.Transparency = NumberSequence.new(1 - 0.75 * alphas[j], 1 - 0.75 * alphas[(j % J) + 1])
				b.Texture = Images.wave_glow[pick]
			end
			for j, b in w.line.segs do
				b.Transparency = NumberSequence.new(1 - alphas[j], 1 - alphas[(j % J) + 1])
				b.Texture = Images.wave_line[((step + i + 1) % 3) + 1]
			end
		end
	end

	-- the bright broken arcs on the lower edge of a raise or collapse
	for i, e in self.edges do
		local on = edge > 0 and front > 0.03 and front < 1
		for _, b in e.segs do
			b.Enabled = on
		end
		if on then
			local n = e.joints
			local phiA = (i - 1) * 2.1 + t * 0.6
			local span = 1.4 + (i - 1) * 0.3
			local thetas, phis = {}, {}
			local jr = Random.new(step * 29 + i + self.seed)
			for j = 0, n do
				local phi = phiA + span * j / n
				phis[j + 1] = phi
				thetas[j + 1] = math.clamp(math.min(0.99, front) * PI / 2 + 0.028 * math.sin(phi * 7 + t * 4) + jr:NextNumber(-0.014, 0.014), 0.02, PI / 2 - 0.01)
			end
			layRing(self, e, R * 1.01, thetas, phis)
			for j, b in e.segs do
				local u0, u1 = (j - 1) / n, j / n
				local ends0 = math.min(1, u0 / 0.15, (1 - u0) / 0.15)
				local ends1 = math.min(1, u1 / 0.15, (1 - u1) / 0.15)
				local gap = if hash(j * 3.7 + i * 11 + step) > 0.85 then 0.2 else 1
				b.Transparency = NumberSequence.new(1 - edge * ends0 * gap, 1 - edge * ends1 * gap)
				b.Texture = Images.wave_line[((step + j) % 3) + 1]
			end
		end
	end

	-- hits: a patch of cells lit round the impact, a ring spreading out, fading (idle only)
	local hits = f.hits or {}
	for k, d in self.hits do
		local hit = hits[k]
		local h = d.Parent :: MeshPart
		if full and hit and hit.age >= 0 and hit.age < ShieldPreview.HIT_LIFE then
			local dir = hit.dir.Unit
			local right = dir:Cross(Vector3.zAxis)
			if right.Magnitude < 1e-3 then
				right = dir:Cross(Vector3.xAxis)
			end
			right = right.Unit
			h.CFrame = CFrame.fromMatrix(base + dir * CAP_CENTER * R, right, dir)
			d.Texture = Images.hit[math.clamp(math.floor(hit.age / ShieldPreview.HIT_LIFE * 8) + 1, 1, 8)]
			d.Transparency = 0
		else
			d.Transparency = 1
		end
	end
end

function ShieldPreview.destroy(self: any)
	self.model:Destroy()
end

return ShieldPreview

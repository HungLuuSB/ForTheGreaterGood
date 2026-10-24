--!strict
-- The shield's energy look v4 in the game (C-187): a port of models-C's
-- reference (assets/fx/shield/waves/ShieldPreview.luau; fx.md "Shield
-- energy"; approved by the user 2026-10-24). Render/ShieldFx owns the
-- shield and its one update loop; this draws one dome's look:
--   - the shell: the single ForceField Dome when up; during a raise or a
--     collapse the 20 bands, revealed from the apex down (or drained back up);
--   - no honeycomb over the dome: the user wants cells only where a shot
--     hits (C-189), so models-C's hexGrid isn't loaded;
--   - the channel: a straight core with packets scrolling up, a soft glow,
--     two zig-zag filaments re-jittered every jitter step, a flickering
--     spark at the emitter and a flare at the apex pulsing as packets arrive;
--   - 20 streaks lying on the dome down unevenly spaced meridians;
--   - 3 energy waves rolling down (rings of curved Beam segments: a glow
--     band and a crackling line, wobbling, with gaps, textures swapped every
--     jitter step), and 3 broken arcs on the front of a raise or collapse;
--   - hits: pooled caps with a Decal flipbook of cells lighting outward.
-- Every instance is made in new(); setFrame only moves, shows and fades
-- them (the reference's fixed pools). Jitter comes from
-- ShieldEnergyLook.hash, not Random, so nothing is allocated per frame.
-- Detail by distance (fx.md): "full"; "mid" drops the streaks, filaments,
-- edge crackle; "far" (strategic) keeps only the shell.

local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")

local ShieldEnergyLook = require("../Core/ShieldEnergyLook")
local Meshes = require("@shared/Defs/Meshes/Registry")

local ShieldEnergy = {}

local entry = (Meshes :: any).shieldEnergy
ShieldEnergy.entry = entry
local PI = math.pi
local WHITE = Color3.new(1, 1, 1)
local hash = ShieldEnergyLook.hash

export type Detail = "full" | "mid" | "far"
export type Hit = { dir: Vector3, age: number }

type Ring = { points: { [number]: Attachment }, segs: { Beam }, joints: number, closed: boolean }

export type Energy = {
	R: number,
	base: Vector3,
	seed: number,
	tint: Color3,
	folder: Folder,
	holder: BasePart,
	dome: BasePart,
	bands: { MeshPart },
	hits: { Decal },
	apex: Attachment,
	from: Attachment,
	glow: Beam,
	core: Beam,
	filaments: { { points: { [number]: Attachment }, segs: { Beam } } },
	flicker: BillboardGui,
	flickerImg: ImageLabel,
	flare: BillboardGui,
	flareImg: ImageLabel,
	streaks: { { phi: number, a0: Attachment, a1: Attachment, beam: Beam } },
	waves: { { glow: Ring, line: Ring, seed: number } },
	edges: { Ring },
	-- what was last set, so unchanged values aren't written again (C-187:
	-- writes of NumberSequences and attachment frames are most of the cost)
	lastStep: number,
	lastFrom: Vector3,
	lastSet: { [Instance]: number },
	lastStreak: number, -- the streaks' end angle last laid
	frame: number, -- frames drawn (mid detail lays the waves every other one)
	-- scratch (reused every frame)
	thetasG: { number },
	thetasL: { number },
	phis: { number },
	alphas: { number },
	pos: { [number]: Vector3 },
}

-- the meshes, made once from their IDs (CreateMeshPartAsync yields: call
-- ShieldEnergy.load in its own thread)
local templates: { bands: { MeshPart }?, cap: MeshPart? } = {}
local state = "idle"

local function bare(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function mesh(id: string): MeshPart?
	local ok, part = pcall(function()
		return (AssetService :: any):CreateMeshPartAsync((Content :: any).fromUri(id))
	end)
	if ok and part then
		bare(part)
		return part
	end
	return nil
end

-- Loads the meshes and preloads the images (fresh images draw blank until
-- loaded once). Yields; ShieldFx runs it in its template thread.
function ShieldEnergy.load()
	if entry == nil or state ~= "idle" then
		return
	end
	state = "loading"
	local bands: { MeshPart }? = {}
	for _, b in entry.bands do
		local p = mesh(b.mesh)
		if p == nil then
			bands = nil
			break
		end
		table.insert(bands :: { MeshPart }, p)
	end
	templates.bands = bands
	templates.cap = mesh(entry.hitCap.mesh)
	local tx = entry.textures
	local ids: { any } = { tx.pulse, tx.glow, tx.line, tx.spark, tx.flare, tx.streak, tx.field }
	for _, list in { tx.waveGlow, tx.waveLine, tx.hit } do
		for _, id in list do
			table.insert(ids, id)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(ids)
	end)
	state = "done"
end

-- Whether the look can be drawn: approved (or shown for review), loaded.
function ShieldEnergy.ready(): boolean
	return entry ~= nil and state == "done" and templates.bands ~= nil
end

-- The faction's tint (fx.md: Order cyan, Chaos amber).
function ShieldEnergy.tint(faction: string?): Color3
	local c = if entry then (if faction == "chaos" then entry.tints.chaos else entry.tints.order) else { 143, 232, 255 }
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- a point on the sphere of radius r round base: theta from the apex, phi round
local function onSphere(base: Vector3, r: number, theta: number, phi: number): Vector3
	return base + Vector3.new(math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi)) * r
end

-- an attachment frame on the dome: X along `along` (a Beam curves along X),
-- Y across it on the surface (with FaceCamera off a Beam's width runs along
-- Y, so the Beam lies on the dome)
local function surfaceFrame(pos: Vector3, normal: Vector3, along: Vector3): CFrame
	local x = (along - normal * along:Dot(normal)).Unit
	local y = normal:Cross(x).Unit
	return CFrame.fromMatrix(pos, x, y)
end
-- Attachments live on `holder`, an unrotated part at the dome's base, so
-- their CFrame is the world frame less the base: writing CFrame is cheaper
-- than WorldCFrame (C-187).

-- A dome's energy look in `folder` round `base` (the dome's base centre),
-- radius `R`, tinted, its channel from `from`. `holder` is a part at the
-- base the attachments live on; `dome` the ForceField hemisphere (made from
-- ShieldFx's Dome template).
function ShieldEnergy.new(folder: Folder, holder: BasePart, base: Vector3, R: number, tint: Color3, from: Attachment, dome: BasePart, seed: number): Energy
	local S = entry.sizes
	local C = entry.counts
	local tx = entry.textures
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
		b.Enabled = false
		b.Parent = holder
		return b
	end
	local function billboard(name: string, adornee: Attachment, texture: string): (BillboardGui, ImageLabel)
		local g = Instance.new("BillboardGui")
		g.Name = name
		g.Adornee = adornee
		g.LightInfluence = 0
		g.Brightness = 2
		g.Enabled = false
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = texture
		img.ImageColor3 = tint
		img.Parent = g
		g.Parent = folder
		return g, img
	end
	local function part(template: MeshPart, name: string, center: { number }, size: { number }): MeshPart
		local m = template:Clone()
		m.Name = name
		m.Size = Vector3.new(size[1] * R, size[2] * R, size[3] * R)
		m.CFrame = CFrame.new(base + Vector3.new(0, center[2] * R, 0))
		m.Transparency = 1
		m.Parent = folder
		return m
	end

	-- the shell: the single dome (up) and the bands (raise, collapse)
	dome.Material = Enum.Material.ForceField
	pcall(function()
		(dome :: any).TextureID = tx.field
	end)
	dome.Color = tint
	local bands: { MeshPart } = {}
	for k, t in templates.bands :: { MeshPart } do
		local b = entry.bands[k]
		local p = part(t, `Band{k}`, b.center, b.size)
		p.Material = Enum.Material.ForceField
		p.TextureID = tx.field
		p.Color = tint
		bands[k] = p
	end
	-- hits: a flipbook in a Decal on a fully transparent cap (fx.md: the cap's
	-- own TextureID ignores alpha in Neon and washes out in ForceField)
	local hits: { Decal } = {}
	if templates.cap then
		for k = 1, C.hits do
			local h = part(templates.cap, `Hit{k}`, entry.hitCap.center, entry.hitCap.size)
			local d = Instance.new("Decal")
			d.Face = Enum.NormalId.Top
			d.Texture = tx.hit[1]
			local glow = S.hitGlow or 3 -- sizes.hitGlow (C-188: 1.6, the user found 3 too much)
			d.Color3 = Color3.new(tint.R * glow, tint.G * glow, tint.B * glow)
			d.Transparency = 1
			d.Parent = h
			hits[k] = d
		end
	end

	-- the channel
	local apex = att("Apex")
	apex.WorldPosition = base + Vector3.new(0, R, 0)
	local length = (apex.WorldPosition - from.WorldPosition).Magnitude
	local glow = beam("ChannelGlow", from, apex, tx.glow, S.glowWidth * R, true)
	local core = beam("ChannelCore", from, apex, tx.pulse, S.coreWidthStuds, true)
	core.TextureLength = math.max(0.1, length / 3) -- three packets in flight
	core.TextureSpeed = 2 -- one packet reaches the apex every pulse period
	core.Brightness = 5
	core.ZOffset = 2
	local filaments = {}
	for f = 1, C.filaments do
		local pts: { [number]: Attachment } = {}
		for i = 0, C.filamentSegments do
			pts[i] = att(`Fil{f}_{i}`)
		end
		local segs: { Beam } = {}
		for i = 1, C.filamentSegments do
			local b = beam(`Fil{f}_{i}`, pts[i - 1], pts[i], tx.line, S.filamentWidthStuds, true)
			b.Brightness = 3
			b.Color = ColorSequence.new(tint:Lerp(WHITE, 0.7))
			segs[i] = b
		end
		filaments[f] = { points = pts, segs = segs }
	end
	local flicker, flickerImg = billboard("EmitterFlicker", from, tx.spark)
	local flare, flareImg = billboard("ApexFlare", apex, tx.flare)

	-- the streaks: down unevenly spaced meridians
	local streaks = {}
	for k = 1, C.streaks do
		local phi = (k - 1) / C.streaks * 2 * PI + (hash(seed * 31 + k) * 2 - 1) * 0.12
		local a0, a1 = att(`Streak{k}_0`), att(`Streak{k}_1`)
		local b = beam(`Streak{k}`, a0, a1, tx.streak, S.streakWidth * R, false)
		b.TextureLength = S.streakTile * R * (0.8 + 0.5 * hash(seed * 17 + k))
		b.TextureSpeed = 0.25 + 0.2 * hash(seed * 13 + k)
		b.Brightness = 2.5
		b.ZOffset = -1
		b.Segments = 16
		streaks[k] = { phi = phi, a0 = a0, a1 = a1, beam = b }
	end

	-- the waves and the raise/collapse edge arcs
	local function ring(name: string, joints: number, texture: string, width: number, closed: boolean): Ring
		local pts: { [number]: Attachment } = {}
		for j = 0, joints - 1 do
			pts[j] = att(`{name}_{j}`)
		end
		pts[joints] = if closed then pts[0] else att(`{name}_{joints}`)
		local segs: { Beam } = {}
		for j = 1, joints do
			local b = beam(`{name}_seg{j}`, pts[j - 1], pts[j], texture, width, false)
			b.Segments = 8
			segs[j] = b
		end
		return { points = pts, segs = segs, joints = joints, closed = closed }
	end
	local waves = {}
	for i = 1, C.waves do
		local g = ring(`Wave{i}Glow`, C.ringJoints, tx.waveGlow[1], S.waveGlowWidth * R, true)
		for _, b in g.segs do
			b.TextureLength = S.waveGlowTile * R
			b.Brightness = 1.6
		end
		local l = ring(`Wave{i}Line`, C.ringJoints, tx.waveLine[1], S.waveLineWidth * R, true)
		for _, b in l.segs do
			b.TextureLength = S.waveLineTile * R
			b.Brightness = 3
			b.ZOffset = 1
			b.Color = ColorSequence.new(tint:Lerp(WHITE, 0.5))
		end
		waves[i] = { glow = g, line = l, seed = hash(seed * 7 + i) * 100 }
	end
	local edges = {}
	for i = 1, C.edgeArcs do
		local e = ring(`Edge{i}`, C.edgeJoints, tx.waveLine[1], S.edgeWidth * R, false)
		for _, b in e.segs do
			b.TextureLength = S.waveLineTile * R
			b.Brightness = 4
			b.Color = ColorSequence.new(tint:Lerp(WHITE, 0.6))
		end
		edges[i] = e
	end

	return {
		R = R,
		base = base,
		seed = seed,
		tint = tint,
		folder = folder,
		holder = holder,
		dome = dome,
		bands = bands,
		hits = hits,
		apex = apex,
		from = from,
		glow = glow,
		core = core,
		filaments = filaments,
		flicker = flicker,
		flickerImg = flickerImg,
		flare = flare,
		flareImg = flareImg,
		streaks = streaks,
		waves = waves,
		edges = edges,
		lastStep = -1,
		lastFrom = Vector3.zero,
		lastSet = {},
		lastStreak = -1,
		frame = seed % 2, -- domes alternate
		thetasG = {},
		thetasL = {},
		phis = {},
		alphas = {},
		pos = {},
	}
end

-- The channel's start (a generator model streamed in or out).
function ShieldEnergy.setFrom(e: Energy, from: Attachment)
	e.from = from
	e.glow.Attachment0 = from
	e.core.Attachment0 = from
	e.flicker.Adornee = from
	e.core.TextureLength = math.max(0.1, (e.apex.WorldPosition - from.WorldPosition).Magnitude / 3)
end

-- lay a ring through joints (thetas[j], phis[j]) on the sphere of radius r,
-- curved as a circle between them
local function layRing(e: Energy, ring: Ring, r: number, thetas: { number }, phis: { number })
	local base = e.base
	local n = ring.joints
	local count = if ring.closed then n else n + 1
	local pos = e.pos
	for j = 0, count - 1 do
		pos[j] = onSphere(base, r, thetas[j + 1], phis[j + 1])
	end
	for j = 0, count - 1 do
		local prev = if j > 0 then pos[j - 1] elseif ring.closed then pos[count - 1] else pos[j]
		local nxt = if j < count - 1 then pos[j + 1] elseif ring.closed then pos[0] else pos[j]
		ring.points[j].CFrame = surfaceFrame(pos[j] - base, (pos[j] - base).Unit, nxt - prev)
	end
	for j, b in ring.segs do
		local j1 = if ring.closed then j % n else j
		local dphi = (phis[j1 + 1] - phis[j]) % (2 * PI)
		local ringR = r * math.sin((thetas[j] + thetas[j1 + 1]) / 2)
		local k = ShieldEnergyLook.handle(dphi, ringR)
		b.CurveSize0, b.CurveSize1 = k, k
	end
end

local function setRing(ring: Ring, on: boolean)
	for _, b in ring.segs do
		if b.Enabled ~= on then
			b.Enabled = on
		end
	end
end

-- A Beam's uniform transparency, written only when it changed by more
-- than a little.
local function fade(e: Energy, b: Beam, v: number)
	local last = e.lastSet[b]
	if last == nil or math.abs(last - v) > 0.01 then
		e.lastSet[b] = v
		b.Transparency = NumberSequence.new(v)
	end
end

-- Everything hidden (down and the beam out, or off screen).
function ShieldEnergy.hide(e: Energy)
	e.dome.Transparency = 1
	for _, b in e.bands do
		b.Transparency = 1
	end
	for _, d in e.hits do
		d.Transparency = 1
	end
	e.glow.Enabled, e.core.Enabled = false, false
	for _, fil in e.filaments do
		for _, b in fil.segs do
			b.Enabled = false
		end
	end
	e.flicker.Enabled, e.flare.Enabled = false, false
	for _, s in e.streaks do
		s.beam.Enabled = false
	end
	for _, w in e.waves do
		setRing(w.glow, false)
		setRing(w.line, false)
	end
	for _, r in e.edges do
		setRing(r, false)
	end
end

-- One frame: v4 state `st` `tState` seconds in, the shield's clock `t`, an
-- opacity factor `alpha` (the strength rule and its flicker, 0..1), the
-- detail level and the live hits (direction from the dome's centre, age).
function ShieldEnergy.setFrame(e: Energy, st: string, tState: number, t: number, alpha: number, detail: Detail, hits: { Hit })
	local R, base = e.R, e.base
	local S, C, T, tx = entry.sizes, entry.counts, entry.timing, entry.textures
	local beamOn, front, edge, flareBoost = ShieldEnergyLook.envelope(st, tState, T)
	local step = math.floor(t / T.jitterStep)
	local full = st == "idle"
	local near = detail == "full"
	local drawDetail = detail ~= "far"

	-- the shell
	e.dome.Transparency = if full then 1 - alpha else 1
	for k, b in e.bands do
		local reveal = if full then 0 else ShieldEnergyLook.bandReveal(front, k, C.bands)
		b.Transparency = 1 - reveal * alpha
	end

	-- the channel
	local from: Vector3 = e.from.WorldPosition
	local top: Vector3 = e.apex.WorldPosition
	local axis = top - from
	local show = drawDetail and beamOn > 0.01
	local glowOn = beamOn * math.max(0.4, alpha)
	e.core.Enabled, e.glow.Enabled = show, show
	if show then
		fade(e, e.core, 1 - glowOn)
		fade(e, e.glow, 1 - 0.55 * glowOn)
	end
	local filOn = show and near and axis.Magnitude > 0.5
	-- the zig-zags change only every jitter step (or when the emitter moves)
	local newStep = step ~= e.lastStep or (from - e.lastFrom).Magnitude > 0.05
	if filOn and newStep then
		local side = axis.Unit:Cross(Vector3.xAxis).Unit
		local side2 = axis.Unit:Cross(side).Unit
		local n = C.filamentSegments
		for fi, fil in e.filaments do
			local ang = hash(step * 131 + fi * 17 + e.seed) * 2 * PI
			for i = 0, n do
				local off = Vector3.zero
				if i > 0 and i < n then
					ang += 0.9 + 0.8 * hash(step * 131 + fi * 17 + e.seed + i * 3.1)
					off = (side * math.cos(ang) + side2 * math.sin(ang)) * (0.4 + 0.6 * hash(step * 71 + fi * 5 + i * 1.7 + e.seed)) * S.filamentReach * R
				end
				fil.points[i].Position = from + axis * (i / n) + off - base
			end
			for _, b in fil.segs do
				b.Enabled = true
				fade(e, b, 1 - 0.9 * glowOn)
			end
		end
	elseif not filOn then
		for _, fil in e.filaments do
			for _, b in fil.segs do
				if b.Enabled then
					b.Enabled = false
				end
			end
		end
	end
	local fs = (0.9 + 0.3 * hash(step * 7 + e.seed)) * 2.4
	e.flicker.Size = UDim2.fromScale(fs, fs)
	e.flicker.Enabled = show
	e.flickerImg.ImageTransparency = 1 - 0.9 * glowOn
	local arrive = ShieldEnergyLook.arrive(t, T.pulsePeriod)
	local unit = S.flare * R
	local size = (if st == "idle" or st == "raise" then 1 + 0.5 * arrive else 0.8) * unit + flareBoost * unit * 1.2
	size *= math.max(beamOn, if flareBoost > 0 then 1 else 0)
	e.flare.Size = UDim2.fromScale(size, size)
	e.flare.Enabled = drawDetail and size > 0.01
	e.flare.Brightness = (2.2 + 1.5 * arrive + flareBoost) * math.max(0.4, alpha)
	e.flareImg.Rotation = math.deg(t * 0.25)

	-- the streaks: down the formed part of the dome
	local streakTheta = math.min(1, front) * PI / 2 * 0.99
	local streaksOn = near and (st == "idle" or st == "raise" or st == "collapse") and streakTheta > 0.05
	-- (laid again only when their end moved: still while the dome is up)
	local relay = streaksOn and math.abs(streakTheta - e.lastStreak) > 1e-4
	if relay then
		e.lastStreak = streakTheta
	end
	for _, s in e.streaks do
		if s.beam.Enabled ~= streaksOn then
			s.beam.Enabled = streaksOn
		end
		if relay then
			local r = R * 1.006
			local apexPos = onSphere(Vector3.zero, r, 0, s.phi)
			local endPos = onSphere(Vector3.zero, r, streakTheta, s.phi)
			s.a0.CFrame = surfaceFrame(apexPos, Vector3.yAxis, Vector3.new(math.cos(s.phi), 0, math.sin(s.phi)))
			local tangent = Vector3.new(math.cos(streakTheta) * math.cos(s.phi), -math.sin(streakTheta), math.cos(streakTheta) * math.sin(s.phi))
			s.a1.CFrame = surfaceFrame(endPos, endPos.Unit, tangent)
			local k = ShieldEnergyLook.handle(streakTheta, r)
			s.beam.CurveSize0, s.beam.CurveSize1 = k, k
		end
		if streaksOn then
			local key = (if full then 1 else 0) + math.floor(alpha * 50) * 2
			if e.lastSet[s.beam] ~= key then
				e.lastSet[s.beam] = key
				local function tr(v: number): number
					return 1 - (1 - v) * alpha
				end
				s.beam.Transparency = if full
					then NumberSequence.new({ NumberSequenceKeypoint.new(0, tr(0.55)), NumberSequenceKeypoint.new(0.7, tr(0.7)), NumberSequenceKeypoint.new(1, 1) })
					else NumberSequence.new({ NumberSequenceKeypoint.new(0, tr(0.6)), NumberSequenceKeypoint.new(0.85, tr(0.3)), NumberSequenceKeypoint.new(1, tr(0.2)) })
			end
		end
	end

	-- the waves
	local shellOn = drawDetail and (st == "raise" or st == "idle" or st == "collapse")
	local J = C.ringJoints
	local thetasG, thetasL, phis, alphas = e.thetasG, e.thetasL, e.phis, e.alphas
	-- beyond full detail the rings move every other frame (half the cost; at
	-- that distance a frame's move is a pixel or two)
	e.frame += 1
	local lay = near or e.frame % 2 == 0
	for i, w in e.waves do
		local fi = i - 1
		local _, wp, waveFade = ShieldEnergyLook.wave(fi, C.waves, t, T.waveCycle)
		local vis = shellOn and wp < front - 0.02
		setRing(w.glow, vis)
		setRing(w.line, vis)
		if vis and (lay or newStep) then
			for j = 0, J - 1 do
				local phi = j / J * 2 * PI + 0.2 * fi
				local th = ShieldEnergyLook.waveTheta(wp, phi, fi, t, step * 53 + i * 7 + j * 1.31 + e.seed)
				thetasL[j + 1] = th
				thetasG[j + 1] = math.max(0.02, th - 0.062) -- the glow band's centre sits above its leading line
				phis[j + 1] = phi
				alphas[j + 1] = ShieldEnergyLook.waveAlpha(phi, fi, t, w.seed, waveFade) * alpha
			end
			layRing(e, w.glow, R * 1.008, thetasG, phis)
			layRing(e, w.line, R * 1.01, thetasL, phis)
		end
		-- their brightness round the ring and the texture swap: every jitter step
		if vis and (newStep or e.lastSet[w.line.segs[1]] == nil) then
			e.lastSet[w.line.segs[1]] = step
			local glowTex = tx.waveGlow[(step + i) % 3 + 1]
			local lineTex = tx.waveLine[(step + i + 1) % 3 + 1]
			for j, b in w.glow.segs do
				b.Transparency = NumberSequence.new(1 - 0.75 * alphas[j], 1 - 0.75 * alphas[(j % J) + 1])
				if b.Texture ~= glowTex then
					b.Texture = glowTex
				end
			end
			for j, b in w.line.segs do
				b.Transparency = NumberSequence.new(1 - alphas[j], 1 - alphas[(j % J) + 1])
				if b.Texture ~= lineTex then
					b.Texture = lineTex
				end
			end
		end
	end
	e.lastStep, e.lastFrom = step, from

	-- the broken arcs on the front of a raise or collapse
	for i, ring in e.edges do
		local on = near and edge > 0 and front > 0.03 and front < 1
		setRing(ring, on)
		if on then
			local n = ring.joints
			local phiA = (i - 1) * 2.1 + t * 0.6
			local span = 1.4 + (i - 1) * 0.3
			for j = 0, n do
				local phi = phiA + span * j / n
				phis[j + 1] = phi
				thetasL[j + 1] = math.clamp(math.min(0.99, front) * PI / 2 + 0.028 * math.sin(phi * 7 + t * 4) + (hash(step * 29 + i + j * 2.3 + e.seed) * 2 - 1) * 0.014, 0.02, PI / 2 - 0.01)
			end
			layRing(e, ring, R * 1.01, thetasL, phis)
			for j, b in ring.segs do
				local u0, u1 = (j - 1) / n, j / n
				local ends0 = math.min(1, u0 / 0.15, (1 - u0) / 0.15)
				local ends1 = math.min(1, u1 / 0.15, (1 - u1) / 0.15)
				local gap = if hash(j * 3.7 + i * 11 + step) > 0.85 then 0.2 else 1
				b.Transparency = NumberSequence.new(1 - edge * ends0 * gap * alpha, 1 - edge * ends1 * gap * alpha)
				b.Texture = tx.waveLine[((step + j) % 3) + 1]
			end
		end
	end

	-- hits: cells lit round the impact, a ring spreading out, fading (up only)
	local frames = #tx.hit
	for k, d in e.hits do
		local hit = hits[k]
		local h = d.Parent :: MeshPart
		if full and drawDetail and hit and hit.age >= 0 and hit.age < T.hitLife then
			local dir = hit.dir.Unit
			local right = dir:Cross(Vector3.zAxis)
			if right.Magnitude < 1e-3 then
				right = dir:Cross(Vector3.xAxis)
			end
			right = right.Unit
			h.CFrame = CFrame.fromMatrix(base + dir * entry.hitCap.center[2] * R, right, dir)
			d.Texture = tx.hit[math.clamp(math.floor(hit.age / T.hitLife * frames) + 1, 1, frames)]
			d.Transparency = 1 - alpha
		elseif d.Transparency ~= 1 then
			d.Transparency = 1
		end
	end
end

return ShieldEnergy

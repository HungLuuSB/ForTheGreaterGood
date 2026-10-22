--!strict
-- Shield dome prototype (C-87): draws Core/Shield.
--
-- The dome, in team colour:
--   - a tinted ball (the field),
--   - a rim of thin Neon segments on the sphere's silhouette as the camera
--     sees it, recomputed each frame (the bright edge where the eye looks
--     through the most field, like a fresnel edge; terrain and units in
--     front hide it, unlike a screen overlay),
--   - plasma sparkles drifting on its surface,
--   - faint hexagon flickers at random spots (the hex shell at rest).
-- The rim dims with the field's force and flickers below full force.
-- At the centre, the plasma core: green full, orange, red empty. Above it, a
-- capacity bar (screen space, above the dome's outline). At 0% the dome collapses (flash, shrink, gone) and the core
-- sputters; at 25% it rises again, growing from the core.
--
-- A hit lights a patch of hexagon plates round the hit point (Neon, white
-- hot to red, rippling outward), dents the
-- centre, throws sparks and a light. Fake shells brake in the field, turn
-- and are thrown back out; heavy ones on a weak dome break through.
--
-- Client-only and not wired to the sim: the server has no shield yet.
-- `ShieldFx.demo` runs a test dome with a stream of fake shells, started
-- from FtggClientDebug:Invoke("shield") in a Studio playtest.
--
-- Hexagons: one hexagon prism built with an EditableMesh and cloned per
-- plate where the experience allows the API (Game Settings, Security);
-- else three thin rectangles 60° apart (their union is a hexagon).

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local Shield = require("../Core/Shield")

local ShieldFx = {}

ShieldFx.TINT_TRANSPARENCY = 0.8
ShieldFx.RIM_SEGMENTS = 64
ShieldFx.RIM_WIDTH = 0.7 -- studs
ShieldFx.PLATE_THICKNESS = 0.12
ShieldFx.MAX_PLATES = 400 -- across every dome
ShieldFx.MAX_SHELLS = 40
ShieldFx.IDLE_EVERY = 0.12 -- seconds between idle hex flickers on a dome at rest
ShieldFx.COLLAPSE_SECONDS = 0.45
ShieldFx.RISE_SECONDS = 0.6

export type DomeView = {
	model: Shield.Dome,
	color: Color3,
	tint: Part,
	rim: { Part },
	glow: { Part }, -- a wider, fainter rim just inside the bright one
	sparkles: ParticleEmitter,
	core: Part,
	halo: Part,
	coreLight: PointLight,
	bar: Frame,
	barFill: Frame,
	barText: TextLabel,
	wasUp: boolean,
	changedAt: number, -- when it last collapsed or rose
	pulse: number, -- 0..1, a hit's flare on the rim
	nextIdle: number,
}

type PlateView = { parts: { BasePart } }

type ShellView = { shell: Shield.Shell, dome: DomeView, part: Part, born: number }

export type Fx = {
	folder: Folder,
	gui: ScreenGui?, -- the capacity bars (none without a local player)
	domes: { DomeView },
	plates: { PlateView },
	shells: { ShellView },
	freeShells: { Part },
	sparks: Attachment,
	emitter: ParticleEmitter,
	light: PointLight,
	lightUntil: number,
	now: number,
	rng: Random,
	hexTemplate: MeshPart?,
	stats: { hits: number, breaches: number, platesLit: number, mesh: string },
}

local WHITE = Color3.new(1, 1, 1)

local function toV3(p: Vector3): Shield.V3
	return { x = p.X, y = p.Y, z = p.Z }
end
local function fromV3(p: Shield.V3): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function bare(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

-- A hexagon prism, flats across X (the plate's `right`), points along Z.
local editableMeshOff = false
local function hexMesh(): MeshPart?
	if editableMeshOff then
		return nil
	end
	local ok, result = pcall(function()
		local em = (AssetService :: any):CreateEditableMesh()
		local h = 0.5
		local top, bottom = {}, {}
		for k = 0, 5 do
			local a = math.rad(30 + 60 * k)
			local x, z = math.cos(a), math.sin(a)
			top[k + 1] = em:AddVertex(Vector3.new(x, h, z))
			bottom[k + 1] = em:AddVertex(Vector3.new(x, -h, z))
		end
		local ct, cb = em:AddVertex(Vector3.new(0, h, 0)), em:AddVertex(Vector3.new(0, -h, 0))
		local function tri(a: number, b: number, c: number)
			-- both windings: seen from either side whatever the convention
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
	editableMeshOff = true -- the API is off here: don't ask (and warn) again
	return nil
end

local function newPlate(fx: Fx): PlateView
	local w = Shield.PLATE
	local parts: { BasePart } = {}
	if fx.hexTemplate then
		local p = fx.hexTemplate:Clone()
		p.Size = Vector3.new(w, ShieldFx.PLATE_THICKNESS, w * 2 / math.sqrt(3))
		p.Transparency = 1
		p.Parent = fx.folder
		parts[1] = p
	else
		-- three rectangles, edge × flats, at 0°, 60° and 120° (rotated in place by `step`)
		for _ = 1, 3 do
			local p = Instance.new("Part")
			bare(p)
			p.Material = Enum.Material.Neon
			p.Size = Vector3.new(w / math.sqrt(3), ShieldFx.PLATE_THICKNESS, w)
			p.Transparency = 1
			p.Parent = fx.folder
			table.insert(parts, p)
		end
	end
	return { parts = parts }
end

function ShieldFx.new(parent: Instance?): Fx
	local folder = Instance.new("Folder")
	folder.Name = "ShieldFx"
	folder.Parent = parent or workspace
	local sparksPart = Instance.new("Part")
	sparksPart.Name = "Sparks"
	bare(sparksPart)
	sparksPart.Transparency = 1
	sparksPart.Size = Vector3.one
	sparksPart.Parent = folder
	local att = Instance.new("Attachment")
	att.Parent = sparksPart
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	em.Enabled = false
	em.LightEmission = 1
	em.Color = ColorSequence.new(Color3.fromRGB(255, 230, 160), Color3.fromRGB(255, 90, 30))
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	em.Lifetime = NumberRange.new(0.25, 0.6)
	em.Speed = NumberRange.new(25, 55)
	em.SpreadAngle = Vector2.new(55, 55)
	em.Acceleration = Vector3.new(0, -60, 0)
	em.Drag = 3
	em.EmissionDirection = Enum.NormalId.Top
	em.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 24
	light.Brightness = 0
	light.Parent = att
	local gui: ScreenGui? = nil
	local player = game:GetService("Players").LocalPlayer
	if player then
		local g = Instance.new("ScreenGui")
		g.Name = "ShieldBars"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true -- placed in viewport pixels (WorldToViewportPoint)
		g.Parent = player:WaitForChild("PlayerGui")
		gui = g
	end
	local fx: Fx = {
		folder = folder,
		gui = gui,
		domes = {},
		plates = {},
		shells = {},
		freeShells = {},
		sparks = att,
		emitter = em,
		light = light,
		lightUntil = 0,
		now = 0,
		rng = Random.new(),
		hexTemplate = hexMesh(),
		stats = { hits = 0, breaches = 0, platesLit = 0, mesh = "" },
	}
	fx.stats.mesh = if fx.hexTemplate then "editable mesh" else "three rectangles"
	return fx
end

function ShieldFx.addDome(fx: Fx, center: Vector3, radius: number, color: Color3): DomeView
	local tint = Instance.new("Part")
	tint.Name = "DomeField"
	bare(tint)
	tint.Shape = Enum.PartType.Ball
	tint.Size = Vector3.one * (2 * radius)
	tint.Position = center
	tint.Color = color
	tint.Material = Enum.Material.SmoothPlastic
	tint.Transparency = ShieldFx.TINT_TRANSPARENCY
	tint.Parent = fx.folder
	local function ring(width: number, tone: Color3): { Part }
		local out = {}
		for _ = 1, ShieldFx.RIM_SEGMENTS do
			local p = Instance.new("Part")
			bare(p)
			p.Material = Enum.Material.Neon
			p.Color = tone
			p.Size = Vector3.new(width, width, 1)
			p.Parent = fx.folder
			table.insert(out, p)
		end
		return out
	end
	local rim = ring(ShieldFx.RIM_WIDTH, color:Lerp(WHITE, 0.15))
	local glow = ring(ShieldFx.RIM_WIDTH * 4, color)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Shape = Enum.ParticleEmitterShape.Sphere
	sparkles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparkles.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparkles.Rate = 45
	sparkles.Lifetime = NumberRange.new(0.5, 1.1)
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.LightEmission = 1
	sparkles.Color = ColorSequence.new(color:Lerp(WHITE, 0.5), color)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.1), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new(0.2)
	sparkles.Parent = tint
	-- the plasma core, on the dome's axis just above the ground
	local core = Instance.new("Part")
	core.Name = "PlasmaCore"
	bare(core)
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Size = Vector3.one * 5
	core.Position = center + Vector3.new(0, 4, 0)
	core.Parent = fx.folder
	local halo = Instance.new("Part") -- the plasma's soft glow round the core
	halo.Name = "CoreHalo"
	bare(halo)
	halo.Shape = Enum.PartType.Ball
	halo.Material = Enum.Material.Neon
	halo.Size = Vector3.one * 9
	halo.Position = core.Position
	halo.Transparency = 0.75
	halo.Parent = fx.folder
	local coreLight = Instance.new("PointLight")
	coreLight.Range = 14
	coreLight.Brightness = 2
	coreLight.Parent = core
	-- the capacity bar, placed above the dome's outline each frame
	local bar = Instance.new("Frame")
	bar.Name = "Capacity"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(130, 30)
	bar.Parent = fx.gui
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Position = UDim2.fromOffset(0, 18)
	back.Size = UDim2.new(1, 0, 0, 10)
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back
	local mark = Instance.new("Frame") -- the 25% a collapsed dome needs
	mark.BackgroundColor3 = WHITE
	mark.BorderSizePixel = 0
	mark.Position = UDim2.fromScale(Shield.RAISE_AT, 0)
	mark.Size = UDim2.new(0, 1, 1, 0)
	mark.Parent = back
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 13
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0.4
	text.Size = UDim2.new(1, 0, 0, 16)
	text.Parent = bar
	local d: DomeView = {
		model = Shield.newDome(toV3(center), radius),
		color = color,
		tint = tint,
		rim = rim,
		glow = glow,
		sparkles = sparkles,
		core = core,
		halo = halo,
		coreLight = coreLight,
		bar = bar,
		barFill = fill,
		barText = text,
		wasUp = true,
		changedAt = -math.huge,
		pulse = 0,
		nextIdle = 0,
	}
	table.insert(fx.domes, d)
	return d
end

-- A hit on dome `d` at `at` (projected onto it).
function ShieldFx.hit(fx: Fx, d: DomeView, at: Vector3, strength: number)
	local patch = Shield.hit(d.model, toV3(at), strength, fx.now)
	fx.stats.hits += 1
	local pos, n = fromV3(patch.hit), fromV3(Shield.unit(Shield.sub(patch.hit, d.model.center)))
	local right = if math.abs(n.Y) < 0.9 then Vector3.yAxis:Cross(n).Unit else Vector3.xAxis:Cross(n).Unit
	fx.sparks.WorldCFrame = CFrame.fromMatrix(pos, right, n)
	fx.emitter:Emit(math.floor(8 + 8 * math.min(strength, 3)))
	fx.light.Brightness = 2 + 2 * math.min(strength, 3)
	fx.lightUntil = fx.now + 0.25
	d.pulse = math.min(1, d.pulse + 0.25 * strength)
end

-- A fake shell of `mass` (1 = a typical shell; size follows it) from
-- `from` at `velocity`, against dome `d`.
function ShieldFx.fire(fx: Fx, d: DomeView, from: Vector3, velocity: Vector3, mass: number)
	if #fx.shells >= ShieldFx.MAX_SHELLS then
		return
	end
	local part = table.remove(fx.freeShells)
	if part == nil then
		local p = Instance.new("Part")
		p.Name = "Shell"
		bare(p)
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.Neon
		p.Parent = fx.folder
		part = p
	end
	local shellPart = part :: Part
	shellPart.Size = Vector3.one * (0.5 + 0.45 * mass)
	shellPart.Color = Color3.fromRGB(255, 190, 90)
	shellPart.Transparency = 0
	shellPart.Position = from
	table.insert(fx.shells, { shell = Shield.newShell(toV3(from), toV3(velocity), mass), dome = d, part = shellPart, born = fx.now })
end

local ROT60 = { CFrame.identity, CFrame.Angles(0, math.rad(60), 0), CFrame.Angles(0, math.rad(120), 0) }

-- The dome's field, core and bar for this frame.
local function drawDome(fx: Fx, d: DomeView, now: number, dt: number)
	local m = d.model
	if m.up ~= d.wasUp then
		d.wasUp = m.up
		d.changedAt = now
		if not m.up then
			-- the collapse: a burst of sparks from the core
			fx.sparks.WorldCFrame = d.core.CFrame
			fx.emitter:Emit(40)
		end
	end
	local since = now - d.changedAt
	local force = Shield.domeForce(m)
	local scale, show = 1, 1
	if not m.up then
		-- collapsing: flashes, shrinks to 85% and fades out
		local k = math.clamp(since / ShieldFx.COLLAPSE_SECONDS, 0, 1)
		scale, show = 1 - 0.15 * k, (1 - k) * (if math.floor(since * 30) % 2 == 0 then 1 else 0.4)
	elseif since < ShieldFx.RISE_SECONDS then
		-- rising: grows out of the core
		local k = since / ShieldFx.RISE_SECONDS
		scale, show = 0.1 + 0.9 * (1 - (1 - k) ^ 3), 1
	end
	d.pulse = math.max(0, d.pulse - dt * 3)
	-- below full force the rim flickers, faster the weaker it is
	local flicker = 1
	if m.up and force < 1 then
		flicker = 0.75 + 0.25 * math.sin(now * (14 + 30 * (1 - force)))
	end
	local size = Vector3.one * (2 * m.radius * scale)
	if d.tint.Size ~= size then
		d.tint.Size = size
	end
	local glow = show * (0.2 + 0.8 * force) * flicker
	d.tint.Transparency = 1 - (1 - ShieldFx.TINT_TRANSPARENCY) * math.min(1.4, glow + 0.5 * d.pulse)
	-- the rim: the sphere's silhouette from the camera, a circle on the plane
	-- facing it, R²/D towards the camera, of radius R·√(1 − R²/D²)
	local cam = workspace.CurrentCamera
	local center = fromV3(m.center)
	local R = m.radius * scale
	local toCam = cam.CFrame.Position - center
	local D = toCam.Magnitude
	local rimAlpha = math.clamp(0.95 * glow + 0.4 * d.pulse, 0, 1)
	-- the bar sits above the top of the outline
	local barAt = center + cam.CFrame.UpVector * m.radius * 1.1
	if D > R * 1.05 and rimAlpha > 0.01 then
		local parts: { BasePart } = {}
		local cframes: { CFrame } = {}
		local n = toCam / D
		local c = center + n * (R * R / D)
		local rr = R * math.sqrt(1 - (R * R) / (D * D))
		local u = (if math.abs(n.Y) < 0.95 then Vector3.yAxis:Cross(n) else Vector3.xAxis:Cross(n)).Unit
		local w = n:Cross(u)
		local up = cam.CFrame.UpVector - n * cam.CFrame.UpVector:Dot(n)
		if up.Magnitude > 1e-3 then
			barAt = c + up.Unit * (rr + 2)
		end
		local N = ShieldFx.RIM_SEGMENTS
		local seg = 2 * math.pi * rr / N * 1.05
		for i = 1, N do
			local a = (i - 0.5) / N * 2 * math.pi
			local radial = u * math.cos(a) + w * math.sin(a)
			local pos = c + radial * rr
			local tangent = -u * math.sin(a) + w * math.cos(a)
			local cf = CFrame.lookAt(pos, pos + tangent, n)
			local rp, gp = d.rim[i], d.glow[i]
			rp.Size = Vector3.new(ShieldFx.RIM_WIDTH, ShieldFx.RIM_WIDTH, seg)
			gp.Size = Vector3.new(ShieldFx.RIM_WIDTH * 4, ShieldFx.RIM_WIDTH * 0.5, seg)
			table.insert(parts, rp)
			table.insert(cframes, cf)
			-- the glow band sits just inside the bright line
			table.insert(parts, gp)
			table.insert(cframes, cf - radial * ShieldFx.RIM_WIDTH * 2)
			rp.Transparency = 1 - rimAlpha
			gp.Transparency = 1 - rimAlpha * 0.35
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	else
		for i = 1, ShieldFx.RIM_SEGMENTS do
			d.rim[i].Transparency = 1
			d.glow[i].Transparency = 1
		end
	end
	d.sparkles.Enabled = m.up and since > 0.2
	d.sparkles.Rate = 15 + 40 * force
	-- the core: its charge colour, sputtering while the dome is down
	local r, g, b = Shield.coreColor(m.charge)
	local coreColor = Color3.fromRGB(r, g, b)
	d.core.Color = coreColor
	d.halo.Color = coreColor
	d.coreLight.Color = coreColor
	local sputter = if m.up then 1 else (if math.floor(now * 12) % 3 == 0 then 0.25 else 0.8)
	d.core.Transparency = 1 - sputter
	d.halo.Transparency = 1 - 0.25 * sputter
	d.coreLight.Brightness = 3 * sputter * (0.5 + 0.5 * m.charge)
	d.core.Size = Vector3.one * (4.2 + 0.6 * math.sin(now * 5))
	-- the bar, above the dome's outline (its top as the camera sees it)
	local top, onScreen = cam:WorldToViewportPoint(barAt)
	d.bar.Visible = onScreen
	d.bar.Position = UDim2.fromOffset(top.X, top.Y)
	d.barFill.Size = UDim2.fromScale(m.charge, 1)
	d.barFill.BackgroundColor3 = coreColor
	local pct = math.floor(m.charge * 100 + 0.5)
	d.barText.Text = if m.up then `Shield {pct}%` else `Shield down · {pct}% / {math.floor(Shield.RAISE_AT * 100)}%`
	d.barText.TextColor3 = if m.up then WHITE else Color3.fromRGB(255, 120, 100)
	-- idle hex flickers while it's up
	if m.up and now >= d.nextIdle then
		local dir = Vector3.new(fx.rng:NextNumber(-1, 1), fx.rng:NextNumber(0.05, 1), fx.rng:NextNumber(-1, 1)).Unit
		Shield.idle(m, toV3(fromV3(m.center) + dir * m.radius), now)
		d.nextIdle = now + ShieldFx.IDLE_EVERY
	end
end

-- Advances to time `now` (seconds; any clock) by `dt`.
function ShieldFx.step(fx: Fx, now: number, dt: number)
	fx.now = now
	for _, d in fx.domes do
		Shield.recharge(d.model, dt)
	end
	-- shells
	for i = #fx.shells, 1, -1 do
		local s = fx.shells[i]
		local e = Shield.stepShell(s.shell, s.dome.model, dt)
		if e == "turn" then
			ShieldFx.hit(fx, s.dome, fromV3(assert(s.shell.hitAt)), s.shell.mass)
		elseif e == "breach" then
			ShieldFx.hit(fx, s.dome, fromV3(assert(s.shell.hitAt)), s.shell.mass * 1.5)
			fx.stats.breaches += 1
		end
		s.part.Position = fromV3(s.shell.pos)
		local st = s.shell.state
		if st == "braking" then
			-- the field heats it as it slows
			local k = 1 - Shield.len(s.shell.vel) / math.max(s.shell.entry, 1)
			s.part.Color = Color3.fromRGB(255, 190, 90):Lerp(WHITE, math.clamp(k, 0, 1))
		elseif st == "spent" then
			s.part.Transparency = math.min(1, s.part.Transparency + dt * 1.2)
		end
		if s.part.Transparency >= 1 or now - s.born > 6 or s.shell.pos.y < s.dome.model.center.y - 5 then
			s.part.Transparency = 1
			table.insert(fx.freeShells, s.part)
			table.remove(fx.shells, i)
		end
	end
	-- domes and plates
	local used = 0
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local function plate(p: Shield.Plate, dent: number, color: Color3, alpha: number)
		used += 1
		if used > ShieldFx.MAX_PLATES then
			return
		end
		local view = fx.plates[used]
		if view == nil then
			view = newPlate(fx)
			fx.plates[used] = view
		end
		local n = fromV3(p.normal)
		local cf = CFrame.fromMatrix(fromV3(p.pos) + n * (0.15 - dent), fromV3(p.right), n)
		for k, part in view.parts do
			table.insert(parts, part)
			table.insert(cframes, if #view.parts == 1 then cf else cf * ROT60[k])
			part.Color = color
			part.Transparency = 1 - alpha
		end
	end
	for _, d in fx.domes do
		drawDome(fx, d, now, dt)
		Shield.expire(d.model, now)
		local up = d.model.up
		for _, patch in d.model.patches do
			local age = now - patch.born
			for _, p in patch.plates do
				local heat, alpha, dent = Shield.plateAt(age, p.ring, patch.strength)
				if alpha > 0 then
					local r, g, b = Shield.color(heat)
					plate(p, dent, Color3.fromRGB(r, g, b), alpha * 0.95)
				end
			end
		end
		if up then
			for _, patch in d.model.idle do
				local age = now - patch.born
				for _, p in patch.plates do
					local a = Shield.idleAt(age, p.ring)
					if a > 0 then
						plate(p, 0, d.color:Lerp(WHITE, 0.2), a * 0.6)
					end
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i = used + 1, #fx.plates do
		for _, p in fx.plates[i].parts do
			if p.Transparency < 1 then
				p.Transparency = 1
			end
		end
	end
	fx.stats.platesLit = math.min(used, ShieldFx.MAX_PLATES)
	fx.light.Brightness = if now < fx.lightUntil then fx.light.Brightness * 0.85 else 0
end

function ShieldFx.destroy(fx: Fx)
	fx.folder:Destroy()
	if fx.gui then
		fx.gui:Destroy()
	end
end

-- A test dome at `center` with fake shells from all round for `seconds`:
-- light, typical and heavy shells, and quick bursts that merge. The fire is
-- heavier than the dome recharges, so it runs down, collapses at 0% (shells
-- go through), rises at 25% and runs down again. Returns a stop function.
function ShieldFx.demo(center: Vector3, radius: number, seconds: number?, color: Color3?): () -> ()
	local fx = ShieldFx.new()
	local d = ShieldFx.addDome(fx, center, radius, color or Color3.fromRGB(80, 150, 255))
	local rng = Random.new()
	local MASSES = { 0.5, 1, 1, 1, 2.5, 4 }
	local t0 = os.clock()
	local nextShot = 0
	local conn: RBXScriptConnection
	local function stop()
		conn:Disconnect()
		ShieldFx.destroy(fx)
	end
	conn = RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock() - t0
		if seconds and now > seconds then
			stop()
			return
		end
		if now >= nextShot then
			local burst = if rng:NextNumber() < 0.2 then 3 else 1
			local mass = MASSES[rng:NextInteger(1, #MASSES)]
			local a = rng:NextNumber() * math.pi * 2
			local aim = center + Vector3.new(math.cos(a + 0.3), 0.3 + rng:NextNumber() * 0.6, math.sin(a + 0.3)).Unit * radius
			local from = center + Vector3.new(math.cos(a) * (radius + 200), radius * 0.6 + rng:NextNumber() * 40, math.sin(a) * (radius + 200))
			for k = 1, burst do
				local jitter = Vector3.new(rng:NextNumber() - 0.5, rng:NextNumber() - 0.5, rng:NextNumber() - 0.5) * 3
				ShieldFx.fire(fx, d, from + jitter * k, (aim - from).Unit * 260, mass)
			end
			nextShot = now + 0.2 + rng:NextNumber() * 0.3
		end
		ShieldFx.step(fx, now, dt)
	end)
	return stop
end

return ShieldFx

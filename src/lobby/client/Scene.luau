--!strict
-- The menu's background (L-12): a small battle drawn with the game's own
-- unit models (the client's MeshModels, used read-only, from the mesh
-- manifest) under evening light. Order tanks and a Seraph SAM hold the
-- west, Chaos tanks and a Hydra MLRS the east; Harpies make passes and the
-- SAM shoots at them. Nothing is simulated: turrets turn to a target, guns
-- fire shells that burst near it, rockets arc, missiles chase. The camera
-- eases toward the mouse (parallax). Everything is local to this client,
-- far from the place's baseplate; a model that isn't ready after a while
-- gets a simple box stand-in.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local Scene = {}

local ORIGIN = Vector3.new(4000, 0, 0)
local ORDER = Color3.fromRGB(64, 132, 230)
local CHAOS = Color3.fromRGB(222, 70, 62)
local MODEL_WAIT = 20 -- seconds before a box stands in for a model
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

-- the cast: def, side, position (relative to ORIGIN), role
local CAST = {
	{ "ord_paladin", "order", Vector3.new(-38, 0, -6), "tank" },
	{ "ord_paladin", "order", Vector3.new(-46, 0, 16), "tank" },
	{ "ord_lancer", "order", Vector3.new(-32, 0, 32), "tank" },
	{ "ord_lancer", "order", Vector3.new(-50, 0, -26), "tank" },
	{ "ord_seraph", "order", Vector3.new(-64, 0, 4), "sam" },
	{ "chs_ravager", "chaos", Vector3.new(40, 0, -10), "tank" },
	{ "chs_ravager", "chaos", Vector3.new(46, 0, 13), "tank" },
	{ "chs_ravager", "chaos", Vector3.new(34, 0, 33), "tank" },
	{ "chs_minotaur", "chaos", Vector3.new(54, 0, -28), "tank" },
	{ "chs_hydra", "chaos", Vector3.new(64, 0, 2), "mlrs" },
}
local AIR = "chs_harpy"

local folder = Instance.new("Folder")
folder.Name = "LobbyScene"
local fx = Instance.new("Folder")
fx.Name = "Effects"
fx.Parent = folder

local enabled = true
local parallax = true
local covered = false -- something opaque covers the screen (key art): render and step nothing
local started = false

type Unit = {
	id: string,
	side: string,
	role: string,
	home: Vector3,
	facing: Vector3,
	model: Model?,
	rootOffset: CFrame,
	turret: Motor6D?,
	turretC0: CFrame,
	yaw: number,
	target: Unit?,
	nextFire: number,
	phase: number,
	pos: Vector3,
	cf: CFrame,
}
local units: { Unit } = {}

type Jet = { model: Model?, rootOffset: CFrame, pos: Vector3, vel: Vector3, alive: boolean, falling: boolean, respawnAt: number, cf: CFrame, smoke: ParticleEmitter? }
local jets: { Jet } = {}

local function rng(a: number, b: number): number
	return a + math.random() * (b - a)
end

-- lighting ------------------------------------------------------------------

local function light()
	Lighting.ClockTime = 17.7
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(70, 62, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 132, 120)
	Lighting.ExposureCompensation = 0.35
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.ShadowSoftness = 0.2
	local function effect(class: string, name: string, props: { [string]: any })
		local e = Lighting:FindFirstChild(name) or Instance.new(class)
		e.Name = name
		for k, v in props do
			(e :: any)[k] = v
		end
		e.Parent = Lighting
	end
	effect("Atmosphere", "LobbyAtmosphere", { Density = 0.3, Offset = 0.25, Color = Color3.fromRGB(222, 186, 150), Decay = Color3.fromRGB(150, 104, 84), Glare = 0.6, Haze = 1.4 })
	effect("BloomEffect", "LobbyBloom", { Intensity = 0.7, Size = 28, Threshold = 1.4 })
	effect("SunRaysEffect", "LobbySunRays", { Intensity = 0.05, Spread = 0.6 })
	effect("ColorCorrectionEffect", "LobbyGrade", { Contrast = 0.14, Saturation = -0.08, TintColor = Color3.fromRGB(255, 238, 222) })
	effect("DepthOfFieldEffect", "LobbyFocus", { FarIntensity = 0.25, FocusDistance = 70, InFocusRadius = 45, NearIntensity = 0 })
end

-- ground --------------------------------------------------------------------

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
	return p
end

local function ground()
	part({ Name = "Ground", Size = Vector3.new(1200, 4, 1200), CFrame = CFrame.new(ORIGIN - Vector3.new(0, 2, 0)), Material = Enum.Material.Ground, Color = Color3.fromRGB(92, 78, 60), Parent = folder })
	-- a lighter sandy band where the armies fight, and scattered rock
	part({ Name = "Field", Size = Vector3.new(220, 0.2, 120), CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.05, 0)), Material = Enum.Material.Sand, Color = Color3.fromRGB(128, 106, 78), Parent = folder })
	for _ = 1, 70 do
		local x, z = rng(-220, 220), rng(-160, 70)
		if math.abs(z) < 50 and math.abs(x) < 80 then
			continue -- keep the battle lane clear
		end
		local s = rng(2, 9)
		part({
			Name = "Rock",
			Size = Vector3.new(s * rng(0.8, 1.8), s * rng(0.4, 1), s * rng(0.8, 1.6)),
			CFrame = CFrame.new(ORIGIN + Vector3.new(x, s * 0.2, z)) * CFrame.Angles(rng(-0.3, 0.3), rng(0, 6.28), rng(-0.3, 0.3)),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(math.floor(rng(84, 110)), math.floor(rng(74, 92)), math.floor(rng(64, 78))),
			Parent = folder,
		})
	end
	-- a ridge behind the Chaos side and one far behind everything
	for i = 1, 9 do
		part({
			Name = "Ridge",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1, 1, 1) * rng(60, 110),
			CFrame = CFrame.new(ORIGIN + Vector3.new(-260 + i * 60 + rng(-20, 20), -30, -210 + rng(-20, 20))),
			Material = Enum.Material.Rock,
			Color = Color3.fromRGB(96, 80, 66),
			Parent = folder,
		})
	end
end

-- models --------------------------------------------------------------------

local MeshModels: any = nil
pcall(function()
	MeshModels = require("@client/Render/MeshModels")
end)

-- A box tank, when the mesh model isn't there.
local function boxModel(color: Color3, air: boolean): Model
	local m = Instance.new("Model")
	local base = part({ Name = "base", Size = if air then Vector3.new(6, 1.2, 8) else Vector3.new(6, 2, 9), Color = Color3.fromRGB(70, 72, 66), Material = Enum.Material.Metal, Parent = m })
	base.CFrame = CFrame.new(0, if air then 0 else 1.4, 0)
	local turret = part({ Name = "turret", Size = Vector3.new(3.6, 1.4, 4), Color = color, Material = Enum.Material.Metal, Anchored = false, Parent = m })
	turret.CFrame = CFrame.new(0, if air then 0.8 else 3.1, 0.4)
	local barrel = part({ Name = "barrel", Size = Vector3.new(0.5, 0.5, 5), Color = Color3.fromRGB(50, 50, 48), Material = Enum.Material.Metal, Anchored = false, Parent = m })
	barrel.CFrame = turret.CFrame * CFrame.new(0, 0.2, -3.6)
	local j = Instance.new("Motor6D")
	j.Name = "turret"
	j.Part0 = base
	j.Part1 = turret
	j.C0 = base.CFrame:Inverse() * turret.CFrame
	j.Parent = turret
	local w = Instance.new("WeldConstraint")
	w.Part0 = turret
	w.Part1 = barrel
	w.Parent = barrel
	local a = Instance.new("Attachment")
	a.Name = "muzzle"
	a.Position = Vector3.new(0, 0, -2.5)
	a.Parent = barrel
	m.PrimaryPart = base
	m:SetAttribute("RootOffset", base.CFrame)
	return m
end

local function paint(m: Model, color: Color3)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and CollectionService:HasTag(d, "TeamColor") then
			d.Color = color
		end
	end
end

-- A copy of def `id`'s model (waits up to MODEL_WAIT for the mesh one).
local function modelFor(id: string, color: Color3, air: boolean): (Model, CFrame)
	local deadline = os.clock() + MODEL_WAIT
	while MeshModels and os.clock() < deadline do
		local m = MeshModels.get(id)
		if m then
			local copy = m:Clone()
			paint(copy, color)
			return copy, copy:GetAttribute("RootOffset") or CFrame.new()
		end
		if not MeshModels.pending(id) then
			break
		end
		task.wait(0.25)
	end
	local box = boxModel(color, air)
	return box, box:GetAttribute("RootOffset")
end

local function muzzleOf(u: Unit): Vector3
	local m = u.model
	local a = m and m:FindFirstChild("muzzle", true)
	if a and a:IsA("Attachment") then
		return a.WorldPosition
	end
	return u.pos + Vector3.new(0, 3, 0) + u.facing * 5
end

-- effects -------------------------------------------------------------------

local liveFx = 0
local MAX_FX = 220

local function fxPart(props: { [string]: any }): Part?
	if liveFx >= MAX_FX then
		return nil
	end
	liveFx += 1
	local p = part(props)
	p.CastShadow = false
	p.Parent = fx
	p.Destroying:Connect(function()
		liveFx -= 1
	end)
	return p
end

local function tween(duration: number, step: (number) -> ()): ()
	local t0 = os.clock()
	while true do
		local k = math.min(1, (os.clock() - t0) / duration)
		step(k)
		if k >= 1 then
			return
		end
		RunService.RenderStepped:Wait()
	end
end

local function flash(at: Vector3, size: number, color: Color3, range: number, life: number)
	local p = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = CFrame.new(at), Material = Enum.Material.Neon, Color = color })
	if p == nil then
		return
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 5
	l.Shadows = false
	l.Parent = p
	task.spawn(function()
		tween(life, function(k)
			p.Transparency = k
			l.Brightness = 5 * (1 - k)
		end)
		p:Destroy()
	end)
end

local emitterHolder: Part? = nil
local smokeEmitter: ParticleEmitter? = nil
local fireEmitter: ParticleEmitter? = nil

local function emitters()
	if emitterHolder then
		return
	end
	local h = part({ Name = "Emitters", Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(ORIGIN), Parent = folder })
	local att = Instance.new("Attachment")
	att.Parent = h
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Enabled = false
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 64, 60), Color3.fromRGB(140, 128, 116))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 11) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(1.8, 3.2)
	smoke.Speed = NumberRange.new(3, 8)
	smoke.SpreadAngle = Vector2.new(60, 60)
	smoke.Acceleration = Vector3.new(0, 3, 0)
	smoke.Drag = 1.5
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.LightInfluence = 1
	smoke.Parent = att
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = FIRE
	fire.Enabled = false
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 200, 120), Color3.fromRGB(255, 90, 30))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 1) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.3, 0.6)
	fire.Speed = NumberRange.new(6, 16)
	fire.SpreadAngle = Vector2.new(180, 180)
	fire.LightEmission = 1
	fire.Parent = att
	emitterHolder, smokeEmitter, fireEmitter = h, smoke, fire
end

local function burst(at: Vector3, big: boolean)
	flash(at + Vector3.new(0, 1, 0), if big then 7 else 4, Color3.fromRGB(255, 170, 80), if big then 40 else 24, if big then 0.45 else 0.3)
	emitters()
	local h = emitterHolder :: Part
	h.CFrame = CFrame.new(at)
	;(fireEmitter :: ParticleEmitter):Emit(if big then 26 else 12)
	;(smokeEmitter :: ParticleEmitter):Emit(if big then 14 else 6)
end

-- A projectile along `path(k)` (k 0..1) over `duration`; `smoke` leaves a trail.
local function fly(path: (number) -> Vector3, duration: number, color: Color3, size: Vector3, smoke: boolean, onHit: () -> ())
	local p = fxPart({ Size = size, Material = Enum.Material.Neon, Color = color, CFrame = CFrame.new(path(0)) })
	if p == nil then
		onHit()
		return
	end
	local emitter: ParticleEmitter? = nil
	if smoke then
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(190, 186, 180))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Rate = 60
		e.Speed = NumberRange.new(0.5, 1)
		e.LightInfluence = 1
		e.Parent = p
		emitter = e
	end
	task.spawn(function()
		local last = path(0)
		tween(duration, function(k)
			local now = path(k)
			if (now - last).Magnitude > 1e-3 then
				p.CFrame = CFrame.lookAt(now, now + (now - last))
			end
			last = now
		end)
		onHit()
		if emitter then
			emitter.Enabled = false
			p.Transparency = 1
			task.wait(1.5)
		end
		p:Destroy()
	end)
end

-- behavior ------------------------------------------------------------------

local function enemiesOf(u: Unit): { Unit }
	local out = {}
	for _, o in units do
		if o.side ~= u.side and o.model then
			table.insert(out, o)
		end
	end
	return out
end

local function fire(u: Unit, now: number)
	if u.role == "sam" then
		-- the SAM shoots at the nearest live jet in range
		local best: Jet? = nil
		for _, j in jets do
			if j.alive and (j.pos - u.pos).Magnitude < 260 then
				best = j
			end
		end
		u.nextFire = now + rng(2.5, 4)
		local jet = best
		if jet == nil then
			return
		end
		local from = muzzleOf(u)
		flash(from, 2, Color3.fromRGB(255, 230, 190), 18, 0.15)
		local t0 = jet.pos
		fly(function(k)
			-- climbs, then closes on the jet (re-read each frame)
			local to = jet.pos
			local mid = from:Lerp(to, 0.5) + Vector3.new(0, 30, 0)
			return from:Lerp(mid, k):Lerp(mid:Lerp(to, k), k)
		end, 1.4, Color3.fromRGB(255, 240, 220), Vector3.new(0.5, 0.5, 2.4), true, function()
			if jet.alive and (jet.pos - t0).Magnitude < 400 then
				burst(jet.pos, true)
				if math.random() < 0.6 then
					jet.alive = false
					jet.falling = true
				end
			end
		end)
		return
	end
	local targets = enemiesOf(u)
	if #targets == 0 then
		return
	end
	if u.target == nil or math.random() < 0.3 then
		u.target = targets[math.random(1, #targets)]
	end
	local t = u.target :: Unit
	if u.role == "mlrs" then
		u.nextFire = now + rng(7, 10)
		local from = muzzleOf(u)
		for i = 1, 6 do
			task.delay(i * 0.12, function()
				local to = t.pos + Vector3.new(rng(-14, 14), 0, rng(-14, 14))
				flash(from, 1.6, Color3.fromRGB(255, 200, 140), 16, 0.12)
				local apex = from:Lerp(to, 0.5) + Vector3.new(0, 45, 0)
				fly(function(k)
					return from:Lerp(apex, k):Lerp(apex:Lerp(to, k), k)
				end, 1.6, Color3.fromRGB(255, 210, 160), Vector3.new(0.35, 0.35, 1.6), true, function()
					burst(to, false)
				end)
			end)
		end
		return
	end
	u.nextFire = now + rng(2.2, 4.5)
	local from = muzzleOf(u)
	local to = t.pos + Vector3.new(rng(-6, 6), rng(0.5, 2), rng(-6, 6))
	flash(from, 1.8, Color3.fromRGB(255, 210, 140), 20, 0.1)
	local dist = (to - from).Magnitude
	fly(function(k)
		return from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * dist * 0.03, 0)
	end, dist / 260, Color3.fromRGB(255, 236, 180), Vector3.new(0.35, 0.35, 2.6), false, function()
		burst(to, math.random() < 0.15)
	end)
end

local function stepUnits(now: number, dt: number)
	for _, u in units do
		local m = u.model
		if m == nil then
			continue
		end
		-- creep forward and back along the lane, as if holding a line
		local sway = math.sin(now * 0.35 + u.phase) * 3
		u.pos = u.home + u.facing * sway
		u.cf = CFrame.lookAt(u.pos, u.pos + u.facing)
		m:PivotTo(u.cf * u.rootOffset)
		-- the turret turns to its target
		if u.turret then
			local aim: Vector3? = nil
			if u.role == "sam" then
				for _, j in jets do
					if j.alive then
						aim = j.pos
					end
				end
			elseif u.target then
				aim = u.target.pos
			end
			if aim then
				local d = u.cf:VectorToObjectSpace(aim - u.pos)
				local want = math.atan2(-d.X, -d.Z)
				local delta = (want - u.yaw + math.pi) % (2 * math.pi) - math.pi
				u.yaw += math.clamp(delta, -dt * 1.2, dt * 1.2)
				u.turret.C0 = u.turretC0 * CFrame.Angles(0, u.yaw, 0)
			end
		end
		if now >= u.nextFire then
			fire(u, now)
		end
	end
end

local function resetJet(j: Jet)
	j.alive = true
	j.falling = false
	j.pos = ORIGIN + Vector3.new(rng(240, 300), rng(30, 40), rng(-50, 40))
	j.vel = Vector3.new(-rng(50, 65), 0, rng(-6, 6))
	j.respawnAt = 0
	if j.model then
		j.model.Parent = folder
	end
	if j.smoke then
		j.smoke.Enabled = false
	end
end

local function stepJets(now: number, dt: number)
	for _, j in jets do
		local m = j.model
		if m == nil then
			continue
		end
		if j.respawnAt > 0 then
			if now >= j.respawnAt then
				resetJet(j)
			end
			continue
		end
		if j.falling then
			j.vel += Vector3.new(0, -30 * dt, 0)
			if j.smoke == nil then
				local e = Instance.new("ParticleEmitter")
				e.Texture = SMOKE
				e.Color = ColorSequence.new(Color3.fromRGB(40, 38, 36))
				e.Size = NumberSequence.new(2, 6)
				e.Transparency = NumberSequence.new(0.3, 1)
				e.Lifetime = NumberRange.new(1.5, 2.5)
				e.Rate = 40
				e.Parent = m.PrimaryPart
				j.smoke = e
			end
			;(j.smoke :: ParticleEmitter).Enabled = true
		end
		j.pos += j.vel * dt
		local bank = if j.falling then math.sin(now * 6) * 0.8 else math.sin(now * 0.9) * 0.25
		j.cf = CFrame.lookAt(j.pos, j.pos + j.vel) * CFrame.Angles(0, 0, bank)
		m:PivotTo(j.cf * j.rootOffset)
		if j.falling and j.pos.Y <= ORIGIN.Y + 1 then
			burst(j.pos, true)
			m.Parent = nil
			j.respawnAt = now + rng(4, 8)
		elseif j.pos.X < ORIGIN.X - 320 then
			m.Parent = nil
			j.respawnAt = now + rng(1, 4)
		end
	end
end

-- camera --------------------------------------------------------------------

local camPos = ORIGIN + Vector3.new(-4, 19, 64)
local camLook = ORIGIN + Vector3.new(2, 4, -2)
local smoothX, smoothY = 0, 0

local function stepCamera(now: number, dt: number)
	local cam = workspace.CurrentCamera
	if cam == nil then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 50
	local mx, my = 0, 0
	if parallax then
		local vp = cam.ViewportSize
		local mouse = UserInputService:GetMouseLocation()
		mx = math.clamp(mouse.X / math.max(vp.X, 1) * 2 - 1, -1, 1)
		my = math.clamp(mouse.Y / math.max(vp.Y, 1) * 2 - 1, -1, 1)
	end
	local a = 1 - math.exp(-dt * 2.5)
	smoothX += (mx - smoothX) * a
	smoothY += (my - smoothY) * a
	local drift = Vector3.new(math.sin(now * 0.07) * 3, math.sin(now * 0.05) * 1, 0)
	if not enabled then
		cam.CFrame = CFrame.lookAt(ORIGIN + Vector3.new(0, 300, 0), ORIGIN + Vector3.new(0, 320, -100))
		return
	end
	local pos = camPos + drift + Vector3.new(smoothX * 5, -smoothY * 2.5, 0)
	local look = camLook + Vector3.new(smoothX * 2, -smoothY * 1, 0)
	cam.CFrame = CFrame.lookAt(pos, look)
end

-- start ---------------------------------------------------------------------

local function spawnUnits()
	local defs = nil
	if MeshModels then
		local ok, Defs = pcall(function()
			return require("@shared/Defs/Defs")
		end)
		if ok then
			local okLoad, all = pcall(Defs.load)
			if okLoad then
				local subset = { units = {} :: { [string]: any } }
				for _, c in CAST do
					subset.units[c[1]] = all.units[c[1]]
				end
				subset.units[AIR] = all.units[AIR]
				defs = subset
			end
		end
		if defs then
			MeshModels.start(defs)
		else
			MeshModels = nil
		end
	end
	for i, c in CAST do
		local side = c[2]
		local u: Unit = {
			id = c[1],
			side = side,
			role = c[4],
			home = ORIGIN + c[3],
			facing = if side == "order" then Vector3.new(1, 0, 0) else Vector3.new(-1, 0, 0),
			model = nil,
			rootOffset = CFrame.new(),
			turret = nil,
			turretC0 = CFrame.new(),
			yaw = 0,
			target = nil,
			nextFire = os.clock() + rng(1, 5),
			phase = i * 1.7,
			pos = ORIGIN + c[3],
			cf = CFrame.new(),
		}
		table.insert(units, u)
		task.spawn(function()
			local m, root = modelFor(u.id, if side == "order" then ORDER else CHAOS, false)
			u.rootOffset = root
			local j = m:FindFirstChild("turret", true)
			if j and j:IsA("Motor6D") then
				u.turret = j
				u.turretC0 = j.C0
			end
			m.Parent = folder
			u.model = m
		end)
	end
	for i = 1, 2 do
		local j: Jet = { model = nil, rootOffset = CFrame.new(), pos = ORIGIN, vel = Vector3.zero, alive = false, falling = false, respawnAt = os.clock() + i * 3, cf = CFrame.new(), smoke = nil }
		table.insert(jets, j)
		task.spawn(function()
			local m, root = modelFor(AIR, CHAOS, true)
			j.rootOffset = root
			j.model = m
		end)
	end
end

function Scene.start()
	if started then
		return
	end
	started = true
	light()
	ground()
	folder.Parent = workspace
	spawnUnits()
	RunService.RenderStepped:Connect(function(dt: number)
		if covered then
			return
		end
		local now = os.clock()
		stepCamera(now, dt)
		if enabled then
			stepUnits(now, dt)
			stepJets(now, dt)
		end
	end)
end

local EFFECTS = { "LobbyBloom", "LobbySunRays", "LobbyGrade", "LobbyFocus" }

local function apply()
	folder.Parent = if enabled and not covered then workspace else nil
	for _, name in EFFECTS do
		local e = Lighting:FindFirstChild(name)
		if e and e:IsA("PostEffect") then
			e.Enabled = not covered
		end
	end
end

function Scene.setEnabled(on: boolean)
	enabled = on
	apply()
end

-- While opaque key art covers the screen, the battle behind it costs frames
-- for nothing (it held a Studio playtest at 39 fps with 80 ms spikes, which
-- made the art's parallax stutter): take it out of the world, switch the
-- post effects off and stop stepping it until it's uncovered.
function Scene.setCovered(on: boolean)
	covered = on
	apply()
end

function Scene.setParallax(on: boolean)
	parallax = on
end

return Scene

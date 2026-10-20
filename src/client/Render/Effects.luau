--!strict
-- Draws Core/Effects (guide 15.3): projectiles as pooled neon parts moved
-- with one BulkMoveTo, tracers as thin fading parts, bursts as a growing,
-- fading flash plus a particle burst (ParticleEmitter:Emit on a shared
-- carrier, never Enabled). Pools never shrink; unused parts are unparented.
-- Looks are placeholders: listed under "Needs my review".

local Effects = require("../Core/Effects")

local RenderEffects = {}

local BURST_COLOR: { [string]: Color3 } = {
	impact = Color3.fromRGB(255, 170, 70),
	death = Color3.fromRGB(255, 110, 50),
	muzzle = Color3.fromRGB(255, 235, 170),
	decoy = Color3.fromRGB(190, 220, 255),
	lost = Color3.fromRGB(170, 170, 170),
}
local PROJ_COLOR: { [string]: Color3 } = {
	BALLISTIC = Color3.fromRGB(255, 205, 110),
	HOMING = Color3.fromRGB(245, 245, 255),
	TORPEDO = Color3.fromRGB(60, 80, 95),
	BOMB = Color3.fromRGB(90, 90, 90),
}

export type Renderer = {
	folder: Folder,
	proj: { BasePart },
	tracers: { BasePart },
	flashes: { BasePart },
	carrier: BasePart,
	emitter: ParticleEmitter,
	emitted: { [any]: boolean },
	parts: { BasePart },
	frames: { CFrame },
}

local function newPart(name: string, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	if shape then
		p.Shape = shape
	end
	return p
end

function RenderEffects.new(): Renderer
	local folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
	local carrier = newPart("BurstCarrier")
	carrier.Transparency = 1
	carrier.Size = Vector3.new(0.2, 0.2, 0.2)
	carrier.Parent = folder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.3, 0.7)
	emitter.Speed = NumberRange.new(5, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90), Color3.fromRGB(70, 65, 60))
	emitter.Parent = carrier
	return { folder = folder, proj = {}, tracers = {}, flashes = {}, carrier = carrier, emitter = emitter, emitted = setmetatable({}, { __mode = "k" }) :: any, parts = {}, frames = {} }
end

local function take(pool: { BasePart }, i: number, make: () -> BasePart, folder: Folder): BasePart
	local p = pool[i]
	if p == nil then
		p = make()
		pool[i] = p
	end
	if p.Parent ~= folder then
		p.Parent = folder
	end
	return p
end

local function park(pool: { BasePart }, from: number)
	for i = from, #pool do
		if pool[i].Parent ~= nil then
			pool[i].Parent = nil
		end
	end
end

function RenderEffects.step(r: Renderer, fx: Effects.Fx, renderTick: number, now: number)
	-- projectiles
	local parts, frames = r.parts, r.frames
	table.clear(parts)
	table.clear(frames)
	local visible = Effects.visible(fx, renderTick)
	for i, v in visible do
		local p = v[1] :: Effects.Proj
		local kind = p.weapon.type
		local part = take(r.proj, i, function()
			return newPart("Projectile")
		end, r.folder)
		local size = if kind == "HOMING" then Vector3.new(0.35, 0.35, 1.8)
			elseif kind == "BOMB" then Vector3.new(1, 1, 1.6)
			elseif kind == "TORPEDO" then Vector3.new(0.5, 0.5, 2.2)
			else Vector3.new(0.45, 0.45, 1.1)
		if part.Size ~= size then
			part.Size = size
		end
		local color = PROJ_COLOR[kind] or PROJ_COLOR.BALLISTIC
		if part.Color ~= color then
			part.Color = color
		end
		local pos = Vector3.new(v[2], v[3], v[4])
		local vel = Vector3.new(p.vx, p.vy, p.vz)
		table.insert(parts, part)
		table.insert(frames, if vel.Magnitude > 1e-3 then CFrame.lookAt(pos, pos + vel) else CFrame.new(pos))
	end
	park(r.proj, #visible + 1)
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- tracers
	for i, t in fx.tracers do
		local part = take(r.tracers, i, function()
			return newPart("Tracer")
		end, r.folder)
		local a, b = Vector3.new(t.x0, t.y0, t.z0), Vector3.new(t.x1, t.y1, t.z1)
		local len = (b - a).Magnitude
		part.Size = Vector3.new(0.18, 0.18, math.max(len, 0.1))
		part.CFrame = CFrame.lookAt((a + b) / 2, b)
		part.Color = if t.hit then Color3.fromRGB(255, 220, 140) else Color3.fromRGB(255, 245, 210)
		part.Transparency = math.clamp((now - t.born) / t.life, 0, 1) * 0.8 + 0.1
	end
	park(r.tracers, #fx.tracers + 1)

	-- bursts: a flash that grows and fades, plus particles once
	for i, b in fx.bursts do
		local part = take(r.flashes, i, function()
			return newPart("Flash", Enum.PartType.Ball)
		end, r.folder)
		local age = math.clamp((now - b.born) / b.life, 0, 1)
		local d = b.radius * 2 * (0.35 + 0.65 * age)
		part.Size = Vector3.new(d, d, d)
		part.CFrame = CFrame.new(b.x, b.y, b.z)
		part.Color = BURST_COLOR[b.kind] or BURST_COLOR.impact
		part.Transparency = 0.15 + 0.85 * age
		if not r.emitted[b] and b.kind ~= "muzzle" then
			r.emitted[b] = true
			r.carrier.CFrame = CFrame.new(b.x, b.y, b.z)
			r.emitter:Emit(math.clamp(math.floor(b.radius * 5), 4, 40))
		end
	end
	park(r.flashes, #fx.bursts + 1)
end

return RenderEffects

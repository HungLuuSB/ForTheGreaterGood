--!strict
-- Draws Core/Effects (guide 15.3): projectiles as pooled Neon shells with a
-- short Trail, moved with one BulkMoveTo; tracers as thin fading parts;
-- bursts as a growing, fading flash plus a particle burst
-- (ParticleEmitter:Emit on a shared carrier, never Enabled). Pools never
-- shrink; unused parts are unparented.
--
-- Sizes are for the RTS camera: at the default height one stud is about two
-- pixels, so shells are ~2.6 studs long with a trail, muzzle flashes at
-- least 4 studs and impacts at least 7 (C-18). Looks are placeholders the
-- user reviews in playtests.

local Effects = require("../Core/Effects")

local RenderEffects = {}

local BURST_COLOR: { [string]: Color3 } = {
	impact = Color3.fromRGB(255, 160, 60),
	death = Color3.fromRGB(255, 100, 40),
	muzzle = Color3.fromRGB(255, 240, 180),
	decoy = Color3.fromRGB(190, 220, 255),
	lost = Color3.fromRGB(170, 170, 170),
}
local PROJ_COLOR: { [string]: Color3 } = {
	BALLISTIC = Color3.fromRGB(255, 225, 120),
	HOMING = Color3.fromRGB(245, 245, 255),
	TORPEDO = Color3.fromRGB(150, 200, 230),
	BOMB = Color3.fromRGB(255, 190, 120),
}
local PROJ_SIZE: { [string]: Vector3 } = {
	BALLISTIC = Vector3.new(0.9, 0.9, 2.6),
	HOMING = Vector3.new(0.7, 0.7, 3.2),
	TORPEDO = Vector3.new(0.9, 0.9, 3.4),
	BOMB = Vector3.new(1.4, 1.4, 2.2),
}
-- burst diameter = max(MIN, radius × 2 × SCALE), growing from 35 % to 100 %
local BURST_MIN: { [string]: number } = { impact = 7, death = 12, muzzle = 4, decoy = 4, lost = 3 }
local BURST_SCALE: { [string]: number } = { impact = 1.6, death = 1.4, muzzle = 1, decoy = 1, lost = 1 }
local TRAIL_SECONDS = 0.06 -- ~20 studs behind a tank shell (340–380 studs/s)

type Shell = { part: BasePart, trail: Trail, owner: number?, fresh: boolean }

export type Renderer = {
	folder: Folder,
	shells: { Shell },
	slotOf: { [number]: number }, -- projectile ID → shell index (stable: trails don't jump)
	tracers: { BasePart },
	flashes: { BasePart },
	carrier: BasePart,
	emitter: ParticleEmitter,
	emitted: { [any]: boolean },
	parts: { BasePart },
	frames: { CFrame },
	stats: { maxProjectiles: number, maxFlashes: number, maxTracers: number, emits: number }, -- diagnostics
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

local function newShell(): Shell
	local part = newPart("Projectile")
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.35, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = TRAIL_SECONDS
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = part
	return { part = part, trail = trail, owner = nil, fresh = true }
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
	emitter.Lifetime = NumberRange.new(0.35, 0.8)
	emitter.Speed = NumberRange.new(8, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 4
	emitter.LightEmission = 0.7
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0.4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100), Color3.fromRGB(80, 70, 60))
	emitter.Parent = carrier
	return {
		folder = folder,
		shells = {},
		slotOf = {},
		tracers = {},
		flashes = {},
		carrier = carrier,
		emitter = emitter,
		emitted = setmetatable({}, { __mode = "k" }) :: any,
		parts = {},
		frames = {},
		stats = { maxProjectiles = 0, maxFlashes = 0, maxTracers = 0, emits = 0 },
	}
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

-- A shell for projectile `id`: the one it had, else a free one (its trail
-- cleared and held back a frame so it doesn't streak from its last use).
local function shellFor(r: Renderer, id: number, inUse: { [number]: boolean }): Shell
	local k = r.slotOf[id]
	if k and r.shells[k].owner == id then
		inUse[k] = true
		return r.shells[k]
	end
	for i, s in r.shells do
		if not inUse[i] then
			if s.owner and r.slotOf[s.owner] == i then
				r.slotOf[s.owner] = nil
			end
			inUse[i] = true
			s.owner, s.fresh = id, true
			r.slotOf[id] = i
			return s
		end
	end
	local s = newShell()
	table.insert(r.shells, s)
	inUse[#r.shells] = true
	s.owner = id
	r.slotOf[id] = #r.shells
	return s
end

function RenderEffects.step(r: Renderer, fx: Effects.Fx, renderTick: number, now: number)
	-- projectiles: keep each one's shell while it flies
	local parts, frames = r.parts, r.frames
	table.clear(parts)
	table.clear(frames)
	local visible = Effects.visible(fx, renderTick)
	local inUse: { [number]: boolean } = {}
	for _, v in visible do
		local p = v[1] :: Effects.Proj
		if r.slotOf[p.id] and r.shells[r.slotOf[p.id]].owner == p.id then
			inUse[r.slotOf[p.id]] = true -- reserve before handing out free shells
		end
	end
	for _, v in visible do
		local p = v[1] :: Effects.Proj
		local kind = p.weapon.type
		local shell = shellFor(r, p.id, inUse)
		local part = shell.part
		local size = PROJ_SIZE[kind] or PROJ_SIZE.BALLISTIC
		if part.Size ~= size then
			part.Size = size
		end
		local color = PROJ_COLOR[kind] or PROJ_COLOR.BALLISTIC
		if part.Color ~= color then
			part.Color = color
			shell.trail.Color = ColorSequence.new(color)
		end
		if part.Parent ~= r.folder then
			part.Parent = r.folder
		end
		local pos = Vector3.new(v[2], v[3], v[4])
		local vel = Vector3.new(p.vx, p.vy, p.vz)
		if shell.fresh then
			shell.trail.Enabled = false
			shell.trail:Clear()
			shell.fresh = false
		elseif not shell.trail.Enabled then
			shell.trail.Enabled = true
		end
		part:SetAttribute("TrailLength", vel.Magnitude * TRAIL_SECONDS) -- for the scene dump
		table.insert(parts, part)
		table.insert(frames, if vel.Magnitude > 1e-3 then CFrame.lookAt(pos, pos + vel) else CFrame.new(pos))
	end
	for i, s in r.shells do
		if not inUse[i] then
			if s.owner and r.slotOf[s.owner] == i then
				r.slotOf[s.owner] = nil
			end
			s.owner = nil
			if s.part.Parent ~= nil then
				s.part.Parent = nil
			end
		end
	end
	r.stats.maxProjectiles = math.max(r.stats.maxProjectiles, #visible)
	r.stats.maxFlashes = math.max(r.stats.maxFlashes, #fx.bursts)
	r.stats.maxTracers = math.max(r.stats.maxTracers, #fx.tracers)
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
		part.Size = Vector3.new(0.35, 0.35, math.max(len, 0.1))
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
		local full = math.max(BURST_MIN[b.kind] or 3, b.radius * 2 * (BURST_SCALE[b.kind] or 1))
		local d = full * (0.35 + 0.65 * age)
		part.Size = Vector3.new(d, d, d)
		part.CFrame = CFrame.new(b.x, b.y, b.z)
		part.Color = BURST_COLOR[b.kind] or BURST_COLOR.impact
		part.Transparency = 0.05 + 0.95 * age * age
		if not r.emitted[b] and b.kind ~= "muzzle" then
			r.emitted[b] = true
			r.carrier.CFrame = CFrame.new(b.x, b.y, b.z)
			r.emitter:Emit(math.clamp(math.floor(full * 2), 8, 50))
			r.stats.emits += 1
		end
	end
	park(r.flashes, #fx.bursts + 1)
end

return RenderEffects

--!strict
-- Plays deaths (guide 14.6, C-34) on the dying unit's own model, then
-- leaves its wreck. The model is UnitRenderer's: the shake moves its root,
-- flung pieces move through their Motor6D.Transform (no detaching, so the
-- pooled model is intact when it goes back). Wrecks are darkened, charred
-- copies of the unit's model with the turret knocked askew, slightly sunk
-- and tilted, pooled per def; they stay until the match restarts (the
-- wire doesn't say when a wreck is reclaimed: request 10), at most
-- MAX_WRECKS. Hidden at strategic zoom. Looks are placeholders.
-- Aircraft that die in the air fall out of the sky instead (C-48,
-- Core/Deaths.crash), burning and trailing smoke, and leave nothing: the
-- ground explosion comes from Effects when they hit.

local Deaths = require("../Core/Deaths")
local Models = require("./Models")
local Prng = require("@shared/Util/Prng")

local RenderDeaths = {}

RenderDeaths.MAX_WRECKS = 300
RenderDeaths.CHAR = Color3.fromRGB(38, 35, 32)
RenderDeaths.CHAR_AMOUNT = 0.75 -- how far wreck colors go to CHAR
RenderDeaths.SINK = 0.35 -- studs into the ground

type Playing = {
	id: number,
	def: any,
	model: Model,
	root: BasePart,
	base: CFrame, -- the root's frame at the death
	motors: { [string]: Motor6D },
	plan: Deaths.Plan,
	start: number,
	done: (() -> ())?, -- gives the model back
	crash: Deaths.Crash?,
	rootOffset: CFrame,
	fire: Attachment?, -- a falling aircraft's flames and smoke
}

export type Wreck = { id: number, defId: string, model: Model }

export type State = {
	playing: { Playing },
	wrecks: { Wreck }, -- oldest first
	free: { [string]: { Model } },
	folder: Folder,
	stats: { shakes: number, flings: number, wrecks: number, crashes: number },
}

function RenderDeaths.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "Wrecks"
	folder.Parent = workspace
	return { playing = {}, wrecks = {}, free = {}, folder = folder, stats = { shakes = 0, flings = 0, wrecks = 0, crashes = 0 } }
end

local function wreckModel(s: State, def: any, id: number): Model
	local list = s.free[def.id]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	local model = Models.template(def):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = d.Color:Lerp(RenderDeaths.CHAR, RenderDeaths.CHAR_AMOUNT)
			d.Material = Enum.Material.CorrodedMetal
			d.CastShadow = true
		elseif d:IsA("Motor6D") then
			-- knocked askew: turrets turned, barrels drooping
			local rng = Prng.new(id + #d.Name)
			d.Transform = CFrame.Angles(math.rad(rng:nextNumber(-25, -5)), math.rad(rng:nextNumber(-60, 60)), 0)
		end
	end
	return model
end

local function placeWreck(s: State, id: number, def: any, base: CFrame)
	local model = wreckModel(s, def, id)
	local rng = Prng.new(id)
	local tilt = CFrame.Angles(math.rad(rng:nextNumber(-4, 4)), 0, math.rad(rng:nextNumber(-4, 4)))
	local root = model.PrimaryPart :: BasePart
	model.Parent = s.folder
	root.CFrame = base * tilt - Vector3.new(0, RenderDeaths.SINK, 0)
	table.insert(s.wrecks, { id = id, defId = def.id, model = model })
	if #s.wrecks > RenderDeaths.MAX_WRECKS then
		local old = table.remove(s.wrecks, 1) :: Wreck
		old.model.Parent = nil
		local list = s.free[old.defId]
		if list == nil then
			list = {}
			s.free[old.defId] = list
		end
		table.insert(list, old.model)
	end
	s.stats.wrecks = #s.wrecks
end

-- Flames and a smoke trail on a falling aircraft (world-space particles).
local function burning(root: BasePart, big: number): Attachment
	local a = Instance.new("Attachment")
	a.Name = "CrashFire"
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Rate = 60
	fire.Lifetime = NumberRange.new(0.2, 0.4)
	fire.Speed = NumberRange.new(1, 3)
	fire.SpreadAngle = Vector2.new(30, 30)
	fire.LightEmission = 0.9
	fire.LightInfluence = 0
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * big), NumberSequenceKeypoint.new(1, 0.4 * big) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 90, 30))
	fire.Parent = a
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 50
	smoke.Lifetime = NumberRange.new(1.8, 2.6)
	smoke.Speed = NumberRange.new(0.5, 2)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 2, 0)
	smoke.Drag = 1
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-30, 30)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5 * big), NumberSequenceKeypoint.new(1, 6 * big) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(50, 48, 46), Color3.fromRGB(120, 118, 115))
	smoke.Parent = a
	a.Parent = root
	return a
end

-- Starts a death on a drawn model. `done` gives the model back when it ends.
-- `crash` (Core/Deaths.crash): an aircraft's fall instead, with the model's
-- `rootOffset` (its root's frame against the unit's position and heading).
function RenderDeaths.start(s: State, id: number, def: any, model: Model, motors: { [string]: Motor6D }, severity: number, wreckId: number, now: number, done: () -> (), crash: Deaths.Crash?, rootOffset: CFrame?)
	local plan = if crash
		then { kind = "crash", duration = crash.duration, wreck = false, pieces = {} } :: Deaths.Plan
		else Deaths.plan(id, def, severity, wreckId)
	local root = model.PrimaryPart :: BasePart
	local fire = if crash then burning(root, math.max(1, def.footprint or 1)) else nil
	table.insert(s.playing, { id = id, def = def, model = model, root = root, base = root.CFrame, motors = motors, plan = plan, start = now, done = done, crash = crash, rootOffset = rootOffset or CFrame.identity, fire = fire })
	if plan.kind == "shake" then
		s.stats.shakes += 1
	elseif plan.kind == "crash" then
		s.stats.crashes += 1
	else
		s.stats.flings += 1
	end
end

-- `now`: render-clock seconds; `speed`: the sim speed (a falling aircraft's
-- flames and smoke run at it, at most 1, like the other effects).
function RenderDeaths.step(s: State, now: number, speed: number?)
	local timeScale = math.clamp(speed or 1, 0, 1)
	for i = #s.playing, 1, -1 do
		local p = s.playing[i]
		local t = now - p.start
		if t >= p.plan.duration then
			if p.fire then
				p.fire:Destroy() -- its smoke stays in the air and fades
			end
			if p.plan.wreck then
				placeWreck(s, p.id, p.def, p.base) -- same model geometry: the wreck's root takes the dying root's place
			end
			table.remove(s.playing, i)
			if p.done then
				p.done()
			end
			continue
		end
		if p.plan.kind == "crash" then
			for _, e in (p.fire :: Attachment):GetChildren() do
				if e:IsA("ParticleEmitter") and e.TimeScale ~= timeScale then
					e.TimeScale = timeScale
				end
			end
			local x, y, z, heading, pitch, roll = Deaths.crashAt(p.crash :: Deaths.Crash, t)
			p.root.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, heading + math.pi, 0) * CFrame.Angles(pitch, 0, roll) * p.rootOffset
		elseif p.plan.kind == "shake" then
			local dx, dz = Deaths.shakeAt(p.id, t)
			p.root.CFrame = p.base + Vector3.new(dx, 0, dz)
		else
			-- the hull blows apart: it sinks out of sight under the burst, while
			-- pieces jointed to it fly free (their offsets make up for the sink)
			local sink = 6 * (t / p.plan.duration) ^ 2
			p.root.CFrame = p.base - Vector3.new(0, sink, 0)
			for _, piece in p.plan.pieces do
				local motor = p.motors[piece.name]
				if motor then
					local x, y, z, rx, ry, rz = Deaths.pieceAt(piece, t)
					if motor.Part0 == p.root then
						y += sink
					end
					motor.Transform = CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz)
				end
			end
		end
	end
end

-- Wrecks show only outside strategic zoom.
function RenderDeaths.setVisible(s: State, visible: boolean)
	s.folder.Parent = if visible then workspace else nil
end

-- A match restart: every wreck and death goes.
function RenderDeaths.clear(s: State)
	for _, p in s.playing do
		if p.fire then
			p.fire:Destroy()
		end
		if p.done then
			p.done()
		end
	end
	table.clear(s.playing)
	for _, w in s.wrecks do
		w.model:Destroy()
	end
	table.clear(s.wrecks)
	for _, list in s.free do
		for _, m in list do
			m:Destroy()
		end
	end
	table.clear(s.free)
	s.stats.wrecks = 0
end

return RenderDeaths

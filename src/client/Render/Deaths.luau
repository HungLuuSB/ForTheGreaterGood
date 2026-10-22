--!strict
-- Plays deaths (guide 14.6, C-34) on the dying unit's own model, then
-- leaves its wreck. The model is UnitRenderer's: the shake moves its root,
-- flung pieces move through their Motor6D.Transform (no detaching, so the
-- pooled model is intact when it goes back). Wrecks are darkened, charred
-- copies of the unit's model with the turret knocked askew, slightly sunk
-- and tilted, pooled per def. The team's wrecks come from WRECK / WRECK_GONE
-- (protocol 10, C-65, `syncWrecks`): one the client didn't see die (on
-- join, off camera) is placed from its record; a reclaimed one goes; a
-- death the client draws places its own at the end of the shake. At most
-- MAX_WRECKS. Hidden at strategic zoom. Looks are placeholders. Units with
-- an approved wreck mesh (models-C, C-115) leave that instead, with the same
-- knocked-askew joints and no charring (its maps are the damage).
-- Aircraft that die in the air fall out of the sky instead (C-48,
-- Core/Deaths.crash), burning and trailing smoke, and leave nothing: the
-- ground explosion comes from Effects when they hit.

local Deaths = require("../Core/Deaths")
local World = require("../Core/World")
local MeshModels = require("./MeshModels")
local Models = require("./Models")
local Prng = require("@shared/Util/Prng")

local RenderDeaths = {}

RenderDeaths.MAX_WRECKS = 300
RenderDeaths.CHAR = Color3.fromRGB(38, 35, 32)
RenderDeaths.CHAR_AMOUNT = 0.75 -- how far wreck colors go to CHAR
RenderDeaths.SINK = 0.35 -- studs into the ground
RenderDeaths.DEATH_WAIT = 30 -- ticks: a WRECK whose DEATH is this recent waits for the death to place it

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
	wreckId: number,
}

export type Wreck = { id: number, defId: string, model: Model, wreckId: number }

export type State = {
	playing: { Playing },
	wrecks: { Wreck }, -- oldest first
	byWreck: { [number]: Wreck }, -- by the server's wreck ID
	pending: { [number]: boolean }, -- WRECK records not placed yet
	reclaimed: { [number]: boolean }, -- WRECK_GONE before its death finished playing
	free: { [string]: { Model } },
	folder: Folder,
	stats: { shakes: number, flings: number, wrecks: number, crashes: number },
}

function RenderDeaths.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "Wrecks"
	folder.Parent = workspace
	return { playing = {}, wrecks = {}, byWreck = {}, pending = {}, reclaimed = {}, free = {}, folder = folder, stats = { shakes = 0, flings = 0, wrecks = 0, crashes = 0 } }
end

local function wreckModel(s: State, def: any, id: number): Model
	local list = s.free[def.id]
	if list and #list > 0 then
		return table.remove(list) :: Model
	end
	local meshed = MeshModels.wreck(def)
	local model = (meshed or Models.template(def)):Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not meshed then
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

local function pool(s: State, w: Wreck)
	w.model.Parent = nil
	local list = s.free[w.defId]
	if list == nil then
		list = {}
		s.free[w.defId] = list
	end
	table.insert(list, w.model)
	if s.byWreck[w.wreckId] == w then
		s.byWreck[w.wreckId] = nil
	end
end

local function placeWreck(s: State, id: number, def: any, base: CFrame, wreckId: number)
	if wreckId ~= 0 and (s.byWreck[wreckId] or s.reclaimed[wreckId]) then
		s.reclaimed[wreckId] = nil -- already there, or reclaimed while the death played
		return
	end
	local model = wreckModel(s, def, id)
	local rng = Prng.new(id)
	local tilt = CFrame.Angles(math.rad(rng:nextNumber(-4, 4)), 0, math.rad(rng:nextNumber(-4, 4)))
	local root = model.PrimaryPart :: BasePart
	model.Parent = s.folder
	root.CFrame = base * tilt - Vector3.new(0, RenderDeaths.SINK, 0)
	local w = { id = id, defId = def.id, model = model, wreckId = wreckId }
	table.insert(s.wrecks, w)
	if wreckId ~= 0 then
		s.byWreck[wreckId] = w
		s.pending[wreckId] = nil
	end
	if #s.wrecks > RenderDeaths.MAX_WRECKS then
		pool(s, table.remove(s.wrecks, 1) :: Wreck)
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
		then { kind = "crash", duration = crash.duration + Deaths.CRASH_LINGER, wreck = false, pieces = {} } :: Deaths.Plan
		else Deaths.plan(id, def, severity, wreckId)
	local root = model.PrimaryPart :: BasePart
	local fire = if crash then burning(root, math.max(1, def.footprint or 1)) else nil
	table.insert(s.playing, { id = id, def = def, model = model, root = root, base = root.CFrame, motors = motors, plan = plan, start = now, done = done, crash = crash, rootOffset = rootOffset or CFrame.identity, fire = fire, wreckId = wreckId })
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
				placeWreck(s, p.id, p.def, p.base, p.wreckId) -- same model geometry: the wreck's root takes the dying root's place
			end
			table.remove(s.playing, i)
			if p.done then
				p.done()
			end
			continue
		end
		if p.plan.kind == "crash" then
			-- after the hit (it sinks out of sight) the flames and smoke stop, and
			-- what they left fades in the air (C-52)
			local burning = t < (p.crash :: Deaths.Crash).duration
			for _, e in (p.fire :: Attachment):GetChildren() do
				if e:IsA("ParticleEmitter") then
					if e.TimeScale ~= timeScale then
						e.TimeScale = timeScale
					end
					if e.Enabled ~= burning then
						e.Enabled = burning
					end
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
-- Follows the team's wreck records (C-65), at render tick `t`: reclaimed
-- wrecks go; a known wreck nobody is placing appears from its record (a
-- recent DEATH of the client's gets DEATH_WAIT ticks to place it itself).
function RenderDeaths.syncWrecks(s: State, world: any, t: number)
	for _, wid in world.wreckGone do
		s.pending[wid] = nil
		local w = s.byWreck[wid]
		if w then
			local i = table.find(s.wrecks, w)
			if i then
				table.remove(s.wrecks, i)
			end
			pool(s, w)
		else
			for _, p in s.playing do
				if p.wreckId == wid then
					s.reclaimed[wid] = true
				end
			end
		end
	end
	table.clear(world.wreckGone)
	for _, wid in world.wreckAdded do
		s.pending[wid] = true
	end
	table.clear(world.wreckAdded)
	for wid in s.pending do
		local rec = world.wrecks[wid]
		if rec == nil or s.byWreck[wid] then
			s.pending[wid] = nil
			continue
		end
		local playing = false
		for _, p in s.playing do
			if p.wreckId == wid then
				playing = true
				break
			end
		end
		local died = world.deathWrecks[wid]
		if playing or (died and t < died + RenderDeaths.DEATH_WAIT) then
			continue
		end
		local def = world.defs.unitByIndex[rec.defIndex]
		if def then
			local offset = (Models.template(def):GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
			local y = World.groundY(world, rec.x, rec.z)
			placeWreck(s, wid, def, CFrame.new(rec.x, y, rec.z) * CFrame.Angles(0, rec.heading + math.pi, 0) * offset, wid)
		end
		s.pending[wid] = nil
	end
end

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
	table.clear(s.byWreck)
	table.clear(s.pending)
	table.clear(s.reclaimed)
	for _, list in s.free do
		for _, m in list do
			m:Destroy()
		end
	end
	table.clear(s.free)
	s.stats.wrecks = 0
end

return RenderDeaths

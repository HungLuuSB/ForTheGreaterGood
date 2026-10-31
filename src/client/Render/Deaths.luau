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
-- A wreck worn below 40% is a scrap heap (protocol 45, S-227; C-278): its
-- model gives way to a pile of scrap sized by the unit's footprint, with a
-- burst of sparks and dust (`onFx`); a blast that hits a wreck throws
-- sparks off it. The pile is models-C's heap mesh (Meshes.fx.scrap_heap,
-- variant = size 1..4) once approved and built, its ground patch tinted to
-- the terrain (C-281); else a stand-in of scattered charred bars, swapped
-- for C's when it's built.
-- Aircraft that die in the air fall out of the sky instead (C-48,
-- Core/Deaths.crash), burning and trailing smoke, and leave nothing: the
-- ground explosion comes from Effects when they hit.

local Deaths = require("../Core/Deaths")
local World = require("../Core/World")
local MeshModels = require("./MeshModels")
local RenderTerrain = require("./Terrain")
local Models = require("./Models")
local Features = require("@shared/Defs/Features")
local Prng = require("@shared/Util/Prng")

local CollectionService = game:GetService("CollectionService")

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

export type Wreck = { id: number, defId: string, model: Model, wreckId: number, heap: boolean? } -- defId "heap_<size>" for a scrap heap

export type State = {
	playing: { Playing },
	wrecks: { Wreck }, -- oldest first
	byWreck: { [number]: Wreck }, -- by the server's wreck ID
	pending: { [number]: boolean }, -- WRECK records not placed yet
	reclaimed: { [number]: boolean }, -- WRECK_GONE before its death finished playing
	free: { [string]: { Model } },
	features: { [number]: { model: Model, kind: number, real: boolean } }, -- map features by wreck ID (S-197): uncapped, apart from the wrecks
	toHeap: { [number]: boolean }, -- wrecks that became scrap heaps before their wreck was placed (S-227)
	featureVersion: number, -- MeshModels.fxVersion when the placeholders were last checked
	folder: Folder,
	stats: { shakes: number, flings: number, wrecks: number, crashes: number },
}

function RenderDeaths.new(): State
	local folder = Instance.new("Folder")
	folder.Name = "Wrecks"
	folder.Parent = workspace
	for i = 1, RenderDeaths.HEAP_SIZES do
		MeshModels.fxVariant("scrap_heap", i) -- start building C's heaps now: the first one is then rarely a stand-in
	end
	return { playing = {}, wrecks = {}, byWreck = {}, pending = {}, reclaimed = {}, free = {}, features = {}, toHeap = {}, featureVersion = -1, folder = folder, stats = { shakes = 0, flings = 0, wrecks = 0, crashes = 0 } }
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

-- Scrap heaps (S-227, C-278).
RenderDeaths.onFx = nil :: ((kind: string, x: number, y: number, z: number, scale: number) -> ())? -- Main plays it on the effects' Vfx
RenderDeaths.HEAP_SIZES = 4
local RUST = Color3.fromRGB(92, 58, 38)

-- A unit's heap size: 1, 2, 3 by footprint, 4 for anything bigger.
function RenderDeaths.heapSize(def: any?): number
	return math.clamp(if def then def.footprint or 1 else 1, 1, RenderDeaths.HEAP_SIZES)
end

-- The stand-in pile: charred bars and plates heaped in a low mound over a
-- disc of dark scrap, about the unit's footprint across (`seed`: the look).
local function standInHeap(size: number, seed: number): Model
	local m = Instance.new("Model")
	m.Name = `ScrapHeap{size}`
	local rng = Prng.new(seed * 7 + size)
	local r = size * 8 * 0.42 -- studs: most of its cells
	local h = 0.9 + size * 0.55 -- the mound's height in the middle
	local base = Instance.new("Part")
	base.Name = "base"
	base.Shape = Enum.PartType.Cylinder
	base.Anchored, base.CanCollide, base.CanTouch, base.CanQuery = true, false, false, false
	base.Size = Vector3.new(0.15, r * 2, r * 2)
	base.CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2)
	base.Color, base.Material = Color3.fromRGB(74, 64, 52), Enum.Material.Ground -- a scorched patch of spilled scrap and dirt
	base.PivotOffset = base.CFrame:ToObjectSpace(CFrame.identity) -- the model's pivot: upright on the ground, not the disc's turned frame
	base.Parent = m
	m.PrimaryPart = base
	for i = 1, 7 + size * 5 do
		local d = r * math.sqrt(rng:nextNumber(0, 1))
		local a = rng:nextNumber(0, math.pi * 2)
		local y = h * (1 - (d / r) ^ 2) * rng:nextNumber(0.4, 1)
		local plate = rng:nextNumber(0, 1) < 0.3
		local p = Instance.new("Part")
		p.Name = `scrap{i}`
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		local len = rng:nextNumber(1.2, 2.2 + size * 0.8)
		p.Size = if plate then Vector3.new(len * 0.7, 0.2, rng:nextNumber(0.8, 1.6)) else Vector3.new(rng:nextNumber(0.25, 0.5), rng:nextNumber(0.25, 0.5), len)
		p.CFrame = CFrame.new(math.cos(a) * d, y + 0.2, math.sin(a) * d)
			* CFrame.Angles(rng:nextNumber(-0.7, 0.7), rng:nextNumber(0, math.pi * 2), rng:nextNumber(-0.5, 0.5))
		p.Color = RenderDeaths.CHAR:Lerp(RUST, rng:nextNumber(0, 0.6))
		p.Material = Enum.Material.CorrodedMetal
		p.Parent = m
	end
	return m
end

-- C's heap of `size` once built, else the stand-in; the pool key says
-- which ("heap_<size>" for C's, "heapstand_<size>" for the stand-in).
local function heapModel(s: State, size: number, wid: number): (Model, string)
	local real = if MeshModels.fxVariants("scrap_heap") >= size then MeshModels.fxVariant("scrap_heap", size) else nil
	local key = if real then `heap_{size}` else `heapstand_{size}`
	local list = s.free[key]
	if list and #list > 0 then
		return table.remove(list) :: Model, key
	end
	return if real then real:Clone() else standInHeap(size, wid), key
end

-- A scrap heap for wreck `wid` where its wreck lay (`x`, `z`, its heading).
-- C's heap: its team-masked ground patch takes the terrain's color there,
-- as a deposit's does (C-281).
local function placeHeap(s: State, world: any, wid: number, def: any?, x: number, z: number, heading: number)
	local size = RenderDeaths.heapSize(def)
	local model, key = heapModel(s, size, wid)
	if key == `heap_{size}` and world.layers then
		local tint = RenderTerrain.tintAt(world.layers, x, z)
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and CollectionService:HasTag(p, MeshModels.TEAM_TAG) then
				p.Color = tint
			end
		end
	end
	model:PivotTo(CFrame.new(x, World.groundY(world, x, z), z) * CFrame.Angles(0, heading, 0))
	model.Parent = s.folder
	local w = { id = wid, defId = key, model = model, wreckId = wid, heap = true }
	table.insert(s.wrecks, w)
	s.byWreck[wid] = w
	s.pending[wid] = nil
	s.toHeap[wid] = nil
	if #s.wrecks > RenderDeaths.MAX_WRECKS then
		pool(s, table.remove(s.wrecks, 1) :: Wreck)
	end
	s.stats.wrecks = #s.wrecks
end

-- Wreck `w` (placed) gives way to a scrap heap, with a burst.
local function collapse(s: State, world: any, w: Wreck, rec: any)
	local i = table.find(s.wrecks, w)
	if i then
		table.remove(s.wrecks, i)
	end
	pool(s, w)
	local def = world.defs.unitByIndex[rec.defIndex]
	placeHeap(s, world, rec.id, def, rec.x, rec.z, rec.heading)
	local onFx = RenderDeaths.onFx
	if onFx then
		local size = RenderDeaths.heapSize(def)
		onFx("scrapCollapse", rec.x, World.groundY(world, rec.x, rec.z) + 1, rec.z, size)
	end
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
-- Map features (S-197): a tree or a rock where the server says, turned by
-- its heading; models-C's variant (Meshes.fx.feature_tree / feature_rock)
-- and a ±15% scale picked from the wreck ID, so every client draws the
-- same. Until the meshes are approved and built, a plain stand-in: a trunk
-- under a crown, a grey block filling its cell.
RenderDeaths.FEATURE_SCALE = 0.15
local TRUNK, CROWN, STONE = Color3.fromRGB(96, 72, 52), Color3.fromRGB(70, 104, 58), Color3.fromRGB(118, 114, 108)

local function plain(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function standIn(kind: number): Model
	local m = Instance.new("Model")
	if kind == Features.TREE then
		local base = plain("base", Vector3.new(0.9, 4, 0.9), CFrame.new(0, 2, 0), TRUNK, Enum.Material.Wood, Enum.PartType.Cylinder, m)
		base.CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		plain("crown", Vector3.new(5, 5, 5), CFrame.new(0, 5.5, 0), CROWN, Enum.Material.Grass, Enum.PartType.Ball, m)
		m.PrimaryPart = base
	else
		local base = plain("base", Vector3.new(6.8, 3, 6.8), CFrame.new(0, 0.9, 0), STONE, Enum.Material.Rock, nil, m)
		m.PrimaryPart = base
	end
	return m
end

-- The model for feature `wid` of `kind`: the mesh variant when built, else
-- the stand-in. `real`: it's the mesh.
local function featureModel(kind: number, wid: number): (Model, boolean)
	local k = Features.BY_ID[kind]
	local n = if k then MeshModels.fxVariants(k.model) else 0
	if n > 0 then
		local template = MeshModels.fxVariant(k.model, wid % n + 1)
		if template then
			return template:Clone(), true
		end
	end
	return standIn(kind), false
end

local function placeFeature(s: State, world: any, wid: number, rec: any)
	local model, real = featureModel(rec.feature, wid)
	local rng = Prng.new(wid)
	local scale = 1 + rng:nextNumber(-RenderDeaths.FEATURE_SCALE, RenderDeaths.FEATURE_SCALE)
	model:ScaleTo(scale)
	local y = World.groundY(world, rec.x, rec.z)
	model:PivotTo(CFrame.new(rec.x, y, rec.z) * CFrame.Angles(0, rec.heading, 0))
	model.Parent = s.folder
	s.features[wid] = { model = model, kind = rec.feature, real = real }
end

function RenderDeaths.syncWrecks(s: State, world: any, t: number)
	for _, wid in world.wreckGone do
		local f = s.features[wid]
		if f then
			f.model:Destroy() -- a map feature reclaimed (S-197)
			s.features[wid] = nil
		end
	end
	-- the meshes arrived: stand-ins become the real thing
	if MeshModels.fxVersion ~= s.featureVersion then
		s.featureVersion = MeshModels.fxVersion
		for wid, f in s.features do
			local rec = world.wrecks[wid]
			if not f.real and rec then
				local _, real = featureModel(f.kind, wid)
				if real then
					f.model:Destroy()
					placeFeature(s, world, wid, rec)
				end
			end
		end
		-- and stand-in scrap heaps become C's (C-281)
		for i = #s.wrecks, 1, -1 do
			local w = s.wrecks[i]
			local rec = world.wrecks[w.wreckId]
			if w.heap and rec and string.sub(w.defId, 1, 10) == "heapstand_" then
				local def = world.defs.unitByIndex[rec.defIndex]
				local size = RenderDeaths.heapSize(def)
				if MeshModels.fxVariants("scrap_heap") >= size and MeshModels.fxVariant("scrap_heap", size) then
					table.remove(s.wrecks, i)
					pool(s, w)
					placeHeap(s, world, rec.id, def, rec.x, rec.z, rec.heading)
				end
			end
		end
	end
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
		if rec == nil or s.byWreck[wid] or s.features[wid] then
			s.pending[wid] = nil
			continue
		end
		if rec.feature then
			placeFeature(s, world, wid, rec)
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
		if rec.heap then
			placeHeap(s, world, wid, def, rec.x, rec.z, rec.heading) -- first seen as a heap: no burst
		elseif def then
			local offset = (Models.template(def):GetAttribute("RootOffset") :: CFrame?) or CFrame.identity
			local y = World.groundY(world, rec.x, rec.z)
			placeWreck(s, wid, def, CFrame.new(rec.x, y, rec.z) * CFrame.Angles(0, rec.heading + math.pi, 0) * offset, wid)
		end
		s.pending[wid] = nil
	end
	-- worn to scrap heaps (S-227): a placed wreck gives way now; one whose
	-- death still plays gives way when it's placed
	for _, wid in world.wreckHeaped do
		s.toHeap[wid] = true
	end
	table.clear(world.wreckHeaped)
	for wid in s.toHeap do
		local rec = world.wrecks[wid]
		local w = s.byWreck[wid]
		if rec == nil or (w and w.heap) then
			s.toHeap[wid] = nil
		elseif w then
			collapse(s, world, w, rec)
		end
	end
	-- WRECK_HIT: sparks off the wreck
	local onFx = RenderDeaths.onFx
	for _, wid in world.wreckHits do
		local rec = world.wrecks[wid]
		if onFx and rec and rec.feature == nil then
			local size = RenderDeaths.heapSize(world.defs.unitByIndex[rec.defIndex])
			onFx("scrapHit", rec.x, World.groundY(world, rec.x, rec.z) + 0.8 + size * 0.6, rec.z, 0.7 + size * 0.3)
		end
	end
	table.clear(world.wreckHits)
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
	table.clear(s.toHeap)
	for _, f in s.features do
		f.model:Destroy()
	end
	table.clear(s.features)
	for _, list in s.free do
		for _, m in list do
			m:Destroy()
		end
	end
	table.clear(s.free)
	s.stats.wrecks = 0
end

return RenderDeaths

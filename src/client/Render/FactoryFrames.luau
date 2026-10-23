--!strict
-- Factory production (C-152, Core/Nanoframe): the unit in production stands
-- on the factory's `buildpad` facing the exit. Parts below the build line
-- show as built; the rest are a team-colored nanoframe (ForceField). A
-- glowing line rises with the progress, and every `nano1..N` emitter of the
-- factory sprays at it while the progress moves. The progress eases between
-- the server's steps (Nanoframe.track).
--
-- The frame model comes from ModelPool like a unit's. Everything changed on
-- it (looks, picking) is put back before it returns to the pool.

local Nanoframe = require("../Core/Nanoframe")
local World = require("../Core/World")
local ModelPool = require("./ModelPool")
local TeamColors = require("./TeamColors")
local UnitRenderer = require("./UnitRenderer")

local FactoryFrames = {}

FactoryFrames.EDGE = 0.07 -- the build line's outline thickness, studs
local MAX_EMITTERS = 8

type Look = {
	part: BasePart,
	transparency: number,
	material: Enum.Material,
	color: Color3,
	appearance: SurfaceAppearance?,
	canQuery: boolean,
	bottom: number, -- unit space (the produced unit's own frame, ground at y = 0)
	top: number,
	built: boolean,
}

type Frame = {
	defIndex: number,
	factoryModel: Model,
	model: Model,
	root: BasePart,
	rootOffset: CFrame,
	looks: { Look },
	lo: number,
	hi: number,
	cx: number,
	cz: number,
	hx: number,
	hz: number,
	edges: { Part }, -- the build line: an outline around the frame's footprint
	targets: { Attachment },
	beams: { Beam },
	tracker: Nanoframe.Tracker,
	expected: number, -- seconds between progress steps at full economy
}

export type FactoryFrames = {
	frames: { [number]: Frame }, -- by factory unit id
}

function FactoryFrames.new(): FactoryFrames
	return { frames = {} }
end

local function frameColor(team: number): Color3
	return TeamColors(team):Lerp(Color3.new(1, 1, 1), 0.35)
end

-- Unit-space bounds of every part (the model's root at its rest offset).
local function measure(f: Frame)
	local place = f.root.CFrame * f.rootOffset:Inverse()
	local lo, hi = math.huge, -math.huge
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, look in f.looks do
		local p = look.part
		local rel = place:ToObjectSpace(p.CFrame)
		local s = p.Size / 2
		local rx, ry, rz = rel.XVector, rel.YVector, rel.ZVector
		local ey = math.abs(rx.Y) * s.X + math.abs(ry.Y) * s.Y + math.abs(rz.Y) * s.Z
		local ex = math.abs(rx.X) * s.X + math.abs(ry.X) * s.Y + math.abs(rz.X) * s.Z
		local ez = math.abs(rx.Z) * s.X + math.abs(ry.Z) * s.Y + math.abs(rz.Z) * s.Z
		local c = rel.Position
		look.bottom, look.top = c.Y - ey, c.Y + ey
		lo, hi = math.min(lo, look.bottom), math.max(hi, look.top)
		x0, x1 = math.min(x0, c.X - ex), math.max(x1, c.X + ex)
		z0, z1 = math.min(z0, c.Z - ez), math.max(z1, c.Z + ez)
	end
	if lo > hi then
		lo, hi, x0, x1, z0, z1 = 0, 1, -1, 1, -1, 1
	end
	f.lo, f.hi = lo, hi
	f.cx, f.cz = (x0 + x1) / 2, (z0 + z1) / 2
	f.hx, f.hz = (x1 - x0) / 2, (z1 - z0) / 2
end

local function setBuilt(look: Look, built: boolean, color: Color3)
	if look.built == built then
		return
	end
	look.built = built
	local p = look.part
	if built then
		p.Material = look.material
		p.Color = look.color
		p.Transparency = look.transparency
		if look.appearance then
			look.appearance.Parent = p
		end
	else
		if look.appearance then
			look.appearance.Parent = nil
		end
		p.Material = Enum.Material.ForceField
		p.Color = color
		p.Transparency = 0
	end
end

local function release(f: Frame)
	for _, look in f.looks do
		setBuilt(look, true, look.color)
		look.part.CanQuery = look.canQuery
	end
	for _, b in f.beams do
		b:Destroy()
	end
	for _, a in f.targets do
		a:Destroy()
	end
	for _, e in f.edges do
		e:Destroy()
	end
	ModelPool.release(f.model)
end

local function create(world: World.World, factory: World.Unit, factoryModel: Model, defIndex: number): Frame?
	local def = world.defs.unitByIndex[defIndex]
	if def == nil then
		return nil
	end
	local model = ModelPool.acquire(def, factory.team)
	local root = model.PrimaryPart
	if root == nil then
		ModelPool.release(model)
		return nil
	end
	local color = frameColor(factory.team)
	local looks: { Look } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(looks, {
				part = d,
				transparency = d.Transparency,
				material = d.Material,
				color = d.Color,
				appearance = d:FindFirstChildOfClass("SurfaceAppearance"),
				canQuery = d.CanQuery,
				bottom = 0,
				top = 0,
				built = true,
			})
			d.CanQuery = false -- clicks on the pad pick the factory, not the frame
		end
	end
	local f: Frame = {
		defIndex = defIndex,
		factoryModel = factoryModel,
		model = model,
		root = root,
		rootOffset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity,
		looks = looks,
		lo = 0,
		hi = 1,
		cx = 0,
		cz = 0,
		hx = 1,
		hz = 1,
		edges = {},
		targets = {},
		beams = {},
		tracker = Nanoframe.tracker(),
		expected = Nanoframe.expectedGap(def.cost.buildTime, (world.defs.unitByIndex[factory.defIndex or 0] or {} :: any).buildPower or 1),
	}
	measure(f)
	local w, d = f.hx * 2 + 0.3, f.hz * 2 + 0.3
	for i, size in { Vector3.new(w, FactoryFrames.EDGE, FactoryFrames.EDGE), Vector3.new(w, FactoryFrames.EDGE, FactoryFrames.EDGE), Vector3.new(FactoryFrames.EDGE, FactoryFrames.EDGE, d), Vector3.new(FactoryFrames.EDGE, FactoryFrames.EDGE, d) } do
		local e = Instance.new("Part")
		e.Name = "BuildLine" .. i
		e.Anchored = true
		e.CanCollide = false
		e.CanQuery = false
		e.CanTouch = false
		e.CastShadow = false
		e.Material = Enum.Material.Neon
		e.Color = color
		e.Size = size
		e.Parent = model
		table.insert(f.edges, e)
	end
	for i = 1, MAX_EMITTERS do
		local a = factoryModel:FindFirstChild("nano" .. i, true)
		if a == nil or not a:IsA("Attachment") then
			break
		end
		local target = Instance.new("Attachment")
		target.Name = "NanoTarget"
		target.Parent = workspace.Terrain
		table.insert(f.targets, target)
		local beam = Instance.new("Beam")
		beam.Name = "NanoSpray"
		beam.Attachment0 = a
		beam.Attachment1 = target
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 0.65),
		})
		beam.Width0 = 0.2
		beam.Width1 = 0.9
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = workspace.Terrain
		table.insert(f.beams, beam)
	end
	return f
end

-- Drops every frame (a rejoin, models rebuilt, strategic zoom).
function FactoryFrames.clear(ff: FactoryFrames)
	for id, f in ff.frames do
		release(f)
		ff.frames[id] = nil
	end
end

function FactoryFrames.step(ff: FactoryFrames, world: World.World, renderer: UnitRenderer.Renderer, now: number)
	local frames = ff.frames
	for id, f in frames do
		local u = world.units[id]
		local defIndex = if u then Nanoframe.producing(u) else nil
		if defIndex ~= f.defIndex or UnitRenderer.modelOf(renderer, id) ~= f.factoryModel then
			release(f)
			frames[id] = nil
		end
	end
	for id, d in renderer.drawn do
		local u = world.units[id]
		if u == nil or (u.build ~= nil and u.build < 1) then
			continue
		end
		local defIndex, reported = Nanoframe.producing(u)
		if defIndex == nil then
			continue
		end
		local f = frames[id]
		if f == nil then
			local made = create(world, u, d.model, defIndex)
			if made == nil then
				continue
			end
			f = made
			frames[id] = made
		end
		local frame = f :: Frame
		-- on the pad, facing the exit (the factory's heading)
		local pad = d.model:FindFirstChild("buildpad", true)
		local at = if pad and pad:IsA("Attachment") then pad.WorldPosition else d.root.Position
		local place = CFrame.new(at) * CFrame.Angles(0, u.heading + math.pi, 0)
		frame.root.CFrame = place * frame.rootOffset
		local progress, spraying = Nanoframe.track(frame.tracker, reported, now, frame.expected)
		local lineY = Nanoframe.lineY(frame.lo, frame.hi, progress)
		local color = frameColor(u.team)
		for _, look in frame.looks do
			setBuilt(look, Nanoframe.built(look.bottom, look.top, lineY, frame.lo, frame.hi), color)
		end
		local ex, ez = frame.hx + 0.15, frame.hz + 0.15
		local edges = frame.edges
		edges[1].CFrame = place * CFrame.new(frame.cx, lineY, frame.cz - ez)
		edges[2].CFrame = place * CFrame.new(frame.cx, lineY, frame.cz + ez)
		edges[3].CFrame = place * CFrame.new(frame.cx - ex, lineY, frame.cz)
		edges[4].CFrame = place * CFrame.new(frame.cx + ex, lineY, frame.cz)
		local n = #frame.beams
		for i, beam in frame.beams do
			beam.Enabled = spraying
			if spraying then
				local ox, oz = Nanoframe.sprayPoint(i, n, now, frame.hx, frame.hz)
				frame.targets[i].WorldPosition = (place * CFrame.new(frame.cx + ox, lineY, frame.cz + oz)).Position
				beam.Width1 = 0.7 + 0.35 * math.sin(now * 17 + i * 2.1)
			end
		end
	end
end

return FactoryFrames

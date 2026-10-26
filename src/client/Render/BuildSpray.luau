--!strict
-- Builders' nano spray (C-193): a team-colored stream from a working
-- builder to the structure it builds or repairs (Core/BuildTargets), its far
-- end sweeping over the target's top as the factory's spray does
-- (Core/Nanoframe.sprayPoint); a reclaim stream is violet and flows back.
-- It starts at the builder's `nano` attachment, else its `emitter` part,
-- else just above its model. One Beam per builder, pooled; none at
-- strategic zoom.

local BuildTargets = require("../Core/BuildTargets")
local Nanoframe = require("../Core/Nanoframe")
local World = require("../Core/World")
local TeamColors = require("./TeamColors")
local UnitRenderer = require("./UnitRenderer")

local BuildSpray = {}

BuildSpray.RECLAIM = Color3.fromRGB(200, 120, 235)

type Stream = { from: Attachment, to: Attachment, beam: Beam }
export type BuildSpray = { pool: { Stream }, used: number, list: { BuildTargets.Spray } }

function BuildSpray.new(): BuildSpray
	return { pool = {}, used = 0, list = {} }
end

local function stream(b: BuildSpray, i: number): Stream
	local s = b.pool[i]
	if s == nil then
		local from = Instance.new("Attachment")
		from.Name = "SprayFrom"
		from.Parent = workspace.Terrain
		local to = Instance.new("Attachment")
		to.Name = "SprayTo"
		to.Parent = workspace.Terrain
		local beam = Instance.new("Beam")
		beam.Name = "BuildSpray"
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.6) })
		beam.Width0 = 0.25
		beam.Width1 = 1.1
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Enabled = false
		beam.Parent = workspace.Terrain
		s = { from = from, to = to, beam = beam }
		b.pool[i] = s
	end
	return s
end

-- Where a builder's spray starts.
local function source(model: Model?, fallback: Vector3): Vector3
	if model then
		local a = model:FindFirstChild("nano1", true) or model:FindFirstChild("nano", true)
		if a and a:IsA("Attachment") then
			return a.WorldPosition
		end
		local e = model:FindFirstChild("emitter", true)
		if e and e:IsA("BasePart") then
			return e.Position
		end
		local cf, size = model:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y / 2, 0)
	end
	return fallback
end

-- Once a frame (`byUnit`: Waypoints' lists); `hidden` at strategic zoom.
function BuildSpray.step(b: BuildSpray, world: World.World, renderer: UnitRenderer.Renderer, byUnit: { [number]: { any } }, now: number, hidden: boolean)
	local n = 0
	if not hidden then
		for _, s in BuildTargets.list(world, byUnit, b.list) do
			-- a unit, or a wreck being reclaimed or resurrected (protocol 39)
			local u = world.units[s.builder]
			local t = if s.wreck then nil else world.units[s.target]
			local w = if s.wreck then world.wrecks[s.target] else nil
			local tdef = if t then World.def(world, t) elseif w then world.defs.unitByIndex[w.defIndex] else nil
			if u == nil or (t == nil and w == nil) or tdef == nil then
				continue
			end
			n += 1
			local st = stream(b, n)
			local ux, uy, uz = u.rx or u.x, u.ry or World.groundY(world, u.x, u.z), u.rz or u.z
			local from = source(UnitRenderer.modelOf(renderer, s.builder), Vector3.new(ux, uy + 3, uz))
			-- the far end sweeps over the target's top, at the height it has reached
			local half = tdef.footprint * 4
			local ox, oz = Nanoframe.sprayPoint(s.builder % 4 + 1, 4, now, half, half)
			local tModel = if t then UnitRenderer.modelOf(renderer, s.target) else nil
			local top
			if t and tModel then
				local cf, size = tModel:GetBoundingBox()
				local progress = if t.build and t.build < 1 then t.build else 1
				top = cf.Position.Y - size.Y / 2 + size.Y * math.max(0.15, progress)
			elseif t then
				top = (t.ry or World.groundY(world, t.x, t.z)) + 2
			else
				top = World.groundY(world, (w :: any).x, (w :: any).z) + 2 -- a wreck: low on the ground
			end
			local tx, tz
			if t then
				tx, tz = t.rx or t.x, t.rz or t.z
			else
				tx, tz = (w :: any).x, (w :: any).z
			end
			local to = Vector3.new(tx + ox, top, tz + oz)
			local reclaim = s.kind == "reclaim"
			-- a reclaim stream flows from the target back to the builder
			st.from.WorldPosition = if reclaim then to else from
			st.to.WorldPosition = if reclaim then from else to
			st.beam.Color = ColorSequence.new(if reclaim then BuildSpray.RECLAIM else TeamColors.of(u.team))
			st.beam.Width1 = 0.8 + 0.35 * math.sin(now * 17 + s.builder * 2.1)
			st.beam.Enabled = true
		end
	end
	for i = n + 1, b.used do
		b.pool[i].beam.Enabled = false
	end
	b.used = n
end

return BuildSpray

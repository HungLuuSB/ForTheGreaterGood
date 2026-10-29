--!strict
-- Builders' nano spray (C-193): a team-coloured stream of nano particles
-- (Render/NanoStream, C-251: a light beam before) from a working builder
-- to the structure it builds or repairs (Core/BuildTargets), aimed over the
-- target's top as the factory's spray is (Core/Nanoframe.sprayPoint); a
-- reclaim stream is violet and flows back. It starts at the builder's
-- `nano` attachment, else its `emitter` part, else just above its model.
-- One stream per builder, pooled; none at strategic zoom.

local BuildTargets = require("../Core/BuildTargets")
local Nanoframe = require("../Core/Nanoframe")
local World = require("../Core/World")
local NanoStream = require("./NanoStream")
local TeamColors = require("./TeamColors")
local UnitRenderer = require("./UnitRenderer")

local BuildSpray = {}

BuildSpray.RECLAIM = Color3.fromRGB(200, 120, 235)

export type BuildSpray = { pool: { NanoStream.Stream }, used: number, list: { BuildTargets.Spray } }

function BuildSpray.new(): BuildSpray
	return { pool = {}, used = 0, list = {} }
end

local function stream(b: BuildSpray, i: number): NanoStream.Stream
	local s = b.pool[i]
	if s == nil then
		s = NanoStream.new(workspace.Terrain)
		b.pool[i] = s
	end
	return s :: NanoStream.Stream
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
			if reclaim then
				NanoStream.aim(st, to, from, BuildSpray.RECLAIM)
			else
				NanoStream.aim(st, from, to, TeamColors.of(u.team))
			end
		end
	end
	for i = n + 1, b.used do
		NanoStream.off(b.pool[i])
	end
	b.used = n
end

return BuildSpray

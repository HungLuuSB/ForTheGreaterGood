--!strict
-- Draws tactical units (guide 15.1–15.2): one pooled model per tactical
-- unit, placed at its interpolated position with one BulkMoveTo per frame;
-- own, allied and seen units out of the camera area stay drawn at their
-- strategic spot (C-161).
-- Pieces move through their Motor6D.Transform, driven by piece scripts
-- (Core/PieceAnim, guide 14: visual only, the server decides when weapons
-- fire); each unit's LOD comes from its distance to the camera. Aircraft
-- bank and ships sit in the water as Core/Attitude says (C-31). A dead
-- unit's model stays where it was drawn until the render clock reaches the
-- death, then plays its death (Render/Deaths, C-34) and leaves its wreck.
-- A unit still being built is drawn semi-transparent (C-99, the user: it
-- is inert until complete).

local Attitude = require("../Core/Attitude")
local Deaths = require("../Core/Deaths")
local Interp = require("../Core/Interp")
local PieceAnim = require("../Core/PieceAnim")
local PieceScripts = require("../Core/PieceScripts/Registry")
local World = require("../Core/World")
local Schema = require("@shared/Net/Schema")
local Glow = require("./Glow")
local ModelPool = require("./ModelPool")
local RenderDeaths = require("./Deaths")

local UnitRenderer = {}

UnitRenderer.AIR_ALT = 35 -- studs: an aircraft out of the camera area never seen close (the sim's helicopter band)

UnitRenderer.BUILD_TRANSPARENCY = 0.6 -- a unit under construction (parts already more see-through stay so)

type Drawn = {
	model: Model,
	root: BasePart,
	rootOffset: CFrame,
	floats: boolean,
	motors: { [string]: Motor6D }, -- by piece name
	def: any,
	attitude: Attitude.State,
	hullHeight: number,
	building: boolean, -- drawn semi-transparent
	looks: { [BasePart]: number }?, -- each part's own transparency, while building
	glows: { Glow.Part }?, -- its glow parts (C-103; BAR meshes only)
	heads: { BasePart }?, -- its headlight glow parts
	pulses: { Glow.Pulse }?, -- its `pulse` pieces, which swell with their breath (C-257)
}

-- A unit under construction: see-through; complete: as modelled.
local function setBuilding(d: Drawn, building: boolean)
	if building == d.building then
		return
	end
	d.building = building
	if building then
		local looks = {}
		for _, p in d.model:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency < 1 then
				looks[p] = p.Transparency
				p.Transparency = math.max(p.Transparency, UnitRenderer.BUILD_TRANSPARENCY)
			end
		end
		d.looks = looks
	elseif d.looks then
		for p, t in d.looks do
			p.Transparency = t
		end
		d.looks = nil
	end
end

export type Renderer = {
	drawn: { [number]: Drawn },
	dying: { { drawn: Drawn, death: World.Death } }, -- dead units' models, kept until the render clock reaches the death
	parts: { BasePart },
	frames: { CFrame },
	anim: PieceAnim.Sched,
	deaths: RenderDeaths.State,
}

function UnitRenderer.new(anim: PieceAnim.Sched): Renderer
	return { drawn = {}, dying = {}, parts = {}, frames = {}, anim = anim, deaths = RenderDeaths.new() }
end

-- Drawn as a model: tactical units, and out of the camera area (strategic
-- records) own, allied and seen units whose type is known, so they stay
-- drawn instead of dropping out and popping back (C-161). Not aircraft in
-- the air there: their height isn't known (the icons show them).
function UnitRenderer.drawable(world: World.World, u: World.Unit): boolean
	if u.tier == "tactical" then
		return true
	end
	local def = World.def(world, u)
	if def == nil then
		return false
	end
	return def.domain ~= "air" or bit32.band(u.state or 0, Schema.UnitState.LANDED) ~= 0
end

local function show(r: Renderer, world: World.World, id: number)
	local u = world.units[id]
	local def = u and World.def(world, u)
	if u == nil or def == nil then
		return
	end
	local model = ModelPool.acquire(def, u.team)
	local motors: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	r.drawn[id] = {
		model = model,
		root = model.PrimaryPart :: BasePart,
		rootOffset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity,
		floats = World.floats(def),
		motors = motors,
		def = def,
		attitude = Attitude.new(),
		hullHeight = model:GetExtentsSize().Y,
		building = false,
		looks = nil,
	}
	local d = r.drawn[id]
	d.glows, d.heads = Glow.collect(model, def)
	d.pulses = Glow.collectPulses(model, def)
	PieceAnim.add(r.anim, id, def, PieceScripts.forDef(def))
end

-- Back to the pool with every joint at rest (the next unit starts clean).
local function release(d: Drawn)
	setBuilding(d, false)
	Glow.reset(d.glows, d.root, d.pulses)
	for _, motor in d.motors do
		motor.Transform = CFrame.identity
	end
	ModelPool.release(d.model)
end

local function hide(r: Renderer, id: number)
	local d = r.drawn[id]
	if d then
		PieceAnim.remove(r.anim, id)
		release(d)
		r.drawn[id] = nil
	end
end

-- Draws def `defId`'s units again with their current template (a mesh
-- model became ready, C-103).
function UnitRenderer.reshow(r: Renderer, world: World.World, defId: string)
	for id, d in r.drawn do
		if d.def.id == defId then
			hide(r, id)
			show(r, world, id)
		end
	end
end

-- Draws every unit again (the Detailed models setting flipped, C-106).
function UnitRenderer.reshowAll(r: Renderer, world: World.World)
	for id in r.drawn do
		hide(r, id)
		show(r, world, id)
	end
end

-- Removes every model (match restart).
function UnitRenderer.clear(r: Renderer)
	for id in r.drawn do
		hide(r, id)
	end
	for _, dying in r.dying do
		release(dying.drawn)
	end
	table.clear(r.dying)
	RenderDeaths.clear(r.deaths)
end

-- Applies the world's queues, then draws every tactical unit at render tick
-- `t`. With `hidden` (strategic zoom: models unparented) it only works out
-- the drawn positions (rx, ry, rz) for icons and selection. `camera` sets
-- each unit's animation LOD.
-- Extra drawn height for a unit at render tick `t` (the pre-game's
-- landing, Render/Landing), or nil for none.
UnitRenderer.lift = nil :: ((u: World.Unit, def: any, t: number) -> number)?

function UnitRenderer.step(r: Renderer, world: World.World, t: number, dt: number, hidden: boolean?, camera: Vector3?, speed: number?)
	for _, id in world.entered do
		local d, u = r.drawn[id], world.units[id]
		if d == nil or u == nil or d.def ~= World.def(world, u) then
			hide(r, id) -- an ID can come back after a LEAVE as another unit; start clean
			show(r, world, id)
		end -- else: drawn out of the camera area all along; keep the model (C-161)
	end
	table.clear(world.entered)
	for _, id in world.left do
		local u = world.units[id]
		if u == nil or not UnitRenderer.drawable(world, u) then
			hide(r, id)
		end
	end
	table.clear(world.left)
	-- strategic records that can be drawn (C-161): a model for each
	for id, u in world.units do
		if r.drawn[id] == nil and u.tier ~= "tactical" and UnitRenderer.drawable(world, u) then
			show(r, world, id)
		end
	end
	for _, death in world.died do
		-- the model stays where it was drawn until the render clock reaches the death
		local d = r.drawn[death.id]
		if d then
			PieceAnim.remove(r.anim, death.id)
			r.drawn[death.id] = nil
			table.insert(r.dying, { drawn = d, death = death })
		end
	end
	-- deaths play on the render clock (sim seconds), so they slow down and
	-- pause with the sim like the effects (C-48)
	local now = t / 15
	for i = #r.dying, 1, -1 do
		local dying = r.dying[i]
		local death = dying.death
		if t < 0 or death.tick <= t then
			table.remove(r.dying, i)
			local d = dying.drawn
			if t < 0 or hidden then
				release(d) -- nothing to watch
			else
				-- the burst comes from Effects; the shake or the flung pieces and the wreck
				-- from here, or an aircraft's fall (C-48)
				local crash = Deaths.crash(death, d.def, function(x: number, z: number): number
					return World.groundY(world, x, z)
				end)
				RenderDeaths.start(r.deaths, death.id, d.def, d.model, d.motors, death.severity, death.wreckId, now, function()
					release(d)
				end, crash, d.rootOffset)
			end
		end
	end
	RenderDeaths.step(r.deaths, now, speed)
	if t >= 0 then
		RenderDeaths.syncWrecks(r.deaths, world, t)
	end
	if t < 0 then
		return
	end

	local function simGround(gx: number, gz: number): number
		return World.simGroundY(world, gx, gz)
	end
	local parts, frames = r.parts, r.frames
	table.clear(parts)
	table.clear(frames)
	for id, d in r.drawn do
		local u = world.units[id]
		if u == nil or not UnitRenderer.drawable(world, u) or d.def ~= World.def(world, u) then
			hide(r, id)
			continue
		end
		local x, z, alt, heading
		if u.tier == "tactical" then
			x, z, alt, heading = Interp.sample(u, t)
		else
			-- out of the camera area: the record's spot (gliding, C-151), last
			-- heading; an aircraft keeps its last height, or a cruising one if
			-- it was never seen close (C-192: not on the ground)
			local air = d.def.domain == "air"
			x, z, alt, heading = u.sx or u.x, u.sz or u.z, if air then (if (u.alt or 0) > 0 then u.alt :: number else UnitRenderer.AIR_ALT) else 0, u.heading
		end
		local y
		if u.tier == "tactical" and d.def.domain == "air" and alt > 0 then
			-- in flight: the snapshots' own heights, interpolated (G16)
			y = Interp.height(u, t, simGround)
		else
			y = World.groundY(world, x, z, d.floats) + alt
		end
		local lift = UnitRenderer.lift
		if lift then
			y += lift(u, d.def, t) -- a Commander landing from the sky (C-218)
		end
		if d.floats then
			y += Attitude.waterOffset(d.def, u.state or 0, d.hullHeight)
		end
		u.rx, u.ry, u.rz = x, y, z
		u.rheading = heading
		if hidden then
			continue
		end
		setBuilding(d, u.build ~= nil and u.build < 1)
		local au = r.anim.units[id]
		if au and camera then
			au.lod = PieceAnim.lodAt((camera - Vector3.new(x, y, z)).Magnitude)
		end
		local roll, pitch = Attitude.step(d.attitude, d.def, x, z, heading, dt)
		table.insert(parts, d.root)
		local frame = CFrame.new(x, y, z) * CFrame.Angles(0, heading + math.pi, 0)
		if roll ~= 0 or pitch ~= 0 then
			frame *= CFrame.Angles(pitch, 0, roll)
		end
		table.insert(frames, frame * d.rootOffset)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Writes the joints of the pieces the scripts moved (only those changed).
function UnitRenderer.applyPieces(r: Renderer): number
	local n = 0
	for _, p in PieceAnim.take(r.anim) do
		local d = r.drawn[p.unit]
		local motor = d and d.motors[p.name]
		if motor then
			local rot, pos = p.rot, p.pos
			-- turn about the joint's pivot, then move along the turned axes (recoil follows the barrel)
			motor.Transform = CFrame.Angles(rot[1], rot[2], rot[3]) * CFrame.new(pos[1], pos[2], pos[3])
			n += 1
		end
	end
	return n
end

-- The unit a drawn model belongs to (click picking), or nil.
function UnitRenderer.unitOfModel(r: Renderer, model: Instance): number?
	for id, d in r.drawn do
		if d.model == model then
			return id
		end
	end
	return nil
end

-- Model of a drawn unit (selection, effects), or nil.
function UnitRenderer.modelOf(r: Renderer, id: number): Model?
	local d = r.drawn[id]
	return d and d.model
end

return UnitRenderer

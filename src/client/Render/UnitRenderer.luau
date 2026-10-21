--!strict
-- Draws tactical units (guide 15.1–15.2): one pooled model per tactical
-- unit, placed at its interpolated position with one BulkMoveTo per frame.
-- Pieces move through their Motor6D.Transform, driven by piece scripts
-- (Core/PieceAnim, guide 14: visual only, the server decides when weapons
-- fire); each unit's LOD comes from its distance to the camera.

local Interp = require("../Core/Interp")
local PieceAnim = require("../Core/PieceAnim")
local PieceScripts = require("../Core/PieceScripts/Registry")
local World = require("../Core/World")
local ModelPool = require("./ModelPool")

local UnitRenderer = {}

type Drawn = {
	model: Model,
	root: BasePart,
	rootOffset: CFrame,
	floats: boolean,
	motors: { [string]: Motor6D }, -- by piece name
}

export type Renderer = {
	drawn: { [number]: Drawn },
	dying: { { drawn: Drawn, tick: number } }, -- dead units' models, kept until the render clock reaches the death
	parts: { BasePart },
	frames: { CFrame },
	anim: PieceAnim.Sched,
}

function UnitRenderer.new(anim: PieceAnim.Sched): Renderer
	return { drawn = {}, dying = {}, parts = {}, frames = {}, anim = anim }
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
		floats = def.domain == "naval",
		motors = motors,
	}
	PieceAnim.add(r.anim, id, def, PieceScripts.forDef(def))
end

-- Back to the pool with every joint at rest (the next unit starts clean).
local function release(d: Drawn)
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

-- Removes every model (match restart).
function UnitRenderer.clear(r: Renderer)
	for id in r.drawn do
		hide(r, id)
	end
	for _, dying in r.dying do
		release(dying.drawn)
	end
	table.clear(r.dying)
end

-- Applies the world's queues, then draws every tactical unit at render tick
-- `t`. With `hidden` (strategic zoom: models unparented) it only works out
-- the drawn positions (rx, ry, rz) for icons and selection. `camera` sets
-- each unit's animation LOD.
function UnitRenderer.step(r: Renderer, world: World.World, t: number, dt: number, hidden: boolean?, camera: Vector3?)
	for _, id in world.entered do
		hide(r, id) -- an ID can come back after a LEAVE; start clean
		show(r, world, id)
	end
	table.clear(world.entered)
	for _, id in world.left do
		hide(r, id)
	end
	table.clear(world.left)
	for _, death in world.died do
		-- the model stays where it was drawn until the render clock reaches the death
		local d = r.drawn[death.id]
		if d then
			PieceAnim.remove(r.anim, death.id)
			r.drawn[death.id] = nil
			table.insert(r.dying, { drawn = d, tick = death.tick })
		end
	end
	for i = #r.dying, 1, -1 do
		local dying = r.dying[i]
		if t < 0 or dying.tick <= t then
			release(dying.drawn) -- the burst comes from Effects; wrecks later
			table.remove(r.dying, i)
		end
	end
	if t < 0 then
		return
	end

	local parts, frames = r.parts, r.frames
	table.clear(parts)
	table.clear(frames)
	for id, d in r.drawn do
		local u = world.units[id]
		if u == nil or u.tier ~= "tactical" then
			hide(r, id)
			continue
		end
		local x, z, alt, heading = Interp.sample(u, t)
		local y = World.groundY(world, x, z, d.floats) + alt
		u.rx, u.ry, u.rz = x, y, z
		if hidden then
			continue
		end
		local au = r.anim.units[id]
		if au and camera then
			au.lod = PieceAnim.lodAt((camera - Vector3.new(x, y, z)).Magnitude)
		end
		table.insert(parts, d.root)
		table.insert(frames, CFrame.new(x, y, z) * CFrame.Angles(0, heading + math.pi, 0) * d.rootOffset)
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

-- Model of a drawn unit (selection, effects), or nil.
function UnitRenderer.modelOf(r: Renderer, id: number): Model?
	local d = r.drawn[id]
	return d and d.model
end

return UnitRenderer

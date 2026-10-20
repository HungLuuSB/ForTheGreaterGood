--!strict
-- Draws tactical units (guide 15.1–15.2): one pooled model per tactical
-- unit, placed at its interpolated position with one BulkMoveTo per frame;
-- turrets and barrels follow the replicated aim through Motor6D.Transform
-- (guide 14: visual only, the server decides when weapons fire).

local Interp = require("../Core/Interp")
local World = require("../Core/World")
local ModelPool = require("./ModelPool")

local UnitRenderer = {}

local AIM_FOLLOW = 14 -- 1/s: how fast drawn aim closes on the replicated aim

type Joint = { motor: Motor6D, angle: number, drawn: number }
type Weapon = { yaw: Joint?, pitch: Joint? }
type Drawn = {
	model: Model,
	root: BasePart,
	rootOffset: CFrame,
	floats: boolean,
	weapons: { [number]: Weapon },
}

export type Renderer = {
	drawn: { [number]: Drawn },
	dying: { { model: Model, tick: number } }, -- dead units' models, kept until the render clock reaches the death
	parts: { BasePart },
	frames: { CFrame },
}

function UnitRenderer.new(): Renderer
	return { drawn = {}, dying = {}, parts = {}, frames = {} }
end

local function jointOf(model: Model, piece: string?): Joint?
	if piece == nil then
		return nil
	end
	local part = model:FindFirstChild(piece, true)
	local motor = part and part:FindFirstChildOfClass("Motor6D")
	if motor then
		return { motor = motor, angle = 0, drawn = 0 }
	end
	return nil
end

local function show(r: Renderer, world: World.World, id: number)
	local u = world.units[id]
	local def = u and World.def(world, u)
	if u == nil or def == nil then
		return
	end
	local model = ModelPool.acquire(def, u.team)
	local weapons = {}
	for slot, w in def.weapons do
		weapons[slot] = { yaw = jointOf(model, w.turretPiece), pitch = jointOf(model, w.pitchPiece) }
	end
	r.drawn[id] = {
		model = model,
		root = model.PrimaryPart :: BasePart,
		rootOffset = (model:GetAttribute("RootOffset") :: CFrame?) or CFrame.identity,
		floats = def.domain == "naval",
		weapons = weapons,
	}
end

local function hide(r: Renderer, id: number)
	local d = r.drawn[id]
	if d then
		ModelPool.release(d.model)
		r.drawn[id] = nil
	end
end

local function follow(j: Joint, target: number, k: number, pitch: boolean)
	local diff = (target - j.drawn + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) < 1e-4 then
		return
	end
	j.drawn += diff * k
	j.motor.Transform = if pitch then CFrame.Angles(j.drawn, 0, 0) else CFrame.Angles(0, j.drawn, 0)
end

-- Removes every model (match restart).
function UnitRenderer.clear(r: Renderer)
	for id in r.drawn do
		hide(r, id)
	end
	for _, dying in r.dying do
		ModelPool.release(dying.model)
	end
	table.clear(r.dying)
end

-- Applies the world's queues, then draws every tactical unit at render tick `t`.
function UnitRenderer.step(r: Renderer, world: World.World, t: number, dt: number)
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
			r.drawn[death.id] = nil
			table.insert(r.dying, { model = d.model, tick = death.tick })
		end
	end
	for i = #r.dying, 1, -1 do
		local dying = r.dying[i]
		if t < 0 or dying.tick <= t then
			ModelPool.release(dying.model) -- the burst comes from Effects; wrecks later
			table.remove(r.dying, i)
		end
	end
	if t < 0 then
		return
	end

	local parts, frames = r.parts, r.frames
	table.clear(parts)
	table.clear(frames)
	local k = math.min(1, dt * AIM_FOLLOW)
	for id, d in r.drawn do
		local u = world.units[id]
		if u == nil or u.tier ~= "tactical" then
			hide(r, id)
			continue
		end
		local x, z, alt, heading = Interp.sample(u, t)
		local y = World.groundY(world, x, z, d.floats) + alt
		u.rx, u.ry, u.rz = x, y, z
		table.insert(parts, d.root)
		table.insert(frames, CFrame.new(x, y, z) * CFrame.Angles(0, heading + math.pi, 0) * d.rootOffset)
		for slot, a in u.aim do
			local w = d.weapons[slot]
			if w then
				if w.yaw then
					follow(w.yaw, a.yaw, k, false)
				end
				if w.pitch then
					follow(w.pitch, a.pitch, k, true)
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Model of a drawn unit (selection, effects), or nil.
function UnitRenderer.modelOf(r: Renderer, id: number): Model?
	local d = r.drawn[id]
	return d and d.model
end

return UnitRenderer

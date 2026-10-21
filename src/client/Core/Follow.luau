--!strict
-- Camera follow (C-43), toggled with T or the placeholder button. Pure Luau
-- (C-7): which thing to follow, where it is drawn this frame, and where the
-- camera's ground focus goes so that it sits in the middle of the screen.
--
-- With units selected the first selected unit is followed; with nothing
-- selected, the homing missile drawn nearest the screen centre. A target
-- ends when its unit leaves the world or its missile ends (a projectile ID
-- can be reused, so a missile target keeps its Proj table to tell).

local Effects = require("./Effects")
local Interp = require("./Interp")
local Selection = require("./Selection")
local World = require("./World")

local Follow = {}

Follow.MIN_GAP = 40 -- studs: the camera stays at least this far in front of a followed target

export type Target = {
	kind: "unit" | "missile",
	id: number,
	proj: Effects.Proj?, -- a missile target's projectile
}

-- What T starts following: the first selected unit the world knows, else
-- the on-screen homing missile in `visible` (Effects.visible's list) drawn
-- nearest the screen point (cx, cy); nil if there is neither.
function Follow.pick(world: World.World, selection: { number }, visible: { { any } }, project: Selection.Projector, cx: number, cy: number): Target?
	for _, id in selection do
		if world.units[id] then
			return { kind = "unit", id = id }
		end
	end
	local best: Effects.Proj?, bestD = nil, math.huge
	for _, v in visible do
		local p = v[1] :: Effects.Proj
		if p.weapon.type ~= "HOMING" then
			continue
		end
		local sx, sy, onScreen = project(v[2], v[3], v[4])
		local d = (sx - cx) ^ 2 + (sy - cy) ^ 2
		if onScreen and d < bestD then
			best, bestD = p, d
		end
	end
	if best then
		return { kind = "missile", id = best.id, proj = best }
	end
	return nil
end

-- Where `target` is drawn at render tick `t`, or nil once it has ended.
-- Units: as UnitRenderer draws them (Interp at `t`, on the ground plus
-- their altitude); missiles: their entry in `visible`, else their prediction.
function Follow.position(world: World.World, fx: Effects.Fx, visible: { { any } }, target: Target, t: number): (number?, number?, number?)
	if target.kind == "unit" then
		local u = world.units[target.id]
		if u == nil then
			return nil, nil, nil
		end
		local x, z, alt = Interp.sample(u, t)
		return x, World.groundY(world, x, z) + alt, z
	end
	local p = fx.projectiles[target.id]
	if p == nil or p ~= target.proj then
		return nil, nil, nil
	end
	for _, v in visible do
		if v[1] == p then
			return v[2], v[3], v[4]
		end
	end
	return p.x, p.y, p.z
end

-- The camera's ground focus that puts point (x, y, z) in the middle of the
-- screen. The camera looks at its focus from `pitch` above the horizon,
-- turned by `yaw` (Camera.apply); a point `alt` above the focus's ground
-- lies on that sight line alt / tan(pitch) nearer the camera, so the focus
-- moves that far away from it. `groundAt` is the ground height; it is read
-- under the point, then under the first guess. Also returns the least
-- camera distance that keeps the point in front of the camera: its slant
-- from the focus (alt / sin(pitch)) plus MIN_GAP; a missile climbing above
-- the camera would otherwise be behind it.
function Follow.focus(x: number, y: number, z: number, pitch: number, yaw: number, groundAt: (number, number) -> number): (number, number, number)
	local bx, bz = -math.sin(yaw), math.cos(yaw) -- towards the camera, on the ground
	local fx, fz, alt = x, z, 0
	for _ = 1, 2 do
		alt = math.max(0, y - groundAt(fx, fz))
		local back = alt / math.tan(pitch)
		fx, fz = x - bx * back, z - bz * back
	end
	return fx, fz, alt / math.sin(pitch) + Follow.MIN_GAP
end

return Follow

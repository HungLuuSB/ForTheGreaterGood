--!strict
-- Attack mode's preview (C-58): for each selected unit with a lofted weapon
-- (a nuke silo, S-48), the arc its shot would fly to the point under the
-- cursor, its flight time and the blast it would leave there. The path is
-- the server's (Weapons.fire, lofted branch, and Projectiles, S-51):
-- launched straight up from the unit's position at Combat.MUZZLE_HEIGHT of
-- its height at `projectileSpeed`, stepped with Shared/Combat/Lofted toward
-- the spot (boost to `climbHeight`, pitch-over, lofted arc) until it lands.
-- Bombers with a carpet (a BOMB weapon with a salvo, S-178, F33) show where
-- each bomb of the salvo lands: the first on the spot, the rest further on
-- along the approach, `salvo.delay` × the bomber's speed apart.

local Layers = require("@shared/Grid/Layers")
local Effects = require("./Effects")
local World = require("./World")

local AttackPreview = {}

AttackPreview.EVERY = 3 -- ticks between drawn points
AttackPreview.MAX_TICKS = 15 * 60
AttackPreview.MAX_ARCS = 4 -- selected launchers previewed at once
AttackPreview.MUZZLE_HEIGHT = 0.6 -- Combat.MUZZLE_HEIGHT: fraction of the unit's height

export type Arc = {
	unitId: number,
	weapon: any,
	points: { { number } }, -- { x, y, z } from the launch to the spot
	seconds: number, -- sim seconds in the air
	apexY: number, -- highest point
	inRange: boolean,
	stock: number?, -- missiles in stock (own units, C-56)
	x: number, -- the aimed spot
	z: number,
}

local function groundAt(world: World.World, x: number, z: number): number
	local layers = world.layers
	return if layers then Layers.heightAt(layers, x, z) else 0
end

-- The unit's lofted weapon and its slot, if it has one.
function AttackPreview.loftedWeapon(world: World.World, u: World.Unit): (any?, number?)
	local def = World.def(world, u)
	if def == nil then
		return nil, nil
	end
	for slot, ws in def.weapons do
		local w = world.defs.weaponByIndex[(ws :: any).weaponIndex]
		if w and (w :: any).apex then
			return w, slot
		end
	end
	return nil, nil
end

-- Unit `u`'s lofted shot from `weapon` (in `slot`) to (tx, tz).
function AttackPreview.arc(world: World.World, u: World.Unit, weapon: any, slot: number, tx: number, tz: number): Arc
	local def = World.def(world, u) :: any
	local launchY = groundAt(world, u.x, u.z) + u.alt + Effects.UNIT_HEIGHT * def.footprint * AttackPreview.MUZZLE_HEIGHT
	local dx, dz = tx - u.x, tz - u.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local goal = { tx, groundAt(world, tx, tz), tz }
	local x, y, z = u.x, launchY, u.z
	local vx, vy, vz = 0, weapon.projectileSpeed or 0, 0
	local points = { { x, y, z } }
	local apexY, seconds = y, 0
	for k = 1, AttackPreview.MAX_TICKS do
		local px, py, pz = x, y, z
		x, y, z, vx, vy, vz = Effects.loftedStep(world, weapon, goal, x, y, z, vx, vy, vz)
		apexY = math.max(apexY, y)
		local ground = groundAt(world, x, z)
		if vy < 0 and y <= ground then
			-- where the tick's chord meets the ground
			local f = if py > y then math.clamp((py - ground) / (py - y), 0, 1) else 1
			table.insert(points, { px + (x - px) * f, ground, pz + (z - pz) * f })
			seconds = (k - 1 + f) / 15
			break
		end
		if k % AttackPreview.EVERY == 0 then
			table.insert(points, { x, y, z })
		end
		seconds = k / 15
	end
	return {
		unitId = u.id,
		weapon = weapon,
		points = points,
		seconds = seconds,
		apexY = apexY,
		inRange = dist <= weapon.range,
		stock = if u.stock then (u.stock :: { [number]: number })[slot] else nil,
		x = tx,
		z = tz,
	}
end

-- Arcs for the selected units with lofted weapons, aimed at (tx, tz).
function AttackPreview.arcs(world: World.World, selection: { number }, tx: number, tz: number): { Arc }
	local out = {}
	for _, id in selection do
		local u = world.units[id]
		if u == nil then
			continue
		end
		local weapon, slot = AttackPreview.loftedWeapon(world, u)
		if weapon and slot then
			table.insert(out, AttackPreview.arc(world, u, weapon, slot, tx, tz))
			if #out >= AttackPreview.MAX_ARCS then
				break
			end
		end
	end
	return out
end

export type Carpet = {
	unitId: number,
	weapon: any,
	points: { { number } }, -- { x, z } of each bomb, first to last
}

-- The unit's carpet-bombing weapon (a BOMB with a salvo of 2 or more).
function AttackPreview.carpetWeapon(world: World.World, u: World.Unit): any?
	local def = World.def(world, u)
	if def == nil then
		return nil
	end
	for _, ws in def.weapons do
		local w = world.defs.weaponByIndex[(ws :: any).weaponIndex]
		if w and w.type == "BOMB" and w.salvo and (w.salvo.count or 1) > 1 then
			return w
		end
	end
	return nil
end

-- Each selected bomber's salvo aimed at (tx, tz): the bombs along the line
-- from the bomber through the spot (its approach; its heading when over it).
function AttackPreview.carpets(world: World.World, selection: { number }, tx: number, tz: number): { Carpet }
	local out = {}
	for _, id in selection do
		local u = world.units[id]
		local w = u and AttackPreview.carpetWeapon(world, u)
		if u == nil or w == nil then
			continue
		end
		local def = World.def(world, u)
		local speed = (def and def.movement and def.movement.maxSpeed) or 0
		local dx, dz = tx - u.x, tz - u.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 1e-3 then
			dx, dz, d = math.sin(u.heading), math.cos(u.heading), 1
		end
		local ux, uz = dx / d, dz / d
		local step = (w.salvo.delay or 0) * speed
		local points = {}
		for k = 0, w.salvo.count - 1 do
			table.insert(points, { tx + ux * step * k, tz + uz * step * k })
		end
		table.insert(out, { unitId = id, weapon = w, points = points })
		if #out >= AttackPreview.MAX_ARCS then
			break
		end
	end
	return out
end

return AttackPreview

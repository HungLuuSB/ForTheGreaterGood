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
local PlacementRules = require("@shared/Grid/PlacementRules")
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

export type Bolt = {
	unitId: number,
	weapon: any,
	x0: number, -- where the bolt starts: the Commander
	z0: number,
	x1: number, -- the end of its range
	z1: number,
	reach: number, -- studs either side of the path (weapon.bolt)
	hits: { number }, -- the units in its way now, any team (it spares only its owner)
}

-- The unit's D-Gun (a weapon with a `bolt`, S-194).
function AttackPreview.boltWeapon(world: World.World, u: World.Unit): any?
	local def = World.def(world, u)
	if def == nil then
		return nil
	end
	for _, ws in def.weapons do
		local w = world.defs.weaponByIndex[(ws :: any).weaponIndex]
		if w and w.bolt then
			return w
		end
	end
	return nil
end

AttackPreview.BOLT_REACH = 0.85 -- of the range: a D-Gun point is pulled in to this (the server walks past 0.9)

-- The enemy unit `targetId` a D-Gun click on it aims at, else nil (own
-- units and empty ground: a point).
function AttackPreview.boltTarget(world: World.World, targetId: number?): World.Unit?
	local t = if targetId then world.units[targetId] else nil
	return if t and t.team ~= world.me.team then t else nil
end

-- Whether unit `u` walks before firing its D-Gun `weapon` at (tx, tz): the
-- server walks it when the point is farther than 0.9 of the range (Commands).
function AttackPreview.boltWalks(u: World.Unit, weapon: any, tx: number, tz: number): boolean
	return (tx - u.x) ^ 2 + (tz - u.z) ^ 2 > (weapon.range * 0.9) ^ 2
end

-- Where unit `u` is sent to fire its D-Gun `weapon` at the ground point
-- (tx, tz) (C-264, the user: the path always stays inside the Commander's
-- range): a point out of range is pulled in along the same line, so the
-- Commander fires from where it stands instead of walking toward it. (An
-- enemy unit clicked out of range is aimed at as it is: the Commander walks
-- to it until in range, then fires.)
function AttackPreview.boltPoint(u: World.Unit, weapon: any, tx: number, tz: number): (number, number)
	local dx, dz = tx - u.x, tz - u.z
	local d = math.sqrt(dx * dx + dz * dz)
	local reach = weapon.range * AttackPreview.BOLT_REACH
	if d <= reach then
		return tx, tz
	end
	return u.x + dx / d * reach, u.z + dz / d * reach
end

-- D-Gun mode's preview (C-264, the user: no hitbox or path shown): each
-- selected Commander's bolt aimed at (tx, tz), or at the enemy unit
-- `targetId` under the cursor, the server's rules (Commands DGUN,
-- Projectiles' bolt): fired from where it stands (the point pulled into
-- range, `boltPoint`), it flies level for its whole range and destroys
-- every unit whose centre is within `bolt` + its radius of the path, own
-- ones too; aircraft in flight pass over it. An enemy unit out of range
-- shows no path (the user): the Commander walks to it first.
function AttackPreview.bolts(world: World.World, selection: { number }, tx: number, tz: number, targetId: number?): { Bolt }
	local out = {}
	local target = AttackPreview.boltTarget(world, targetId)
	if target then
		tx, tz = target.x, target.z
	end
	for _, id in selection do
		local u = world.units[id]
		local w = u and AttackPreview.boltWeapon(world, u)
		if u == nil or w == nil or (target and AttackPreview.boltWalks(u, w, tx, tz)) then
			continue
		end
		local dx, dz = tx - u.x, tz - u.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 1e-3 then
			dx, dz, d = math.sin(u.heading), math.cos(u.heading), 1
		end
		local ux, uz = dx / d, dz / d
		local x0, z0 = u.x, u.z
		local x1, z1 = x0 + ux * w.range, z0 + uz * w.range
		local hits = {}
		local lx, lz = x1 - x0, z1 - z0
		local len2 = lx * lx + lz * lz
		for oid, o in world.units do
			if oid == id then
				continue
			end
			local odef = World.def(world, o)
			if odef == nil or (odef.domain == "air" and (o.alt or 0) > 0.5) then
				continue
			end
			local t = math.clamp(((o.x - x0) * lx + (o.z - z0) * lz) / len2, 0, 1)
			local ex, ez = x0 + lx * t - o.x, z0 + lz * t - o.z
			local r = w.bolt + odef.footprint * PlacementRules.RADIUS_PER_FOOTPRINT
			if ex * ex + ez * ez <= r * r then
				table.insert(hits, oid)
			end
		end
		table.sort(hits)
		table.insert(out, { unitId = id, weapon = w, x0 = x0, z0 = z0, x1 = x1, z1 = z1, reach = w.bolt, hits = hits })
		if #out >= AttackPreview.MAX_ARCS then
			break
		end
	end
	return out
end

return AttackPreview

--!strict
-- Attack mode's preview (C-58): for each selected unit with a lofted weapon
-- (a nuke silo, S-48), the arc its shot would fly to the point under the
-- cursor, its flight time and the blast it would leave there. The arc is
-- the server's (Weapons.fire, lofted branch): launched from the unit's
-- position at Combat.MUZZLE_HEIGHT of its height, straight up at
-- sqrt(2 g apex), across at the speed that lands it on the spot.

local Layers = require("@shared/Grid/Layers")
local Effects = require("./Effects")
local World = require("./World")

local AttackPreview = {}

AttackPreview.SAMPLES = 48 -- points along a drawn arc
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
	local g = weapon.gravity :: number
	local launchY = groundAt(world, u.x, u.z) + u.alt + Effects.UNIT_HEIGHT * def.footprint * AttackPreview.MUZZLE_HEIGHT
	local dx, dz = tx - u.x, tz - u.z
	local dist = math.sqrt(dx * dx + dz * dz)
	local drop = launchY - groundAt(world, tx, tz)
	local up = math.sqrt(2 * g * weapon.apex)
	local t = (up + math.sqrt(math.max(up * up + 2 * g * drop, 0))) / g
	local points = table.create(AttackPreview.SAMPLES + 1)
	for i = 0, AttackPreview.SAMPLES do
		local s = t * i / AttackPreview.SAMPLES
		table.insert(points, { u.x + dx * s / t, launchY + up * s - 0.5 * g * s * s, u.z + dz * s / t })
	end
	return {
		unitId = u.id,
		weapon = weapon,
		points = points,
		seconds = t,
		apexY = launchY + up * up / (2 * g),
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

return AttackPreview

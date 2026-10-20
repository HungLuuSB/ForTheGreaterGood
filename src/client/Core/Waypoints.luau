--!strict
-- What each own unit was last ordered to do, from the commands this client
-- sent (order queues aren't replicated, net.md section 9): drawn as lines
-- for selected units (guide 15.6). A point is dropped when its unit gets
-- close; a unit target follows that unit and is dropped when it's gone.
-- Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local Orders = require("./Orders")
local World = require("./World")

local Waypoints = {}

Waypoints.REACHED = 10 -- studs, at least; groups stand in a formation around the point
Waypoints.IDLE_SECONDS = 2 -- a unit standing still this long has no orders left
Waypoints.MAX_PER_UNIT = 16

local CT = Schema.CmdType

export type Point = { kind: number, x: number, z: number, targetId: number?, reach: number }
export type Waypoints = { byUnit: { [number]: { Point } }, idleSince: { [number]: number } }

function Waypoints.new(): Waypoints
	return { byUnit = {}, idleSince = {} }
end

-- How close counts as there: the server spreads a group in a formation
-- around a point (Orders.lineSlots), about spacing × √n across.
local function reachFor(world: World.World, ids: { number }): number
	local footprint = 1
	for _, id in ids do
		local u = world.units[id]
		local def = u and World.def(world, u)
		if def then
			footprint = math.max(footprint, def.footprint)
		end
	end
	local spacing = 2 * footprint * Orders.RADIUS_PER_FOOTPRINT * Orders.SLOT_SPACING
	return math.max(Waypoints.REACHED, spacing * math.sqrt(#ids))
end

-- Records `intent` sent to `ids`.
function Waypoints.issue(wp: Waypoints, world: World.World, intent: Orders.Intent, ids: { number })
	local kind = intent.cmdType
	if kind == CT.STOP then
		for _, id in ids do
			wp.byUnit[id] = nil
		end
		return
	end
	if kind ~= CT.MOVE and kind ~= CT.FIGHT and kind ~= CT.PATROL and kind ~= CT.ATTACK
		and kind ~= CT.ATTACK_GROUND and kind ~= CT.GUARD and kind ~= CT.REPAIR and kind ~= CT.RECLAIM then
		return -- state commands don't move anything
	end
	local slots = if intent.x2
		then Orders.lineSlots(world, ids, intent.x :: number, intent.z :: number, intent.x2, intent.z2 :: number)
		else nil
	local reach = if slots then Waypoints.REACHED else reachFor(world, ids)
	for _, id in ids do
		local list = wp.byUnit[id]
		if list == nil or not intent.queue then
			list = {}
			wp.byUnit[id] = list
		end
		if #list >= Waypoints.MAX_PER_UNIT then
			continue
		end
		local point: Point
		if intent.targetId then
			local t = world.units[intent.targetId]
			point = { kind = kind, x = if t then t.x else 0, z = if t then t.z else 0, targetId = intent.targetId, reach = 0 }
		elseif slots then
			point = { kind = kind, x = slots[id][1], z = slots[id][2], reach = reach }
		else
			point = { kind = kind, x = intent.x :: number, z = intent.z :: number, reach = reach }
		end
		table.insert(list, point)
		wp.idleSince[id] = nil
	end
end

-- Follows unit targets, drops reached points, units that are gone and
-- units that have stood still for IDLE_SECONDS (`now` in seconds).
function Waypoints.update(wp: Waypoints, world: World.World, now: number)
	for id, list in wp.byUnit do
		local u = world.units[id]
		if u == nil then
			wp.byUnit[id] = nil
			wp.idleSince[id] = nil
			continue
		end
		if bit32.band(u.state, World.State.MOVING) == 0 then
			local since = wp.idleSince[id]
			if since == nil then
				wp.idleSince[id] = now
			elseif now - since >= Waypoints.IDLE_SECONDS then
				wp.byUnit[id] = nil
				wp.idleSince[id] = nil
				continue
			end
		else
			wp.idleSince[id] = nil
		end
		local first = list[1]
		while first do
			if first.targetId then
				local t = world.units[first.targetId]
				if t == nil then
					table.remove(list, 1)
					first = list[1]
					continue
				end
				first.x, first.z = t.rx or t.x, t.rz or t.z
				break -- attack / guard / repair last until the target is gone
			end
			local x, z = u.rx or u.x, u.rz or u.z
			if (first.x - x) ^ 2 + (first.z - z) ^ 2 <= first.reach ^ 2 and first.kind ~= CT.PATROL then
				table.remove(list, 1)
				first = list[1]
			else
				break
			end
		end
		if #list == 0 then
			wp.byUnit[id] = nil
		end
	end
end

return Waypoints

--!strict
-- What each own unit was last ordered to do, from the commands this client
-- sent (order queues aren't replicated, net.md section 9): drawn as lines
-- for selected units (guide 15.6) and as translucent queued structures. A
-- point is dropped when its unit gets close; a unit target follows that unit
-- and is dropped when it's gone; a queued build is done once an own frame of
-- that structure stands on its spot (C-23). A factory's orders are for the
-- units it builds (the sim's rally point): they stay until replaced or
-- stopped (C-109).
-- Pure Luau (C-7).

local Formation = require("@shared/Grid/Formation")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Schema = require("@shared/Net/Schema")
local Orders = require("./Orders")
local Placement = require("./Placement")
local Upgrades = require("./Upgrades")
local World = require("./World")

local Waypoints = {}

Waypoints.REACHED = 10 -- studs, at least; groups stand in a formation around the point
Waypoints.IDLE_SECONDS = 2 -- a unit standing still this long has no orders left
-- A builder stands still while it builds, so a queued build only expires
-- after this long idle with no own frame going up within its build range
-- (a fallback for a build the server dropped).
Waypoints.BUILD_IDLE_SECONDS = 20
Waypoints.MAX_PER_UNIT = 16
-- Aircraft fly to their goal and arrive within the server's
-- Air.ARRIVE_RADIUS, or once the goal falls behind them after they flew
-- toward it, within Air.LOITER_RADIUS (a goal inside their turn circle:
-- the closest approach); then they circle it (S-38, C-51).
Waypoints.AIR_REACH = 40
Waypoints.AIR_PASS = 220

local CT = Schema.CmdType

export type Point = { kind: number, x: number, z: number, targetId: number?, reach: number, defIndex: number?, facing: number?, approached: boolean? }
export type Waypoints = { byUnit: { [number]: { Point } }, idleSince: { [number]: number } }

function Waypoints.new(): Waypoints
	return { byUnit = {}, idleSince = {} }
end

-- How close counts as there: the server spreads a group in a formation
-- around a point (Orders.lineSlots), about spacing × √n across; aircraft
-- arrive at AIR_REACH.
local function reachFor(world: World.World, ids: { number }): number
	local footprint, air = 1, false
	for _, id in ids do
		local u = world.units[id]
		local def = u and World.def(world, u)
		if def then
			footprint = math.max(footprint, def.footprint)
			air = air or def.domain == "air"
		end
	end
	local spacing = Formation.spacing(footprint * PlacementRules.RADIUS_PER_FOOTPRINT)
	return math.max(if air then Waypoints.AIR_REACH else Waypoints.REACHED, spacing * math.sqrt(#ids))
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
		and kind ~= CT.ATTACK_GROUND and kind ~= CT.GUARD and kind ~= CT.REPAIR and kind ~= CT.RECLAIM
		and kind ~= CT.BUILD then
		return -- state commands don't move anything
	end
	local slots = if intent.x2
		then Orders.lineSlots(world, ids, intent.x :: number, intent.z :: number, intent.x2, intent.z2 :: number)
		else nil
	local reach = if slots then Waypoints.REACHED
		elseif kind == CT.BUILD then 0 -- builders work from range: done when the frame starts, not on arrival
		else reachFor(world, ids)
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
		elseif intent.defIndex then
			point = { kind = kind, x = intent.x :: number, z = intent.z :: number, reach = reach, defIndex = intent.defIndex, facing = intent.facing }
		elseif slots then
			point = { kind = kind, x = slots[id][1], z = slots[id][2], reach = reach }
		else
			point = { kind = kind, x = intent.x :: number, z = intent.z :: number, reach = reach }
		end
		table.insert(list, point)
		wp.idleSince[id] = nil
	end
end

-- Is the queued build `p` finished from the client's point of view: an own
-- structure of that def stands on its spot (its frame has started), or
-- another structure took the spot (the server skips it)?
local function buildDone(world: World.World, p: Point): boolean
	local def = world.defs.unitByIndex[p.defIndex :: number]
	for _, s in world.units do
		local sdef = World.def(world, s)
		if sdef and sdef.domain == "structure" and math.abs(s.x - p.x) < 1 and math.abs(s.z - p.z) < 1 then
			-- ours of that def (started) or something else (blocked); not the
			-- extractor this build upgrades in place (C-121)
			if s.defIndex == p.defIndex or not Upgrades.canUpgrade(world, def, s) then
				return true
			end
		end
	end
	local r = Placement.check(world, def, p.x, p.z)
	return not r.ok and r.reason == "occupied" and r.replaces == 0
end

-- Is `u` putting up a frame: an own unfinished structure within its build range?
local function building(world: World.World, u: World.Unit): boolean
	local def = World.def(world, u)
	local range = (def and def.buildRange or 0) + 16
	for _, s in world.units do
		if s.team == u.team and s.build and s.build < 1 and (s.x - u.x) ^ 2 + (s.z - u.z) ^ 2 <= range * range then
			return true
		end
	end
	return false
end

-- Follows unit targets, drops reached points and started builds, units that
-- are gone, and units that have stood still for IDLE_SECONDS (builders with a
-- build next: BUILD_IDLE_SECONDS, and never while a frame goes up) (`now` in
-- seconds).
function Waypoints.update(wp: Waypoints, world: World.World, now: number)
	for id, list in wp.byUnit do
		local u = world.units[id]
		if u == nil then
			wp.byUnit[id] = nil
			wp.idleSince[id] = nil
			continue
		end
		local udef = World.def(world, u)
		if udef and udef.domain == "structure" and udef.buildOptions and #udef.buildOptions > 0 then
			continue -- a factory's orders for its new units: kept until replaced or stopped
		end
		-- queued builds anywhere in the list: done once their frame stands
		for i = #list, 1, -1 do
			local p = list[i]
			if p.kind == CT.BUILD and p.defIndex and buildDone(world, p) then
				table.remove(list, i)
			end
		end
		local head = list[1]
		local buildNext = head ~= nil and head.kind == CT.BUILD
		if not World.moving(world, u) and not (buildNext and building(world, u)) then
			local since = wp.idleSince[id]
			local limit = if buildNext then Waypoints.BUILD_IDLE_SECONDS else Waypoints.IDLE_SECONDS
			if since == nil then
				wp.idleSince[id] = now
			elseif now - since >= limit then
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
			local d2 = (first.x - x) ^ 2 + (first.z - z) ^ 2
			local passed = false
			local def = World.def(world, u)
			if def and def.domain == "air" then
				-- the server's arrival (S-38): the goal fell behind after it was ahead
				local ahead = math.sin(u.heading) * (first.x - x) + math.cos(u.heading) * (first.z - z) > 0
				if ahead then
					first.approached = true
				elseif first.approached and d2 <= Waypoints.AIR_PASS ^ 2 then
					passed = true
				end
			end
			if (d2 <= first.reach ^ 2 or passed) and first.kind ~= CT.PATROL then
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

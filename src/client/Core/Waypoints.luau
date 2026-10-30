--!strict
-- What each own unit was last ordered to do, from the commands this client
-- sent (order queues aren't replicated, net.md section 9): drawn as lines
-- for selected units (guide 15.6) and as translucent queued structures.
-- Lines stay until the order is done (C-193, the user: "unit with command
-- will have their command planned stayed until they finished all of the
-- command"): a point when its unit gets there (or stands stuck short of it
-- for STUCK_SECONDS: that one point goes); attack, guard (assist) and
-- reclaim until the target is gone; repair until it's whole; a queued build
-- until its frame is finished (C-23 dropped it when the frame started);
-- patrol until replaced; and everything once the server reports the builder
-- idle (IDLE events, S-136). A factory's orders are for the units it builds
-- (the sim's rally point, S-95): they stay until replaced or stopped
-- (C-109), and each unit it rolls out takes a copy, as the server gives it.
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
Waypoints.STUCK_SECONDS = 6 -- a unit standing still this long short of a point: that point is dropped
Waypoints.IDLE_GRACE = 1.5 -- seconds the server keeps reporting a builder idle before its lines go
Waypoints.ADOPT_REACH = 16 -- studs beyond a factory's footprint where its new units appear
Waypoints.MAX_PER_UNIT = 16
-- Aircraft fly to their goal and arrive within the server's
-- Air.ARRIVE_RADIUS, or once the goal falls behind them after they flew
-- toward it, within Air.LOITER_RADIUS (a goal inside their turn circle:
-- the closest approach); then they circle it (S-38, C-51).
Waypoints.AIR_REACH = 40
Waypoints.AIR_PASS = 220

local CT = Schema.CmdType

export type Point = { kind: number, x: number, z: number, targetId: number?, reach: number, defIndex: number?, facing: number?, approached: boolean?, radius: number? } -- radius: an AREA's circle (S-183)
export type Waypoints = {
	byUnit: { [number]: { Point } },
	idleSince: { [number]: number }, -- since when the server reports the unit idle
	stuckSince: { [number]: number }, -- since when it stands still short of its point
	seen: { [number]: boolean }?, -- units already known (a new one may come out of a factory)
}

function Waypoints.new(): Waypoints
	return { byUnit = {}, idleSince = {}, stuckSince = {}, seen = nil }
end

-- Forgets everything (a new WELCOME: unit IDs start over).
function Waypoints.reset(wp: Waypoints)
	table.clear(wp.byUnit)
	table.clear(wp.idleSince)
	table.clear(wp.stuckSince)
	wp.seen = nil
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
		and kind ~= CT.BUILD and kind ~= CT.AREA and kind ~= CT.LOAD and kind ~= CT.UNLOAD then
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
		if list == nil or not (intent.queue or intent.front) then
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
		elseif intent.areaOp then
			-- Smart Reclaim's circle (S-183): it lasts until the server reports the builder idle
			point = { kind = kind, x = intent.x :: number, z = intent.z :: number, reach = 0, radius = intent.radius }
		elseif slots then
			point = { kind = kind, x = slots[id][1], z = slots[id][2], reach = reach }
		else
			point = { kind = kind, x = intent.x :: number, z = intent.z :: number, reach = reach }
		end
		if intent.front then
			table.insert(list, 1, point) -- FRONT (S-199): first, the order under way after it
		else
			table.insert(list, point)
		end
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
		-- off camera a record has only its cell's centre (F13: the frame read
		-- as "something else took the spot", and the order was dropped)
		local tol = if s.tier == "tactical" then 1 else World.CELL_SLACK
		if sdef and sdef.domain == "structure" and math.abs(s.x - p.x) < tol and math.abs(s.z - p.z) < tol then
			-- ours of that def, finished (C-193: the line stays while it goes
			-- up), or something else (blocked); not the extractor this build
			-- upgrades in place (C-121)
			if s.defIndex == p.defIndex then
				return s.build == nil or s.build >= 1
			elseif not Upgrades.canUpgrade(world, def, s) then
				return true
			end
		end
	end
	local r = Placement.check(world, def, p.x, p.z)
	return not r.ok and r.reason == "occupied" and r.replaces == 0
end

-- Units new since the last frame that came out of an own factory with
-- orders take a copy of its list (the server gives each produced unit the
-- factory's order list, S-95). Units already there at the first frame
-- (the join) take nothing.
local function adopt(wp: Waypoints, world: World.World)
	local first = wp.seen == nil
	local seen: { [number]: boolean } = wp.seen or {}
	wp.seen = seen
	for id, u in world.units do
		if seen[id] then
			continue
		end
		seen[id] = true
		if first or u.team ~= world.me.team or wp.byUnit[id] ~= nil then
			continue
		end
		local def = World.def(world, u)
		if def == nil or def.domain == "structure" then
			continue
		end
		local best, bestD2 = nil, math.huge
		for fid, list in wp.byUnit do
			local f = world.units[fid]
			local fdef = f and World.def(world, f)
			if f and fdef and fdef.domain == "structure" and fdef.buildOptions and #fdef.buildOptions > 0 and #list > 0 then
				local reach = fdef.footprint * 8 / 2 + Waypoints.ADOPT_REACH
				local d2 = (f.x - u.x) ^ 2 + (f.z - u.z) ^ 2
				if d2 <= reach * reach and d2 < bestD2 then
					best, bestD2 = fid, d2
				end
			end
		end
		if best then
			local copy = {}
			for _, p in wp.byUnit[best] do
				table.insert(copy, table.clone(p))
			end
			wp.byUnit[id] = copy
		end
	end
	for id in seen do
		if world.units[id] == nil then
			seen[id] = nil
		end
	end
end

-- Follows unit targets and drops what's done (see the header) (`now` in seconds).
function Waypoints.update(wp: Waypoints, world: World.World, now: number)
	adopt(wp, world)
	for id, list in wp.byUnit do
		local u = world.units[id]
		if u == nil then
			wp.byUnit[id] = nil
			wp.idleSince[id] = nil
			wp.stuckSince[id] = nil
			continue
		end
		local udef = World.def(world, u)
		if udef and udef.domain == "structure" and udef.buildOptions and #udef.buildOptions > 0 then
			continue -- a factory's orders for its new units: kept until replaced or stopped
		end
		-- queued builds anywhere in the list: done once their frame is finished
		for i = #list, 1, -1 do
			local p = list[i]
			if p.kind == CT.BUILD and p.defIndex and buildDone(world, p) then
				table.remove(list, i)
			end
		end
		-- the server's word: a builder it keeps reporting idle has nothing left
		if world.idle[id] then
			local since = wp.idleSince[id]
			if since == nil then
				wp.idleSince[id] = now
			elseif now - since >= Waypoints.IDLE_GRACE then
				wp.byUnit[id] = nil
				wp.idleSince[id] = nil
				wp.stuckSince[id] = nil
				continue
			end
		else
			wp.idleSince[id] = nil
		end
		local first = list[1]
		while first do
			if first.targetId then
				local t = world.units[first.targetId]
				local healed = first.kind == CT.REPAIR and t ~= nil and t.build == nil and (t.health or 0) >= 0.999
				if t == nil or healed then
					table.remove(list, 1)
					first = list[1]
					continue
				end
				first.x, first.z = t.rx or t.x, t.rz or t.z
				break -- attack / guard / repair / reclaim last until the target is gone (or whole)
			end
			if first.kind == CT.BUILD or first.kind == CT.PATROL or first.kind == CT.AREA then
				break -- a build until its frame is finished; a patrol until replaced; an area until idle
			end
			if first.kind == CT.UNLOAD then
				-- until the cargo is down (S-219, C-273), not on arrival: the set-down takes a while there
				if u.cargo == nil or #u.cargo == 0 then
					table.remove(list, 1)
					first = list[1]
					continue
				end
				break
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
			if d2 <= first.reach ^ 2 or passed then
				table.remove(list, 1)
				first = list[1]
				wp.stuckSince[id] = nil
				continue
			end
			-- standing still short of it (blocked, or arrived spread out in a
			-- formation): that point goes after STUCK_SECONDS
			if World.moving(world, u) then
				wp.stuckSince[id] = nil
			else
				local since = wp.stuckSince[id]
				if since == nil then
					wp.stuckSince[id] = now
				elseif now - since >= Waypoints.STUCK_SECONDS then
					table.remove(list, 1)
					first = list[1]
					wp.stuckSince[id] = nil
					continue
				end
			end
			break
		end
		if #list == 0 then
			wp.byUnit[id] = nil
		end
	end
end

return Waypoints

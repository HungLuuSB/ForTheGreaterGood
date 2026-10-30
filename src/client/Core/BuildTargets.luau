--!strict
-- What each own builder is working on now, for its nano spray (C-193, the
-- user: "Add nano-spray to the build so I know what they are building").
-- Since protocol 39 the server says (WORK: Schema.WorkKind and the unit or
-- wreck, S-194; G7: the guess sprayed the previous structure while the
-- server built the next). Without it (older recordings) the target comes
-- from the builder's own order line (Core/Waypoints): its queued build's frame once
-- that frame stands, its repair or reclaim target, or, assisting another
-- builder (GUARD), what that builder works on. Only while the builder
-- stands still within reach (build range plus the target's half size), as
-- the server builds. Pure Luau (C-7).

local Schema = require("@shared/Net/Schema")
local World = require("./World")

local BuildTargets = {}

local CT = Schema.CmdType

BuildTargets.SLACK = 8 -- studs past the build range still counted as in reach

-- The own unfinished structure of `defIndex` standing on (x, z), or nil.
local function frameAt(world: World.World, defIndex: number, x: number, z: number): number?
	for id, s in world.units do
		local tol = if s.tier == "tactical" then 1 else World.CELL_SLACK -- off camera: the cell's centre (F13)
		if s.defIndex == defIndex and s.team == world.me.team and math.abs(s.x - x) < tol and math.abs(s.z - z) < tol then
			return id
		end
	end
	return nil
end

-- The unit builder `id`'s first order points at (frame, repair or reclaim
-- target), before the reach check; `depth` limits following assists.
local function aimOf(world: World.World, byUnit: { [number]: { any } }, id: number, depth: number): (number?, string?)
	local list = byUnit[id]
	local p = list and list[1]
	if p == nil then
		return nil, nil
	end
	if p.kind == CT.BUILD and p.defIndex then
		return frameAt(world, p.defIndex, p.x, p.z), "build"
	elseif p.kind == CT.REPAIR and p.targetId then
		return p.targetId, "build"
	elseif p.kind == CT.RECLAIM and p.targetId then
		return p.targetId, "reclaim"
	elseif p.kind == CT.GUARD and p.targetId and depth > 0 then
		-- assisting: what the lead works on (or the lead's frame, when the lead is a frame)
		local lead = world.units[p.targetId]
		if lead and lead.build and lead.build < 1 then
			return p.targetId, "build"
		end
		return aimOf(world, byUnit, p.targetId, depth - 1)
	end
	return nil, nil
end

export type Spray = { builder: number, target: number, kind: string, wreck: boolean? } -- wreck: `target` is a wreck ID (reclaim, resurrect)

local WK = Schema.WorkKind

-- The server's word: the unit or wreck builder `u` works on, or nil.
local function served(world: World.World, u: World.Unit, depth: number): (number?, string?, boolean?)
	local kind, target = u.workKind, u.workTarget
	if kind == nil or kind == WK.NONE or target == nil then
		return nil, nil, nil
	end
	if kind == WK.RECLAIM or kind == WK.RESURRECT then
		if world.wrecks[target] == nil then
			return nil, nil, nil
		end
		return target, if kind == WK.RECLAIM then "reclaim" else "resurrect", true
	end
	local t = world.units[target]
	if t == nil then
		return nil, nil, nil
	end
	if kind == WK.ASSIST and not (t.build and t.build < 1) and depth > 0 then
		-- assisting a builder: what that builder works on
		return served(world, t, depth - 1)
	end
	if kind == WK.RECLAIM_UNIT then
		return target, "reclaim", false -- a construction turret taking a live enemy apart (protocol 42, S-218)
	end
	return target, "build", false
end

-- Every own builder spraying now: builder → its target and kind ("build"
-- or "reclaim").
function BuildTargets.list(world: World.World, byUnit: { [number]: { any } }, out: { Spray }): { Spray }
	table.clear(out)
	for id, u in world.units do
		if u.team ~= world.me.team then
			continue
		end
		if u.workKind ~= nil then
			local target, kind, wreck = served(world, u, 2)
			if target and kind then
				table.insert(out, { builder = id, target = target, kind = kind, wreck = wreck })
			end
			continue
		end
		if byUnit[id] == nil then
			continue
		end
		local def = World.def(world, u)
		if def == nil or (def.buildPower or 0) <= 0 or World.moving(world, u) then
			continue
		end
		local target, kind = aimOf(world, byUnit, id, 2)
		local t = target and world.units[target]
		if t == nil or kind == nil then
			continue
		end
		local tdef = World.def(world, t)
		local reach = (def.buildRange or 0) + ((tdef and tdef.footprint) or 1) * 4 + BuildTargets.SLACK
		local ux, uz, tx, tz = u.rx or u.x, u.rz or u.z, t.rx or t.x, t.rz or t.z
		if (ux - tx) ^ 2 + (uz - tz) ^ 2 <= reach * reach then
			table.insert(out, { builder = id, target = target :: number, kind = kind })
		end
	end
	return out
end

return BuildTargets

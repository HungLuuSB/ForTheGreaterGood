--!strict
-- What each own builder is working on now, for its nano spray (C-193, the
-- user: "Add nano-spray to the build so I know what they are building").
-- The server doesn't send a builder's target, so it comes from the
-- builder's own order line (Core/Waypoints): its queued build's frame once
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
		if s.defIndex == defIndex and s.team == world.me.team and math.abs(s.x - x) < 1 and math.abs(s.z - z) < 1 then
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

export type Spray = { builder: number, target: number, kind: string }

-- Every own builder spraying now: builder → its target and kind ("build"
-- or "reclaim").
function BuildTargets.list(world: World.World, byUnit: { [number]: { any } }, out: { Spray }): { Spray }
	table.clear(out)
	for id, u in world.units do
		if u.team ~= world.me.team or byUnit[id] == nil then
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

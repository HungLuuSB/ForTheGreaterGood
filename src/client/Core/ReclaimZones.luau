--!strict
-- Reclaim zones (C-216, S-168): with only workers selected, the known
-- wrecks grouped into fields (two wrecks within LINK studs share one), each
-- with its centre (weighted by supply), a radius that holds every wreck in
-- it, and the supply left in all of them. Also the wreck nearest a ground
-- point, for the hover label. Pure Luau (C-7); Render/WreckInfo draws them.

local World = require("./World")

local ReclaimZones = {}

ReclaimZones.LINK = 80 -- studs: wrecks this close fall in one zone
ReclaimZones.PAD = 16 -- studs added round the farthest wreck
ReclaimZones.HOVER = 24 -- studs: the hover names the wreck within this of the point

export type Zone = { x: number, z: number, r: number, supply: number, count: number }

-- True when the selection is own units and every one is a mobile builder.
function ReclaimZones.workersOnly(world: World.World, selection: { number }): boolean
	if #selection == 0 then
		return false
	end
	for _, id in selection do
		local u = world.units[id]
		local def = u and World.def(world, u) :: any
		if def == nil or u.team ~= world.me.team or def.domain == "structure" or def.buildPower == nil then
			return false
		end
	end
	return true
end

-- The zones of the known wrecks with supply left, largest supply first.
function ReclaimZones.of(world: World.World): { Zone }
	local ids = {}
	for id, w in world.wrecks do
		if w.supply > 0 and w.feature == nil then -- (map features aren't zoned: trees and rocks would ring the whole map, S-197)
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	-- single-link grouping (union-find over pairs within LINK)
	local parent: { [number]: number } = {}
	local function find(i: number): number
		while parent[i] ~= i do
			parent[i] = parent[parent[i]]
			i = parent[i]
		end
		return i
	end
	for _, id in ids do
		parent[id] = id
	end
	local link2 = ReclaimZones.LINK ^ 2
	for i = 1, #ids do
		local a = world.wrecks[ids[i]]
		for j = i + 1, #ids do
			local b = world.wrecks[ids[j]]
			if (a.x - b.x) ^ 2 + (a.z - b.z) ^ 2 <= link2 then
				parent[find(ids[j])] = find(ids[i])
			end
		end
	end
	local groups: { [number]: { number } } = {}
	local roots = {}
	for _, id in ids do
		local r = find(id)
		if groups[r] == nil then
			groups[r] = {}
			table.insert(roots, r)
		end
		table.insert(groups[r], id)
	end
	local out: { Zone } = {}
	for _, r in roots do
		local members = groups[r]
		local supply, sx, sz = 0, 0, 0
		for _, id in members do
			local w = world.wrecks[id]
			supply += w.supply
			sx += w.x * w.supply
			sz += w.z * w.supply
		end
		local cx, cz = sx / supply, sz / supply
		local reach = 0
		for _, id in members do
			local w = world.wrecks[id]
			reach = math.max(reach, math.sqrt((w.x - cx) ^ 2 + (w.z - cz) ^ 2))
		end
		table.insert(out, { x = cx, z = cz, r = reach + ReclaimZones.PAD, supply = supply, count = #members })
	end
	table.sort(out, function(a, b)
		return a.supply > b.supply
	end)
	return out
end

-- The known wreck nearest (x, z) within HOVER studs, or nil.
function ReclaimZones.wreckAt(world: World.World, x: number, z: number): World.Wreck?
	local best, bestD2 = nil, ReclaimZones.HOVER ^ 2
	for _, w in world.wrecks do
		local d2 = (w.x - x) ^ 2 + (w.z - z) ^ 2
		if d2 < bestD2 then
			best, bestD2 = w, d2
		end
	end
	return best
end

-- The hover text for wreck `w`: "<unit name> wreck · 45 supply", with the
-- resurrect progress when it has some.
function ReclaimZones.label(world: World.World, w: World.Wreck): string
	local def = world.defs.unitByIndex[w.defIndex]
	local name = if def then def.name else "Unknown"
	local text = `{name} wreck · {w.supply} supply`
	if w.rez > 0 then
		text ..= ` · resurrect {math.floor(w.rez * 100)}%`
	end
	return text
end

return ReclaimZones

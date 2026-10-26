--!strict
-- Extractor upgrades in place (guide 9.3; the user's brief, C-121): a T2
-- extractor may be built onto the player's own finished T1. The sim's rule
-- (S-108): the new def lists the old in `upgradesFrom`; the T1 keeps
-- producing under the frame and leaves when the T2 finishes. Until S-108 is
-- in, the older rule (D92: an extractor with a lower rate) applies. This
-- finds the targets for the build ghost (highlight, snap), for extractor
-- drags and for the "Upgrade extractors" area command (every target in a
-- circle, nearest first). Core/Placement applies the same rule to the
-- ghost; the server checks again (Sim/Placement). Pure Luau (C-7).

local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")
local PlacementRules = require("@shared/Grid/PlacementRules")
local World = require("./World")

local Upgrades = {}

Upgrades.SNAP = 16 -- studs: an extractor ghost this close to an upgradable extractor jumps onto it
Upgrades.TOOLTIP = "Upgrades a T1 extractor in place"

-- Does `def` replace `old` in place: listed in its `upgradesFrom` (S-108),
-- or, for defs without one, an extractor with a lower rate (D92).
function Upgrades.replaces(def: any, old: any): boolean
	if def.upgradesFrom ~= nil then
		return table.find(def.upgradesFrom, old.id) ~= nil
	end
	return def.extractor ~= nil and old.extractor ~= nil and old.extractor.rate < def.extractor.rate and old.faction == def.faction
end

-- Can `def` upgrade unit `u` in place: the player's own (the client's own
-- units are its team's), finished, and replaced by `def`.
function Upgrades.canUpgrade(world: World.World, def: any, u: any): boolean
	if (def.extractor == nil and def.upgradesFrom == nil) or u == nil or u.team ~= world.me.team or (u.build or 0) < 1 then
		return false
	end
	local udef = World.def(world, u)
	return udef ~= nil and Upgrades.replaces(def, udef)
end

-- Where `def` goes to upgrade unit `id`: centred on the deposit patch
-- under it (S-184: the advanced extractor's footprint 4 around the T1 on
-- its 2 x 2 patch), the old unit's centre when no patch is known under it.
function Upgrades.site(world: World.World, def: any, id: number): (number, number)
	local u = world.units[id]
	local udef = World.def(world, u)
	local layers = world.layers
	if udef == nil or layers == nil then
		return u.x, u.z
	end
	local px, pz = PlacementRules.depositNear(layers, u.x, u.z, udef.footprint * Grid.CELL_SIZE / 2 + 1)
	if px == nil or pz == nil then
		return u.x, u.z
	end
	return px, pz
end

-- Every extractor `def` can upgrade, by id.
function Upgrades.targets(world: World.World, def: any): { number }
	local out = {}
	for id, u in world.units do
		if Upgrades.canUpgrade(world, def, u) then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- The upgradable extractor nearest (x, z) within `reach` studs, or nil.
function Upgrades.nearest(world: World.World, def: any, x: number, z: number, reach: number): number?
	local best, bestD = nil, reach * reach
	for _, id in Upgrades.targets(world, def) do
		local u = world.units[id]
		local d = (u.x - x) ^ 2 + (u.z - z) ^ 2
		if d <= bestD then
			best, bestD = id, d
		end
	end
	return best
end

-- The upgradable extractors within `radius` of (cx, cz), in visiting order:
-- the nearest to (fromX, fromZ) first, then each next one nearest to the
-- last (BAR's area extractor order).
function Upgrades.inCircle(world: World.World, def: any, cx: number, cz: number, radius: number, fromX: number, fromZ: number): { number }
	local left = {}
	for _, id in Upgrades.targets(world, def) do
		local u = world.units[id]
		if (u.x - cx) ^ 2 + (u.z - cz) ^ 2 <= radius * radius then
			table.insert(left, id)
		end
	end
	local out = {}
	local x, z = fromX, fromZ
	while #left > 0 do
		local bi, bd = 1, math.huge
		for i, id in left do
			local u = world.units[id]
			local d = (u.x - x) ^ 2 + (u.z - z) ^ 2
			if d < bd then
				bi, bd = i, d
			end
		end
		local id = table.remove(left, bi) :: number
		table.insert(out, id)
		x, z = world.units[id].x, world.units[id].z
	end
	return out
end

-- Does `def` upgrade another structure in place (the tooltip's line)?
-- `defs`: Defs.load()'s set.
function Upgrades.isUpgrade(defs: any, def: any): boolean
	if def.upgradesFrom ~= nil then
		return #def.upgradesFrom > 0
	end
	if def.extractor == nil then
		return false
	end
	for _, other in defs.unitByIndex do
		if other ~= def and Upgrades.replaces(def, other) then
			return true
		end
	end
	return false
end

-- The extractor the selected builders' upgrades use: the highest-rate
-- upgrading extractor in any of their build options (`builderDefs`: the
-- selected units' defs), or nil when none can upgrade.
function Upgrades.upgraderFor(defs: any, builderDefs: { any }): any?
	local best = nil
	for _, bdef in builderDefs do
		for _, optionId in bdef.buildOptions or {} do
			local def = defs.units[optionId]
			if def and def.extractor and Upgrades.isUpgrade(defs, def) and (best == nil or def.extractor.rate > best.extractor.rate) then
				best = def
			end
		end
	end
	return best
end

return Upgrades

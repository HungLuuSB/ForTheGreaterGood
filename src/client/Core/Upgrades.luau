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

-- Where `def` goes to upgrade unit `id`: on the deposit under it (S-108:
-- the BUILD at the deposit cell, so a bigger footprint covers the old one),
-- as the point the snap turns into that spot (an odd footprint's center is
-- the cell's center, an even one's its min corner). The old unit's center
-- when no deposit is known under it.
function Upgrades.site(world: World.World, def: any, id: number): (number, number)
	local u = world.units[id]
	local udef = World.def(world, u)
	local layers = world.layers
	if udef == nil or layers == nil then
		return u.x, u.z
	end
	local g = world.grid
	local x0, z0 = PlacementRules.snap(g, udef.footprint, u.x, u.z)
	local best, bestD = nil, math.huge
	for cz = z0, z0 + udef.footprint - 1 do
		for cx = x0, x0 + udef.footprint - 1 do
			if g:inBounds(cx, cz) and Layers.getSupply(layers, g:index(cx, cz)) > 0 then
				local wx, wz = g:cellCenter(cx, cz)
				local d = (wx - u.x) ^ 2 + (wz - u.z) ^ 2
				if d < bestD then
					best, bestD = { cx, cz, wx, wz }, d
				end
			end
		end
	end
	if best == nil then
		return u.x, u.z
	end
	if def.footprint % 2 == 1 then
		return best[3], best[4]
	end
	return g.originX + best[1] * Grid.CELL_SIZE, g.originZ + best[2] * Grid.CELL_SIZE
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

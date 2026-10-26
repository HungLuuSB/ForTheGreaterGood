--!strict
-- Map features in the match (S-197): the map's trees and rocks
-- (Layers.features, Defs/Features) become reclaimable features when the sim
-- starts. They live with the wrecks (Combat.addFeature: wreckKind, the
-- amount in wreckSupply, wreckDef 0), so reclaim orders, Smart Reclaim and
-- the wire handle them like wrecks; they are never resurrected. Reclaiming a
-- tree pays power (Build), a rock supply. A rock occupies its cell
-- (Passability.ROCK: no ground or naval unit enters, nothing is built there)
-- until it is reclaimed.

local FeatureDefs = require("@shared/Defs/Features")
local Passability = require("@shared/Grid/Passability")
local Combat = require("./Combat/Combat")
local Nav = require("./Nav")
local Types = require("./Types")

local Features = {}

-- Places the map's features (Sim.new, once).
function Features.spawn(sim: Types.Sim)
	local pm = sim.map :: Passability.PassMap?
	local layers = pm and pm.layers
	local list = layers and layers.features
	if pm == nil or list == nil then
		return
	end
	local g = pm.grid
	-- each one turned its own way (the golden angle steps through every
	-- heading evenly), so clients draw a varied forest without any RNG
	local GOLDEN = math.pi * (3 - math.sqrt(5))
	for k, f in ipairs(list) do
		local heading = (k * GOLDEN) % (2 * math.pi) - math.pi
		local kind = FeatureDefs.KINDS[f.kind]
		assert(kind, `Features: unknown kind {f.kind}`)
		local cx, cz = g:cellAt(f.x, f.z)
		if not g:inBounds(cx, cz) then
			continue
		end
		if kind.blocks then
			-- centred on its cell; a cell holds one rock
			local i = g:index(cx, cz)
			if Passability.occupant(pm, i) ~= 0 then
				continue
			end
			local x, z = g:cellCenter(cx, cz)
			Combat.addFeature(sim.combat, x, z, kind.id, f.value or kind.value, heading)
			Passability.setOccupied(pm, cx, cz, 1, Passability.ROCK)
		else
			Combat.addFeature(sim.combat, f.x, f.z, kind.id, f.value or kind.value, heading)
		end
	end
	if sim.nav then
		Nav.terrainChanged(sim.nav, 0, 0, g.cellsX - 1, g.cellsZ - 1)
	end
end

-- Feature `wid` is gone (reclaimed): a rock frees its cell.
function Features.cleared(sim: Types.Sim, wid: number)
	local c = sim.combat
	local kind = FeatureDefs.BY_ID[c.wreckKind[wid] or 0]
	local pm = sim.map :: Passability.PassMap?
	if kind == nil or not kind.blocks or pm == nil then
		return
	end
	local cx, cz = pm.grid:cellAt(c.wreckX[wid], c.wreckZ[wid])
	Passability.clearOccupied(pm, cx, cz, 1, Passability.ROCK)
	if sim.nav then
		Nav.terrainChanged(sim.nav, cx, cz, cx, cz)
	end
end

-- The account a feature's (or wreck's) reclaim pays into.
function Features.resource(sim: Types.Sim, wid: number): "supply" | "power"
	local kind = FeatureDefs.BY_ID[sim.combat.wreckKind[wid] or 0]
	return if kind then kind.resource else "supply"
end

return Features

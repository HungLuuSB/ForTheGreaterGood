--!strict
-- The one place units enter and leave the simulation, so every subsystem
-- that keeps per-unit state (economy producers, move orders, construction,
-- structure footprints) is updated together.

local Economy = require("./Economy")
local Nav = require("./Nav")
local Types = require("./Types")
local World = require("./World")

local Lifecycle = {}

-- Called right after World.spawn. Complete units with production/storage
-- start producing at once (the Command Vehicle); structures register when
-- construction completes.
function Lifecycle.added(sim: Types.Sim, id: number)
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	if Economy.isProducerDef(def) and sim.world.buildProgress[id] >= 1 then
		Economy.addProducer(sim.eco, id)
	end
end

-- A structure (or factory-built unit) finished construction.
function Lifecycle.completed(sim: Types.Sim, id: number)
	local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
	if Economy.isProducerDef(def) then
		Economy.addProducer(sim.eco, id)
	end
end

-- Extra cleanup steps registered by modules that keep per-unit state and
-- sit above this one in the require graph (construction, placement).
-- Run in registration order, which is fixed by Sim's require order.
Lifecycle.removalHooks = {} :: { (Types.Sim, number) -> () }

-- Removes a unit from every subsystem, then from the world.
function Lifecycle.remove(sim: Types.Sim, id: number)
	Economy.removeProducer(sim.eco, id)
	if sim.nav then
		Nav.clearOrder(sim.nav, sim.world, id)
	end
	for _, hook in Lifecycle.removalHooks do
		hook(sim, id)
	end
	World.despawn(sim.world, sim.tick, id)
end

return Lifecycle

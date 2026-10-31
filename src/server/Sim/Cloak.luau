--!strict
-- Cloak (S-228, the BAR roster program's batch 1; BAR's cloakCost and
-- mincloakdistance). A unit whose def has `cloak` is cloaked while it is
-- finished, switched on (TOGGLE; it starts on), fully powered (its drain is
-- a Sensors drain), hasn't fired for FIRE_QUIET_SECONDS and no enemy stands
-- within its `decloak` radius. Cloaked (the CLOAKED state bit), enemy sight
-- can't see it: only radar (Sensors.levelFor), so it shows as a blip unless
-- it is stealthy too.
local ContactGrid = require("./Combat/ContactGrid")
local Lifecycle = require("./Lifecycle")
local Types = require("./Types")
local World = require("./World")

local Cloak = {}

Cloak.FIRE_QUIET_SECONDS = 2 -- after a shot, it stays visible this long
Cloak.EVERY = 2 -- ticks between re-checks: the Sensors rate

local CLOAKED = World.State.CLOAKED
local TOGGLED_ON = World.State.TOGGLED_ON

export type State = {
	firedAt: { [number]: number }, -- cloaking unit → tick it last fired
}

function Cloak.new(): State
	return { firedAt = {} }
end

local scratch: { number } = {}

-- One tick: note this tick's shots by cloaking units; every EVERY ticks,
-- set each cloaking unit's CLOAKED bit.
function Cloak.step(sim: Types.Sim)
	local w = sim.world
	local unitByIndex = sim.defs.unitByIndex
	local firedAt = sim.cloak.firedAt
	for _, e in sim.combat.events do
		if (e.kind == "FIRE" or e.kind == "SPAWN_PROJ") and e.unit ~= 0 and w.slot[e.unit] and unitByIndex[w.defIndex[e.unit]].cloak then
			firedAt[e.unit] = sim.tick
		end
	end
	if sim.tick % Cloak.EVERY ~= 0 then
		return
	end
	local quiet = sim.tick - Cloak.FIRE_QUIET_SECONDS * 15
	local powerScale = sim.sensors.powerScale
	local contacts = sim.combat.contacts
	for _, id in w.ids do
		local cloak = unitByIndex[w.defIndex[id]].cloak
		if cloak == nil then
			continue
		end
		local state = w.state[id]
		local on = bit32.band(state, TOGGLED_ON) ~= 0
			and w.buildProgress[id] >= 1
			and (powerScale[id] or 1) >= 0.999
			and (firedAt[id] or -math.huge) <= quiet
			and not World.isParalyzed(w, id)
		if on and ContactGrid.query(contacts, w, w.posX[id], w.posZ[id], cloak.decloak, w.ally[id], scratch) > 0 then
			on = false -- an enemy close by
		end
		local want = if on then bit32.bor(state, CLOAKED) else bit32.band(state, bit32.bnot(CLOAKED))
		if want ~= state then
			World.setState(w, id, want)
		end
	end
end

-- Is unit `id` cloaked from its enemies?
function Cloak.isCloaked(w: World.World, id: number): boolean
	return bit32.band(w.state[id] or 0, CLOAKED) ~= 0
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	sim.cloak.firedAt[id] = nil
end)

return Cloak

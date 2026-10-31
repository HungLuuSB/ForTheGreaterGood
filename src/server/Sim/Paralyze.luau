--!strict
-- EMP (S-229, the BAR roster program's batch 1; BAR's paralyzer). A
-- paralyzer weapon's damage fills the target's stun bar (World.paralyze)
-- instead of taking health. While the bar is above the unit's max health it
-- is stunned (the PARALYZED state bit): it neither moves, fires nor builds,
-- and a cloak drops. The bar drains a tenth of max health a second, and a
-- hit tops it up to at most max health × (1 + its seconds / DRAIN_SECONDS),
-- so a stun lasts at most the weapon's seconds after the last hit.
local Types = require("./Types")
local World = require("./World")

local Paralyze = {}

Paralyze.DRAIN_SECONDS = 10 -- a full bar drains in this long
Paralyze.EVERY = 3 -- ticks between drains (0.2 s)

local PARALYZED = World.State.PARALYZED

local function setStunned(w: World.World, id: number, stunned: boolean)
	local state = w.state[id]
	local want = if stunned then bit32.bor(state, PARALYZED) else bit32.band(state, bit32.bnot(PARALYZED))
	if want ~= state then
		World.setState(w, id, want)
	end
end

-- EMP `amount` on unit `id`, from a weapon that stuns for `seconds` (Damage).
function Paralyze.add(sim: Types.Sim, id: number, amount: number, seconds: number)
	local w = sim.world
	local max = sim.defs.unitByIndex[w.defIndex[id]].health
	local cap = max * (1 + seconds / Paralyze.DRAIN_SECONDS)
	local bar = w.paralyze[id] or 0
	if bar >= cap then
		return
	end
	bar = math.min(cap, bar + amount)
	w.paralyze[id] = bar
	if bar > max then
		setStunned(w, id, true)
	end
end

function Paralyze.step(sim: Types.Sim)
	local w = sim.world
	local unitByIndex = sim.defs.unitByIndex
	local dt = Paralyze.EVERY / 15
	for _, id in w.ids do
		local bar = w.paralyze[id]
		if bar == nil then
			continue
		end
		local max = unitByIndex[w.defIndex[id]].health
		bar -= max / Paralyze.DRAIN_SECONDS * dt
		if bar <= 0 then
			w.paralyze[id] = nil
			setStunned(w, id, false)
		else
			w.paralyze[id] = bar
			setStunned(w, id, bar > max)
		end
	end
end

return Paralyze

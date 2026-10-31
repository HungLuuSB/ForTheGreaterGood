--!strict
-- Idle autoheal (S-226, the user: "idle auto heal is important, add it";
-- BAR's idleautoheal). A finished unit or structure that has taken no
-- damage for DELAY_SECONDS heals RATE of its max health a second, up to
-- full. Any damage, from anyone, restarts the wait. It runs once a second
-- (Sim.AutoHeal, every TICK_RATE ticks), so health moves in 1% steps.
local Lifecycle = require("./Lifecycle")
local Types = require("./Types")
local World = require("./World")

local AutoHeal = {}

AutoHeal.DELAY_SECONDS = 10
AutoHeal.RATE = 0.01 -- of max health, a second
AutoHeal.EVERY = 15 -- ticks (Sim.TICK_RATE): once a second

export type State = {
	hitAt: { [number]: number }, -- unit → tick it last took damage
	off: boolean?, -- no autoheal: tests that set health by hand and check it holds
}

function AutoHeal.new(): State
	return { hitAt = {} }
end

-- Unit `id` took damage this tick (Damage).
function AutoHeal.damaged(sim: Types.Sim, id: number)
	sim.autoheal.hitAt[id] = sim.tick
end

function AutoHeal.step(sim: Types.Sim)
	if sim.autoheal.off then
		return
	end
	local w = sim.world
	local hitAt = sim.autoheal.hitAt
	local unitByIndex = sim.defs.unitByIndex
	local quiet = sim.tick - AutoHeal.DELAY_SECONDS * AutoHeal.EVERY
	for _, id in w.ids do
		local health = w.health[id]
		if health <= 0 or w.buildProgress[id] < 1 then
			continue
		end
		local at = hitAt[id]
		if at ~= nil and at > quiet then
			continue
		end
		local max = unitByIndex[w.defIndex[id]].health
		if health < max then
			World.setHealth(w, id, math.min(max, health + max * AutoHeal.RATE))
		end
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	sim.autoheal.hitAt[id] = nil
end)

return AutoHeal

--!strict
-- Self-destruct (S-194, the user's G13): a player's SELF_DESTRUCT command
-- starts a unit's countdown (Schema.SELF_DESTRUCT_SECONDS); a second command
-- with value 0 stops it. When it runs out the unit dies at once, leaves no
-- wreck, and its death blast is bigger than a normal death's: damage and
-- radius × (1 + BLAST_PER_TIER × tier), so a T3 unit's is 1.75 times. A
-- frame still under construction just goes (no blast, like any frame).

local Schema = require("@shared/Net/Schema")
local Combat = require("./Combat/Combat")
local Lifecycle = require("./Lifecycle")
local Types = require("./Types")

local SelfDestruct = {}

SelfDestruct.TICKS = Schema.SELF_DESTRUCT_SECONDS * 15
SelfDestruct.BLAST_PER_TIER = 0.25

-- Starts (`on`) or stops unit `id`'s countdown.
function SelfDestruct.set(sim: Types.Sim, id: number, on: boolean)
	local c = sim.combat
	if on then
		if c.selfDestruct[id] == nil then
			c.selfDestruct[id] = sim.tick + SelfDestruct.TICKS
		end
	else
		c.selfDestruct[id] = nil
	end
end

-- Whole seconds left of unit `id`'s countdown (1 in its last second), or nil.
function SelfDestruct.secondsLeft(sim: Types.Sim, id: number): number?
	local at = sim.combat.selfDestruct[id]
	if at == nil then
		return nil
	end
	return math.max(1, math.ceil((at - sim.tick) / 15))
end

-- The blast multiplier for a self-destructing def.
function SelfDestruct.blastScale(def: any): number
	return 1 + SelfDestruct.BLAST_PER_TIER * (def.tier or 1)
end

-- Before Damage applies this tick's queue: units whose countdown ran out are
-- killed (in unit ID order, so it's deterministic).
function SelfDestruct.step(sim: Types.Sim)
	local c = sim.combat
	table.clear(c.selfDestructed)
	if next(c.selfDestruct) == nil then
		return
	end
	local due = {}
	for id, at in c.selfDestruct do
		if at <= sim.tick then
			table.insert(due, id)
		end
	end
	table.sort(due)
	local w = sim.world
	for _, id in due do
		c.selfDestruct[id] = nil
		if w.slot[id] ~= nil then
			c.selfDestructed[id] = true
			sim.cheats.killing[id] = true -- (through god mode too)
			Combat.queueDamage(c, id, w.health[id] * 100 + 1, 0, w.owner[id]) -- (past any armour; no wreck either way)
		end
	end
end

table.insert(Lifecycle.removalHooks, function(sim: Types.Sim, id: number)
	sim.combat.selfDestruct[id] = nil
end)

return SelfDestruct

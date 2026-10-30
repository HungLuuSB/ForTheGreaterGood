--!strict
-- The skirmish AI's counters (S-223, after BAR's CircuitAI: it answers the
-- enemy's army by spending share, with a cap per role). Data, not code:
-- what the AI sees the enemy spend on, as shares of its known armed value,
-- asks for a share of the AI's production in the roles that answer it.
--
-- Enemy classes (`classOf`): armed units and structures its team has
-- identified (D107), by value (supply + power / 10, S-92).
-- Roles: what a factory can answer with (Skirmish picks the units).

local Categories = require("@shared/Defs/Categories")
local Defs = require("@shared/Defs/Defs")

local Counters = {}

local BIT = Categories.Bit

Counters.CLASSES = table.freeze({ "light", "armored", "artillery", "defense", "air", "naval" })
Counters.ROLES = table.freeze({ "heavy", "artillery", "raider", "antiair" })

-- enemy class → { role → production share asked per unit of that class's
-- share of the enemy's value }
Counters.RESPONSE = table.freeze({
	light = table.freeze({ heavy = 0.6 }), -- heavy armour shrugs off light guns
	armored = table.freeze({ artillery = 0.3, heavy = 0.3 }),
	artillery = table.freeze({ raider = 0.6 }), -- fast units dive the guns (was: 3+ known, S-187)
	defense = table.freeze({ artillery = 0.8 }), -- outrange the turrets (was: 3+ known, S-187)
	air = table.freeze({ antiair = 0.5 }),
	naval = table.freeze({}),
})

-- the most of a factory's production one role may take
Counters.CAPS = table.freeze({ heavy = 0.7, artillery = 0.5, raider = 0.4, antiair = 0.35 })

-- a class seen and lost from sight is remembered at half its value after this long
Counters.HALF_LIFE = 3 * 60 * 15 -- ticks

-- An armed def's class; nil for unarmed ones (workers, radar, economy).
function Counters.classOf(d: Defs.UnitDef): string?
	if #d.weapons == 0 then
		return nil
	end
	if d.domain == "structure" then
		return "defense"
	elseif d.domain == "air" then
		return "air"
	elseif d.domain == "naval" then
		return "naval"
	elseif bit32.band(d.categoryMask, BIT.COMMANDER) ~= 0 then
		return nil
	elseif bit32.band(d.categoryMask, BIT.ARTILLERY) ~= 0 then
		return "artillery"
	elseif bit32.band(d.categoryMask, BIT.LIGHT) ~= 0 then
		return "light"
	end
	return "armored"
end

-- The production share each role asks for, from the enemy's value per class.
function Counters.demand(mix: { [string]: number }): { [string]: number }
	local total = 0
	for _, k in Counters.CLASSES do
		total += mix[k] or 0
	end
	local out: { [string]: number } = {}
	for _, r in Counters.ROLES do
		out[r] = 0
	end
	if total <= 0 then
		return out
	end
	for _, k in Counters.CLASSES do
		local share = (mix[k] or 0) / total
		for r, wgt in Counters.RESPONSE[k] do
			out[r] += share * wgt
		end
	end
	for _, r in Counters.ROLES do
		out[r] = math.min(out[r], Counters.CAPS[r])
	end
	return out
end

return table.freeze(Counters)

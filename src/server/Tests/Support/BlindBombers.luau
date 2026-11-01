--!strict
-- Bombers that can't see their target before they release. Since S-234
-- slowed them, a bomb's lead falls inside the bomber's own sight, so the
-- tests of bombing what a team only remembers, sees on radar or tracks blind
-- the Absolution and the Plague (sight 40). `BlindBombers.load()` builds that
-- def set once; pass it as Sim.new's `defs`.
local Defs = require("@shared/Defs/Defs")

local BlindBombers = {}

local built: Defs.DefSet? = nil
function BlindBombers.load(): Defs.DefSet
	if built == nil then
		local registry = require("@shared/Defs/Registry") :: any
		local units = table.clone(registry.units)
		for _, id in { "ord_absolution", "chs_plague" } do
			local d = table.clone(units[id])
			d.sensors = table.clone(d.sensors)
			d.sensors.sight = 40
			units[id] = d
		end
		local copy = table.clone(registry)
		copy.units = units
		built = Defs.build(copy)
	end
	return built :: Defs.DefSet
end

return BlindBombers

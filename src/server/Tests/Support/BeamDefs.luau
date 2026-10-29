--!strict
-- The beam towers at their ranges before S-203 (the user's H7 shortened
-- Radiance's beam to 488 and Bulwark's to 384): the beam mechanism's tests
-- (Defenses, Shield) were laid out for those distances and test the beam,
-- not its reach. `BeamDefs.load()` builds that def set once; pass it as
-- Sim.new's `defs`.
local Defs = require("@shared/Defs/Defs")

local BeamDefs = {}

local RANGE = {
	ord_radiance_beam = 650,
	chs_bulwark_beam = 480,
}

local built: Defs.DefSet? = nil
function BeamDefs.load(): Defs.DefSet
	if built == nil then
		local registry = require("@shared/Defs/Registry") :: any
		local weapons = table.clone(registry.weapons)
		for id, range in RANGE do
			local wd = table.clone(weapons[id])
			wd.range = range
			weapons[id] = wd
		end
		local copy = table.clone(registry)
		copy.weapons = weapons
		built = Defs.build(copy)
	end
	return built :: Defs.DefSet
end

return BeamDefs

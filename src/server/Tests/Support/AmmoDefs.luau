--!strict
-- The aircraft as they were before S-194 (the user's G17 took their ammo
-- away): ammo, rearm costs and the old reloads, so the tests of the ammo and
-- rearm mechanism (still in Sim/Air for any def that sets ammo) keep running.
-- `AmmoDefs.load()` builds that def set once; pass it as Sim.new's `defs`.
local Defs = require("@shared/Defs/Defs")

local AmmoDefs = {}

local AMMO = {
	chs_behemoth = { ammo = 3, ammoCost = { supply = 35, power = 260 } },
	chs_harpy = { ammo = 6, ammoCost = { supply = 8, power = 110 } },
	chs_leech = { ammo = 4, ammoCost = { supply = 12, power = 120 } },
	chs_manticore = { ammo = 10, ammoCost = { supply = 10, power = 140 } },
	chs_plague = { ammo = 6, ammoCost = { supply = 12, power = 100 } },
	chs_wasp = { ammo = 10, ammoCost = { supply = 6, power = 60 } },
	ord_absolution = { ammo = 4, ammoCost = { supply = 15, power = 120 } },
	ord_archon = { ammo = 6, ammoCost = { supply = 14, power = 200 } },
	ord_falcon = { ammo = 4, ammoCost = { supply = 10, power = 150 } },
	ord_guardian = { ammo = 12, ammoCost = { supply = 6, power = 60 } },
	ord_liche = { ammo = 1, ammoCost = { supply = 120, power = 1500 } },
	ord_phantom = { ammo = 2, ammoCost = { supply = 40, power = 300 } },
	ord_tidewatch = { ammo = 4, ammoCost = { supply = 12, power = 120 } },
}
local RELOAD = {
	chs_heavy_bomb = 2.5,
	chs_aam = 0.8,
	chs_heavy_aam = 0.9,
	chs_bomb = 1.5,
	chs_rockets = 0.8,
	ord_bomb = 1.5,
	ord_radar_aam = 2.4,
	ord_aam = 1.4,
	ord_rockets = 0.8,
	ord_liche_bomb = 1,
	ord_heavy_bomb = 2.5,
}

local built: Defs.DefSet? = nil
function AmmoDefs.load(): Defs.DefSet
	if built == nil then
		local registry = require("@shared/Defs/Registry") :: any
		local units, weapons = table.clone(registry.units), table.clone(registry.weapons)
		for id, extra in AMMO do
			local d = table.clone(units[id])
			d.ammo, d.ammoCost = extra.ammo, extra.ammoCost
			units[id] = d
		end
		for id, reload in RELOAD do
			local wd = table.clone(weapons[id])
			wd.reload = reload
			weapons[id] = wd
		end
		local copy = table.clone(registry)
		copy.units, copy.weapons = units, weapons
		built = Defs.build(copy)
	end
	return built :: Defs.DefSet
end

return AmmoDefs

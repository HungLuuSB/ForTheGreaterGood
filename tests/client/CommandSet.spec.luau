--!strict
-- Each unit type's commands (C-109): defenses, builders, factories, silos,
-- aircraft and tanks offer their own set; a mixed selection the union.

local CommandSet = require("../../src/client/Core/CommandSet")
local Defs = require("@shared/Defs/Defs")

local defs = Defs.load()

local function has(list: { string }, name: string): boolean
	return table.find(list, name) ~= nil
end

return function(t: any)
	t.test("a tank, a builder, a factory, a silo and a defense each get their own commands", function()
		local tank = CommandSet.of({ defs.units.ord_lancer })
		t.expect(has(tank, "move") and has(tank, "attack") and has(tank, "fire") and has(tank, "movestate"), "tank: moves and fights")
		t.expect(not has(tank, "repeat") and not has(tank, "repair") and not has(tank, "toggle"), "tank: no factory, builder or switch commands")
		local mason = CommandSet.of({ defs.units.ord_mason })
		t.expect(has(mason, "move") and has(mason, "repair") and has(mason, "reclaim") and has(mason, "guard"), "builder: moves, repairs, reclaims, assists")
		t.expect(has(mason, "resurrect"), "a T1 worker resurrects (S-168)")
		local plant = CommandSet.of({ defs.units.ord_vehplant })
		t.expect(has(plant, "repeat") and has(plant, "cancel") and has(plant, "move") and has(plant, "patrol"), "factory: queue and orders for new units")
		t.expect(has(plant, "attack") and has(plant, "guard"), "factory: attack and guard orders for its new units (S-95)")
		t.expect(not has(plant, "fire"), "factory: no fire state (no weapons)")
		local silo = CommandSet.of({ defs.units.ord_reckoning })
		t.expect(has(silo, "stop") and has(silo, "attack") and not has(silo, "fire") and not has(silo, "move"), "silo: stop and a manual attack only")
		local radiance = CommandSet.of({ defs.units.ord_radiance })
		t.expect(has(radiance, "toggle") and has(radiance, "attack") and has(radiance, "fire") and not has(radiance, "move"), "beam tower: on / off (retract), attack, fire state (S-96)")
		local citadel = CommandSet.of({ defs.units.ord_citadel })
		t.expect(has(citadel, "fire") and has(citadel, "attack") and not has(citadel, "move"), "defense: fire state and attack, no movement")
		for _, list in { tank, mason, plant, silo, citadel } do
			t.expect(has(list, "stop") and has(list, "alert"), "stop and the alert jump everywhere")
		end
		t.equal(#CommandSet.of({}), 0, "nothing selected, no commands")
		-- the audit (C-193): nothing to stop on a passive structure; shields switch
		for _, id in { "ord_generator", "chs_generator", "ord_extractor", "ord_depot", "ord_airpad", "ord_barrier", "ord_witness", "ord_ear" } do
			local list = CommandSet.of({ defs.units[id] }, defs)
			t.expect(not has(list, "stop") and has(list, "alert"), `{id}: no Stop, only the alert jump`)
		end
		for _, id in { "ord_phalanx", "chs_carapace" } do
			local list = CommandSet.of({ defs.units[id] }, defs)
			t.expect(has(list, "toggle") and not has(list, "stop"), `{id}: On / Off to save power, no Stop`)
		end
		for _, id in { "ord_sanctum", "chs_basilisk", "ord_providence", "chs_cerberus" } do
			local list = CommandSet.of({ defs.units[id] }, defs)
			t.expect(has(list, "fire") and not has(list, "attack") and not has(list, "stop"), `{id}: an interceptor holds fire or not, nothing manual`)
		end
		local nuke = CommandSet.of({ defs.units.ord_reckoning }, defs)
		t.expect(has(nuke, "stop") and has(nuke, "attack") and not has(nuke, "fire"), "a nuke silo with the def set: stop and a manual launch")
		-- resource priority (S-156, C-196) where it does something
		for _, id in { "ord_mason", "ord_vehplant", "ord_phalanx", "ord_beacon", "ord_falcon", "ord_reckoning", "ord_guardian" } do
			t.expect(has(CommandSet.of({ defs.units[id] }, defs), "priority"), `{id}: priority`)
		end
		for _, id in { "ord_lancer", "ord_generator", "ord_extractor" } do
			t.expect(not has(CommandSet.of({ defs.units[id] }, defs), "priority"), `{id}: no priority (uses no resources)`)
		end
		local sam = CommandSet.of({ defs.units.ord_aegis }, defs)
		t.expect(has(sam, "fire") and has(sam, "attack") and has(sam, "stop"), "a stockpiled SAM site is an ordinary defense")
		-- Upgrade extractors (C-121): builders with an upgrading extractor only
		t.expect(has(CommandSet.of({ defs.units.ord_architect }, defs), "upgrade"), "a T2 builder upgrades extractors")
		t.expect(not has(CommandSet.of({ defs.units.ord_mason }, defs), "upgrade"), "a T1 builder doesn't")
	end)

	t.test("a mixed selection offers the union, in card order", function()
		local mixed = CommandSet.of({ defs.units.ord_lancer, defs.units.ord_mason })
		t.expect(has(mixed, "repair") and has(mixed, "movestate"), "both units' commands")
		local last = 0
		for _, name in mixed do
			local i = table.find(CommandSet.ORDER, name) :: number
			t.expect(i > last, `{name} in order`)
			last = i
		end
	end)
end

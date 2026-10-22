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
		local plant = CommandSet.of({ defs.units.ord_vehplant })
		t.expect(has(plant, "repeat") and has(plant, "cancel") and has(plant, "move") and has(plant, "patrol"), "factory: queue and orders for new units")
		t.expect(has(plant, "attack") and has(plant, "guard"), "factory: attack and guard orders for its new units (S-95)")
		t.expect(not has(plant, "fire"), "factory: no fire state (no weapons)")
		local silo = CommandSet.of({ defs.units.ord_reckoning })
		t.expect(has(silo, "stop") and has(silo, "attack") and not has(silo, "fire") and not has(silo, "move"), "silo: stop and a manual attack only")
		local citadel = CommandSet.of({ defs.units.ord_citadel })
		t.expect(has(citadel, "fire") and has(citadel, "attack") and not has(citadel, "move"), "defense: fire state and attack, no movement")
		for _, list in { tank, mason, plant, silo, citadel } do
			t.expect(has(list, "stop") and has(list, "alert"), "stop and the alert jump everywhere")
		end
		t.equal(#CommandSet.of({}), 0, "nothing selected, no commands")
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

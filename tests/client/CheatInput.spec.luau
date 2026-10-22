--!strict
-- The cheat command line's typing help (C-119): suggestions for commands and
-- unit ids or names, names turned into ids, the cursor added to a give.

local CheatInput = require("../../src/client/Core/CheatInput")
local Defs = require("@shared/Defs/Defs")

local defs = Defs.load()

return function(t: any)
	t.test("suggests commands, then units by id or display name, case-insensitive", function()
		local cmds = CheatInput.suggest("/gi", defs)
		t.equal(cmds[1].text, "/give ")
		local all = CheatInput.suggest("/", defs, 20)
		t.expect(#all >= 10, "every command with an empty line")
		local byId = CheatInput.suggest("/give ord_la", defs)
		t.equal(byId[1].text, "/give ord_lancer ")
		local byName = CheatInput.suggest("/give LANC", defs)
		t.equal(byName[1].text, "/give ord_lancer ", "by display name, any case")
		t.equal(#CheatInput.suggest("/give ord_lancer 5", defs), 0, "nothing past the unit")
	end)

	t.test("prepares the line: names to ids, the cursor added to a give", function()
		t.equal(CheatInput.prepare("/give lancer 3", defs, 100.4, -20.6), "give ord_lancer 3 at 100,-21")
		t.equal(CheatInput.prepare("/give ord_lancer at 5,5", defs, 100, 100), "give ord_lancer at 5,5", "an explicit at stays")
		t.equal(CheatInput.prepare("/cheat give ord_lancer", defs, 1, 2), "give ord_lancer at 1,2", "/cheat prefix dropped")
		t.equal(CheatInput.prepare("/cheat on", defs), "cheat on", "/cheat on keeps its word")
		t.equal(CheatInput.prepare("/god on", defs), "god on")
		t.equal(CheatInput.unitId("Radiance", defs), "ord_radiance")
		t.equal(CheatInput.unitId("nothing", defs), nil)
	end)

	t.test("/help lists every command with an example", function()
		local lines = CheatInput.help()
		t.expect(#lines >= #CheatInput.COMMANDS + 1, "a line each")
		t.expect(string.find(table.concat(lines, "\n"), "e.g. /give ord_lancer 5", 1, true) ~= nil, "with examples")
	end)
end

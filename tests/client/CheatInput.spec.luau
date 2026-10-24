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
		local counts = CheatInput.suggest("/give ord_lancer ", defs)
		t.expect(#counts > 0 and counts[1].text == "/give ord_lancer 1 ", "counts after the unit (C-194)")
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

	t.test("names who cheated in the results, nil when nobody did", function()
		t.equal(CheatInput.cheaters({ players = { { name = "A", stats = { cheats = 0 } } }, series = {} }), nil)
		t.equal(CheatInput.cheaters({ players = { { name = "A", stats = { cheats = 3 } }, { name = "B", stats = { cheats = 0 } } } }), "A ×3")
		t.equal(CheatInput.cheaters({ players = {}, series = { cheated = true } }), "", "the series flag alone")
	end)

	t.test("/help lists every command with an example", function()
		local lines = CheatInput.help()
		t.expect(#lines >= #CheatInput.COMMANDS + 1, "a line each")
		t.expect(string.find(table.concat(lines, "\n"), "e.g. /give ord_lancer 5", 1, true) ~= nil, "with examples")
	end)

	t.test("units answer to their icon-sheet type with the faction's prefix, full and short (C-194)", function()
		t.equal(CheatInput.unitId("ord_shield", defs), "ord_phalanx")
		t.equal(CheatInput.unitId("chs_shield-generator", defs), "chs_carapace")
		t.equal(CheatInput.unitId("phalanx", defs), "ord_phalanx", "the display name")
		local both = CheatInput.resolve("shield", defs)
		t.expect(table.find(both, "ord_phalanx") ~= nil and table.find(both, "chs_carapace") ~= nil, "the type alone names both factions'")
		t.equal(CheatInput.unitId("shield", defs), nil, "ambiguous: no single id (Tab cycles them)")
		local irSam = CheatInput.resolve("ord_ir-sam", defs)
		t.expect(#irSam >= 1, "ord_ir-sam names Order's IR SAM site")
		t.equal(CheatInput.prepare("/give ord_shield 2", defs, 0, 0), "give ord_phalanx 2 at 0,0")
		local sug = CheatInput.suggest("/give ord_shi", defs)
		t.equal(sug[1].text, "/give ord_phalanx ", "suggested by alias")
		t.expect(string.find(sug[1].label, "Shield Generator", 1, true) ~= nil, "the label says the type")
	end)

	t.test("each command's choices come up as it's typed (C-194)", function()
		local function texts(line: string): { string }
			local out = {}
			for _, x in CheatInput.suggest(line, defs, 20) do
				table.insert(out, x.text)
			end
			return out
		end
		t.deepEqual(texts("/reveal "), { "/reveal on ", "/reveal off " })
		t.deepEqual(texts("/god o"), { "/god on ", "/god off " })
		t.deepEqual(texts("/god of"), { "/god off " })
		t.equal(texts("/kill ")[1], "/kill selected ")
		t.deepEqual(texts("/res p"), { "/res power " })
		t.equal(texts("/res all ")[1], "/res all max ")
		t.deepEqual(texts("/ai 2 "), { "/ai 2 pause ", "/ai 2 resume " })
		t.equal(#texts("/speed "), 6)
	end)

	t.test("retired units aren't suggested or aliased, but their id still works (S-157)", function()
		for _, x in CheatInput.suggest("/give chs_spi", defs, 50) do
			t.expect(not string.find(x.text, "chs_spike", 1, true), "Spike retired")
		end
		t.equal(CheatInput.unitId("chs_spike", defs), "chs_spike", "the id still resolves")
		t.equal(#CheatInput.resolve("ord_gun-turret", defs), 0, "the retired Bulwark's type names nothing")
		t.deepEqual(CheatInput.resolve("ord_laser", defs), { "ord_sentry_tower" }, "draft 5's Laser Tower: the Sentry")
	end)
end

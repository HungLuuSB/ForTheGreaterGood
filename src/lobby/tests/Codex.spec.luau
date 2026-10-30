--!strict
-- The unit encyclopedia's data (L-18) on the real defs: every role names
-- real units of the right faction, every buildable unit has a role, pairs
-- point at each other, retired defs stay out, and the numbers match the
-- defs and the unit panel's damage-per-second rule.

local Codex = require("../shared/Codex")
local Defs = require("@shared/Defs/Defs")
local RunAll = require("../../server/Tests/RunAll")

local defs = Defs.load()
local codex = Codex.build(defs)

return function(t: RunAll.Context)
	t.test("every role lists real units of its own faction, once", function()
		local seen: { [string]: string } = {}
		for _, role in Codex.ROLES do
			t.expect(#role.order + #role.chaos > 0, `{role.name} lists nobody`)
			for side, list in { order = role.order, chaos = role.chaos } do
				for _, id in list do
					local def = defs.units[id]
					-- an announced unit may come before its def (Codex.ANNOUNCED)
					t.expect(def ~= nil or Codex.ANNOUNCED[id] ~= nil, `{role.name}: no def {id}`)
					if def then
						t.equal(def.faction, side, `{role.name}: {id}`)
					end
					t.equal(seen[id], nil, `{id} is in two roles ({seen[id]}, {role.name})`)
					seen[id] = role.name
				end
			end
		end
	end)

	t.test("announced units are named by a role and stay hidden until their def lands", function()
		local named: { [string]: boolean } = {}
		for _, role in Codex.ROLES do
			for _, list in { role.order, role.chaos } do
				for _, id in list do
					named[id] = true
				end
			end
		end
		for id in Codex.ANNOUNCED do
			t.expect(named[id], `{id} is announced but no role names it`)
			if defs.units[id] == nil then
				t.equal(codex.entries[id], nil, id)
			end
		end
	end)

	t.test("every buildable unit and structure has a role; retired ones don't show", function()
		local missing = {}
		for id, e in codex.entries do
			if e.role == nil then
				table.insert(missing, id)
			end
		end
		table.sort(missing)
		t.equal(#missing, 0, `no role: {table.concat(missing, ", ")}`)
		t.equal(codex.entries.chs_inferno, nil)
		t.equal(codex.entries.chs_spike, nil)
		t.equal(codex.entries.ord_bulwark, nil)
		t.equal(codex.entries.ord_generator, nil)
		t.equal(codex.entries.chs_generator, nil)
		t.expect(codex.entries.ord_sovereign ~= nil, "Command Vehicles show though nothing builds them")
		local fake = { units = table.clone(defs.units), weapons = defs.weapons }
		fake.units.ord_titan = table.clone(defs.units.ord_titan)
		fake.units.ord_titan.retired = true
		local c = Codex.build(fake)
		t.equal(c.entries.ord_titan, nil, "a retired def on a build list still doesn't show")
		t.equal(#c.entries.chs_juggernaut.counterparts, 0, "and isn't a counterpart")
	end)

	t.test("counterparts point at each other", function()
		t.deepEqual(codex.entries.ord_titan.counterparts, { "chs_juggernaut" })
		t.deepEqual(codex.entries.chs_juggernaut.counterparts, { "ord_titan" })
		-- S-224 brings the Goliath back; until its def is on this branch it's
		-- still retired (S-213), hidden, and the Paladin has no counterpart
		if defs.units.chs_goliath.retired then
			t.equal(codex.entries.chs_goliath, nil, "the retired Goliath")
			t.equal(#codex.entries.ord_paladin.counterparts, 0, "no Chaos main battle tank while it's retired")
		else
			t.deepEqual(codex.entries.ord_paladin.counterparts, { "chs_goliath" })
			t.deepEqual(codex.entries.chs_goliath.counterparts, { "ord_paladin" })
		end
		t.deepEqual(codex.entries.ord_overwatch.counterparts, { "chs_twin_guard", "chs_geryon" })
		t.deepEqual(codex.entries.chs_geryon.counterparts, { "ord_overwatch" })
		t.equal(#codex.entries.ord_warden.counterparts, 0, "faction-only")
		for id, e in codex.entries do
			for _, other in e.counterparts do
				t.expect(codex.entries[other] ~= nil, `{id}'s counterpart {other} isn't listed`)
				t.notEqual(defs.units[other].faction, e.faction)
			end
		end
	end)

	t.test("lists run by section, then role", function()
		for faction, list in codex.byFaction do
			t.expect(#list > 60, `{faction}: {#list}`)
			t.equal(list[1].id, if faction == "order" then "ord_sovereign" else "chs_warlord")
			local last = 0
			for _, e in list do
				local at = 0
				for i, s in Codex.SECTIONS do
					if s.id == e.section then
						at = i
					end
				end
				t.expect(at >= last, `{e.id} out of section order`)
				last = at
			end
		end
	end)

	t.test("article numbers come from the defs", function()
		local s = Codex.stats(codex, "ord_paladin")
		local def = defs.units.ord_paladin
		t.equal(s.supply, def.cost.supply)
		t.equal(s.power, def.cost.power)
		t.equal(s.value, def.cost.supply + def.cost.power / 10)
		t.equal(s.health, def.health)
		t.equal(s.speed, def.movement.maxSpeed)
		t.equal(#s.weapons, 1)
		local w = defs.weapons.ord_heavy_cannon
		t.equal(s.weapons[1].class, "ARMORED")
		t.equal(s.weapons[1].dps, w.damage.ARMORED / w.reload)
		t.equal(s.range, w.range)
		t.equal(s.weapons[1].damage.AIR, nil, "zero damage is left out")
		t.expect(s.buildSeconds ~= nil and s.builder ~= nil, "built by a factory with build power")
		t.equal(Codex.stats(codex, "ord_archon").stealth, defs.units.ord_archon.sensors.radarSignature)
		t.expect(#Codex.stats(codex, "ord_vehplant").builds > 0)
	end)

	t.test("the firing range has a target for every weapon but anti-missile and strategic ones", function()
		local skipped = {}
		for id, w in defs.weapons do
			local kind = Codex.rangeTarget(w, false)
			if kind == nil then
				t.expect(w.interceptOnly or w.strategic or w.intercepts, `{id} has no target`)
				table.insert(skipped, id)
			end
			if table.find(w.targets, "SUB") then
				t.equal(Codex.rangeTarget(w, true), "sub", `{id} on water`)
			end
		end
		t.equal(Codex.rangeTarget(defs.weapons.ord_ir_sam, false), "air")
		t.equal(Codex.rangeTarget(defs.weapons.ord_heavy_cannon, true), "ground")
		t.expect(#skipped > 0 and #skipped < 12, `{#skipped} skipped`)
	end)

	t.test("a comparison lists differences of 5% or more, biggest first", function()
		local d = Codex.compare(codex, "ord_titan", "chs_juggernaut")
		for i, x in d do
			t.expect(math.abs(x.pct) >= 5, x.label)
			if i > 1 then
				t.expect(math.abs(d[i - 1].pct) >= math.abs(x.pct))
			end
		end
		local same = Codex.compare(codex, "ord_paladin", "ord_paladin")
		t.equal(#same, 0)
		for _, x in Codex.compare(codex, "ord_lancer", "chs_ravager") do
			if x.label == "value" then
				t.equal(x.better, x.pct < 0, "cheaper is better")
			end
		end
	end)

	t.test("the article's bars: each stat's maximum is the game's biggest, and the cards' words", function()
		local max = Codex.maxima(codex)
		local seraph = Codex.stats(codex, "ord_seraph")
		for _, id in { "ord_paladin", "ord_seraph", "chs_juggernaut", "ord_mason" } do
			local s = Codex.stats(codex, id)
			t.expect(s.health <= max.health and s.supply <= max.supply and s.power <= max.power, id)
			for _, w in s.weapons do
				t.expect(w.dps <= max.wDps and w.alpha <= max.wAlpha and w.range <= max.wRange, `{id} {w.id}`)
			end
		end
		t.expect(max.health > seraph.health, "the Seraph isn't the toughest")
		local sam = seraph.weapons[1]
		t.equal(sam.launch, "vertical")
		t.equal(sam.stock, 15)
		t.expect(sam.stockSeconds ~= nil and sam.stockPower ~= nil and sam.speed ~= nil, "stockpile and speed")
		t.equal(Codex.word("reload", 3.7), "slow")
		t.equal(Codex.word("alpha", 1150), "very heavy")
		t.equal(Codex.word("aoe", 20), "large")
		t.equal(Codex.word("range", 1100), "very long")
	end)
end

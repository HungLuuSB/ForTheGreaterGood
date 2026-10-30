--!strict
-- The skirmish AI's counters by the enemy's spending (S-223, after BAR's
-- CircuitAI): the classes, the shares the table asks for, and a plant that
-- answers known artillery with raiders and known defences with artillery.
local Counters = require("../Sim/AI/Counters")
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function start(seed: number): Sim.Sim
	return Sim.new({
		seed = seed,
		players = PLAYERS,
		mapId = "skirmish:192",
		scenario = "standard_start",
		match = { mode = "FFA", win = "COMMAND_ENDS" },
	})
end

return function(t: RunAll.Context)
	t.test("enemy classes: light, armored, artillery, defence, air, naval; unarmed units and Commanders none (S-223)", function()
		local u = start(1).defs.units
		t.equal(Counters.classOf(u.chs_jackal), "light")
		t.equal(Counters.classOf(u.ord_paladin), "armored")
		t.equal(Counters.classOf(u.ord_verdict), "artillery")
		t.equal(Counters.classOf(u.chs_guard), "defense")
		t.equal(Counters.classOf(u.ord_falcon), "air")
		t.equal(Counters.classOf(u.ord_sentry), "naval")
		t.equal(Counters.classOf(u.ord_mason), nil, "a worker")
		t.equal(Counters.classOf(u.ord_sovereign), nil, "a Commander")
		t.equal(Counters.classOf(u.ord_solar), nil, "an economy building")
	end)

	t.test("the counter table: shares of the enemy's value ask for roles, each capped (S-223)", function()
		local none = Counters.demand({})
		for _, r in Counters.ROLES do
			t.equal(none[r], 0, `{r}: nothing known, nothing asked`)
		end
		local d = Counters.demand({ defense = 1000 })
		t.equal(d.artillery, Counters.CAPS.artillery, "all defence: artillery, at its cap")
		d = Counters.demand({ artillery = 500 })
		t.equal(d.raider, Counters.CAPS.raider, "all artillery: raiders, at their cap")
		d = Counters.demand({ light = 300, defense = 300 })
		t.equal(d.heavy, 0.5 * Counters.RESPONSE.light.heavy, "half light: heavy")
		t.equal(d.artillery, 0.5 * Counters.RESPONSE.defense.artillery, "half defence: artillery")
		t.equal(d.raider, 0, "no artillery known: no raiders")
	end)

	t.test("the plant answers known artillery with raiders and known defences with artillery (S-223)", function()
		-- 6 minutes of normal Order with full accounts and no waves; what
		-- its plants queued, with the enemy's mix it remembers set
		local function trial(mix: { [string]: number }): { [string]: number }
			local sim = start(61)
			local brain = Skirmish.new(sim, 1, "normal")
			brain.lastRetreatAt = math.huge
			local w = sim.world
			local seen: { [number]: boolean } = {}
			local made: { [string]: number } = {}
			for _ = 1, 900 * 6 do
				for k, v in mix do
					brain.enemyMix[k] = v
				end
				brain.enemyMixAt = sim.tick
				local acc = sim.eco.accounts[brain.team]
				acc.supply.stored = acc.supply.storage
				acc.power.stored = acc.power.storage
				Skirmish.tick(brain)
				Sim.step(sim)
				for _, id in w.ids do
					if w.owner[id] == 1 and not seen[id] then
						seen[id] = true
						local defId = sim.defs.unitByIndex[w.defIndex[id]].id
						made[defId] = (made[defId] or 0) + 1
					end
				end
			end
			return made
		end
		local base = trial({})
		local vsArty = trial({ artillery = 1e6 })
		local vsDefense = trial({ defense = 1e6 })
		local function n(m: { [string]: number }, id: string): number
			return m[id] or 0
		end
		print(string.format("    heralds %d / %d / %d, verdicts %d / %d / %d (none / artillery / defence)", n(base, "ord_herald"), n(vsArty, "ord_herald"), n(vsDefense, "ord_herald"), n(base, "ord_verdict"), n(vsArty, "ord_verdict"), n(vsDefense, "ord_verdict")))
		t.expect(n(vsArty, "ord_herald") >= n(base, "ord_herald") + 2, "raiders against artillery")
		t.expect(n(vsDefense, "ord_verdict") >= n(base, "ord_verdict") + 2, "artillery against defences")
	end)
end

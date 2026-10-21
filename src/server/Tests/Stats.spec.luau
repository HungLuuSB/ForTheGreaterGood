--!strict
-- Match statistics per player (S-63, client request 38): units built, lost
-- and killed, damage dealt, resources gathered and spent.
local Combat = require("../Sim/Combat/Combat")
local Economy = require("../Sim/Economy")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Stats = require("../Sim/Stats")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

return function(t: RunAll.Context)
	t.test("damage dealt is enemy health removed, capped at what was left; kills and losses by owner", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local lancers = {}
		for i = 1, 3 do
			table.insert(lancers, Spawn.unit(sim, "ord_lancer", 1, -60, (i - 2) * 20, math.pi / 2))
		end
		local victim = Spawn.unit(sim, "chs_jackal", 2, 60, 0, -math.pi / 2)
		World.setFireState(w, victim, World.FireState.HOLD_FIRE)
		local hp = w.health[victim]
		for _ = 1, 600 do
			Sim.step(sim)
			if not World.isAlive(w, victim) then
				break
			end
		end
		t.expect(not World.isAlive(w, victim), "the Jackal died")
		local r = Stats.report(sim)
		t.expect(math.abs(r[1].damageDealt - hp) < 1e-6, `damage dealt is the Jackal's health, overkill not counted ({r[1].damageDealt} of {hp})`)
		t.equal(r[1].unitsKilled, 1)
		t.equal(r[2].unitsLost, 1)
		t.equal(r[1].unitsLost, 0)
		t.equal(r[2].damageDealt, 0, "it never fired")
	end)

	t.test("a shell keeps its shooter's player after the shooter dies", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local gun = Spawn.unit(sim, "ord_verdict", 1, -80, 0, math.pi / 2) -- 160 studs: in its sight
		local target = Spawn.unit(sim, "chs_vehplant", 2, 80, 0, 0) -- a big target: the one shell hits
		local full = w.health[target]
		local killed = false
		for _ = 1, 300 do
			Sim.step(sim)
			if not killed then
				for _, e in sim.combat.events do
					if e.kind == "SPAWN_PROJ" and e.unit == gun then
						Combat.queueDamage(sim.combat, gun, 1e6, 0) -- dies with its shell in the air
						killed = true
					end
				end
			elseif w.health[target] < full then
				break
			end
		end
		t.expect(killed and not World.isAlive(w, gun), "the Verdict fired, then died")
		t.expect(w.health[target] < full, "its shell landed")
		t.expect(math.abs(Stats.report(sim)[1].damageDealt - (full - w.health[target])) < 1e-6, "the shell's damage counts for player 1")
	end)

	t.test("units built count factory output and finished structures, not the start", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64", scenario = "standard_start" })
		local acc = sim.eco.accounts[1]
		acc.supply.stored, acc.power.stored = 1e6, 1e6
		acc.supply.storage, acc.power.storage = 1e6, 1e6
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
		local cell = (sim.map :: any).grid:encode(0, 0)
		submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_herald.index, cell = cell, offX = 0, offZ = 0, facing = 0 })
		local produced = 0
		for _ = 1, 600 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "PRODUCED" then
					produced += 1
				end
			end
		end
		t.expect(produced >= 1, "the plant produced")
		t.equal(Stats.report(sim)[1].unitsBuilt, produced, "each produced unit, nothing for the starting units")
	end)

	t.test("resources gathered and spent follow the account, a forgiven shortfall not spent", function()
		local r: Economy.Resource = {
			stored = 100,
			storage = 1000,
			income = 30,
			demand = 0,
			ratio = 1,
			spent = 50,
			reclaimed = 20,
			wasted = 0,
			gathered = 0,
			drawn = 0,
		}
		Economy.settle(r, 1)
		t.equal(r.gathered, 50, "income for the window and reclaim")
		t.equal(r.drawn, 50)
		t.equal(r.stored, 100)
		r.spent = 400 -- more than it has: 100 stored + 30 income
		Economy.settle(r, 1)
		t.equal(r.drawn, 50 + 130, "only what was there")
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64", scenario = "standard_start" })
		for _ = 1, 300 do
			Sim.step(sim)
		end
		local rep = Stats.report(sim)
		t.expect(rep[1].powerGathered > 0 and rep[1].supplyGathered > 0, "the Command Vehicle's production counts")
	end)
end

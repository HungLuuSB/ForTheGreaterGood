--!strict
-- Friendly fire as a match option (S-73, guide 10.6, audit item 14).
local Combat = require("../Sim/Combat/Combat")
local Replay = require("../Sim/Replay")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

-- A 300-damage blast of radius 20 between an own tank and an enemy tank.
local function blast(sim: Sim.Sim): (number, number)
	local w = sim.world
	local own = Spawn.unit(sim, "ord_lancer", 1, -6, 0)
	local enemy = Spawn.unit(sim, "chs_ravager", 2, 6, 0)
	Sim.step(sim) -- into the contact grid
	local h1, h2 = w.health[own], w.health[enemy]
	local weapon = { damage = { LIGHT = 300, ARMORED = 300, STRUCTURE = 300, SHIP = 300, AIR = 0, SUB = 0 }, aoe = 20, edgeEffectiveness = 1 }
	Combat.explode(sim.combat, w, 0, 2, 0, weapon :: any, 0, w.ally[own], 0, 1)
	Sim.step(sim)
	return h1 - w.health[own], h2 - w.health[enemy]
end

return function(t: RunAll.Context)
	t.test("a match without friendly fire spares allies from blasts; the default hurts them", function()
		local on = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64", match = { mode = "FFA", win = "ANNIHILATION" } })
		local ownOn, enemyOn = blast(on)
		t.expect(ownOn > 0 and enemyOn > 0, `default: both tanks hurt ({ownOn}, {enemyOn})`)
		local off = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64", match = { mode = "FFA", win = "ANNIHILATION", friendlyFire = false } })
		local ownOff, enemyOff = blast(off)
		t.equal(ownOff, 0, "friendly fire off: the own tank is untouched")
		t.expect(enemyOff > 0, "the enemy still takes it")
	end)

	t.test("the option travels in the replay header", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64", match = { mode = "FFA", win = "ANNIHILATION", friendlyFire = false } })
		local log = Replay.parse(Replay.serialize(sim.replay))
		t.equal((log.header.match :: any).friendlyFire, false)
		t.equal(Sim.fromReplay(log).combat.friendlyFire, false, "a replayed match keeps it")
		local plain = Replay.parse(Replay.serialize(Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64", match = { mode = "FFA", win = "ANNIHILATION" } }).replay))
		t.equal((plain.header.match :: any).friendlyFire, nil, "the default writes the old header")
	end)
end

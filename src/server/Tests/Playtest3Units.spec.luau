--!strict
-- Playtest 3's new units (S-209): the construction turret's nano-only death
-- blast, the Juggernaut's near-nuke self-destruct, the economy's numbers.
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function steps(sim: Sim.Sim, n: number)
	for _ = 1, n do
		Sim.step(sim)
	end
end

local function selfDestruct(sim: Sim.Sim, player: number, id: number)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.SELF_DESTRUCT, flags = 0, unitIds = { id }, value = 1 })
	assert(Sim.submit(sim, player, w:finish()))
end

-- A nano at (0, 0), a second nano and a tank of its own side 24 studs off,
-- an enemy tank 24 studs the other way.
local function nanoPack(): (Sim.Sim, number, number, number, number)
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" }) -- (a death blast hurts every side: team 0)
	local w = sim.world
	local nano = Spawn.unit(sim, "ord_nano", 1, 0, 0)
	local other = Spawn.unit(sim, "ord_nano", 1, 24, 0)
	local tank = Spawn.unit(sim, "ord_lancer", 1, 0, 24)
	local enemy = Spawn.unit(sim, "chs_ravager", 2, -24, 0)
	for _, id in { tank, enemy } do
		World.setFireState(w, id, World.FireState.HOLD_FIRE)
	end
	return sim, nano, other, tank, enemy
end

return function(t: RunAll.Context)
	t.test("a construction turret's death hurts only the nanos around it; self-destructed, none (H31)", function()
		local sim, nano, other, tank, enemy = nanoPack()
		local w = sim.world
		local hp = { [other] = w.health[other], [tank] = w.health[tank], [enemy] = w.health[enemy] }
		Combat.queueDamage(sim.combat, nano, 1e6, 0)
		steps(sim, 3)
		t.equal(w.slot[nano], nil, "the nano died")
		t.expect(w.slot[other] == nil or w.health[other] < hp[other], "the nano beside it is hurt or set off (a chain)")
		t.equal(w.health[tank], hp[tank], "its own tank isn't")
		t.equal(w.health[enemy], hp[enemy], "nor the enemy's")

		local sim2, nano2, other2 = nanoPack()
		local w2 = sim2.world
		local before = w2.health[other2]
		selfDestruct(sim2, 1, nano2)
		steps(sim2, 15 * 7)
		t.equal(w2.slot[nano2], nil, "self-destructed")
		t.equal(w2.health[other2], before, "a self-destructed nano hurts no nano")
	end)

	t.test("the Juggernaut self-destructs almost like a nuke: 220 studs (H40)", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:96" })
		local w = sim.world
		local jug = Spawn.unit(sim, "chs_korgoth", 1, 0, 0)
		local far = Spawn.unit(sim, "ord_paladin", 2, 160, 0)
		World.setFireState(w, jug, World.FireState.HOLD_FIRE)
		World.setFireState(w, far, World.FireState.HOLD_FIRE)
		local before = w.health[far]
		selfDestruct(sim, 1, jug)
		steps(sim, 15 * 7)
		t.equal(w.slot[jug], nil, "it went up")
		t.expect(w.slot[far] == nil or w.health[far] < before, "a tank 160 studs off is hit")
	end)

	t.test("the new economy's numbers (H23, H25, H27-H30)", function()
		local defs = Sim.new({ seed = 1, players = PLAYERS }).defs
		local u = defs.units
		for _, p in { "ord_", "chs_" } do
			t.equal((u[p .. "solar"].production :: any).power, 20, p .. "solar: +20 power")
			t.equal((u[p .. "solar"].storage :: any).power, 50, p .. "solar: +50 storage")
			t.equal((u[p .. "advsolar"].production :: any).power, 80, p .. "advsolar: +80 power")
			t.equal((u[p .. "advsolar"].storage :: any).power, 100, p .. "advsolar: +100 storage")
			t.equal((u[p .. "advfusion"].production :: any).power, 3000, p .. "advfusion: +3,000 power")
			t.equal((u[p .. "advfusion"].storage :: any).power, 9000, p .. "advfusion: +9,000 storage")
			t.equal((u[p .. "advdepot"].storage :: any).supply, 10000, p .. "advdepot: +10,000 supply storage")
			t.deepEqual(u[p .. "advconverter"].converter, { power = 600, supply = 10.3 }, p .. "advconverter: 600 → 10.3")
			t.equal(u[p .. "windmill"].cost.supply, 40, p .. "windmill: 40 supply")
			t.equal(u[p .. "windmill"].cost.power, 175, p .. "windmill: 175 power")
			t.expect(u[p .. "generator"].retired == true, p .. "generator: retired")
		end
		t.equal((u.ord_capacitor.storage :: any).power, 6000, "Capacitor Bank: +6,000")
		t.equal((u.chs_accumulator.storage :: any).power, 6000, "Accumulator: +6,000")
		t.equal((u.ord_advcapacitor.storage :: any).power, 60000, "Grid Reservoir: +60,000")
		t.equal((u.chs_advaccumulator.storage :: any).power, 60000, "Great Accumulator: +60,000")
	end)
end

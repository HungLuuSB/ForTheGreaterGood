--!strict
-- Playtest 3's new units (S-209): the construction turret's nano-only death
-- blast, the Juggernaut's near-nuke self-destruct, the economy's numbers.
local Build = require("../Sim/Build")
local Combat = require("../Sim/Combat/Combat")
local Placement = require("../Sim/Placement")
local Packer = require("@shared/Net/Packer")
local PlacementRules = require("@shared/Grid/PlacementRules")
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

	t.test("a construction turret left alone assists, repairs and reclaims what is in its reach, and never moves (H31, S-211)", function()
		-- a Commander's solar 40 studs off it, its progress after 1.3 s
		local function solarProgress(withNano: boolean): (number, Sim.Sim, number?)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:96" })
			local w = sim.world
			local acc = sim.eco.accounts[1]
			acc.supply.stored, acc.power.stored = acc.supply.storage, acc.power.storage
			local com = Spawn.unit(sim, "ord_sovereign", 1, 0, -40)
			World.setFireState(w, com, World.FireState.HOLD_FIRE)
			local nano = if withNano then Spawn.unit(sim, "ord_nano", 1, 80, 0) else nil
			Build.commandBuild(sim, { com }, sim.defs.units.ord_solar.index, 0, 0, 0)
			steps(sim, 20)
			local frame = sim.build.target[com] or 0
			return if frame ~= 0 then w.buildProgress[frame] else 1, sim, nano
		end
		local alone = solarProgress(false)
		local helped, sim, nano = solarProgress(true)
		t.expect(helped > alone * 1.5, `the nano helped build the Commander's solar ({helped} against {alone})`)

		local w = sim.world
		local id = nano :: number
		local x, z = w.posX[id], w.posZ[id]
		local near = Spawn.unit(sim, "ord_lancer", 1, 180, 0) -- 100 studs off: in reach
		local far = Spawn.unit(sim, "ord_lancer", 1, 80, 300) -- out of it
		for _, u in { near, far } do
			World.setFireState(w, u, World.FireState.HOLD_FIRE)
			World.setHealth(w, u, w.health[u] / 2)
		end
		local nearHp, farHp = w.health[near], w.health[far]
		steps(sim, 15 * 20)
		t.expect(w.health[near] > nearHp, "it repaired the tank in reach")
		t.equal(w.health[far], farHp, "not the one out of it")

		local wreck = Combat.addWreck(sim.combat, 80, 100, sim.defs.units.chs_ravager, 0)
		local supply = sim.combat.wreckSupply[wreck]
		steps(sim, 15 * 3)
		t.expect(sim.combat.wreckX[wreck] == nil or sim.combat.wreckSupply[wreck] < supply, "it reclaims the wreck in reach")

		Build.commandAssist(sim, { id }, far)
		steps(sim, 2)
		t.equal(w.health[far], farHp, "an order out of reach does nothing")
		t.expect((sim.build.target[id] or 0) ~= far, "and is dropped")
		t.equal(w.posX[id], x, "it never moved")
		t.equal(w.posZ[id], z)
	end)

	t.test("an offshore extractor goes only under the sea, like a ship's yard (H20)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "wall:64" })
		local g = (sim.map :: any).grid
		local wx, wz = g:cellCenter(32, 40) -- wall:64's lake
		for _, id in { "ord_seaextractor", "chs_seaextractor" } do
			local def = sim.defs.units[id]
			local _, onWater = Placement.check(sim, def, wx, wz)
			t.expect(onWater ~= "terrain", `{id}: the lake's terrain is fine ({onWater})`)
			local _, onLand = Placement.check(sim, def, g:cellCenter(4, 4))
			t.equal(onLand, "terrain", `{id}: not on land`)
		end
		local pm = sim.map :: any
		for i = 0, g.cellsX * g.cellsZ - 1, 7 do
			t.equal(PlacementRules.terrainOk(pm, i, "seafloor"), PlacementRules.terrainOk(pm, i, "water"), `cell {i}: seafloor is water's rule`)
		end
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

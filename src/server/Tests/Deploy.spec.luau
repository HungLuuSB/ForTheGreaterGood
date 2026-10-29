--!strict
-- Faction-only units, stage 2 (S-64): the Warden deploys (Sim/Deploy), the
-- Minotaur's demolition charge levels structures.
local Combat = require("../Sim/Combat/Combat")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local CT = Schema.CmdType
local DEPLOYED, DEPLOYING = World.State.DEPLOYED, World.State.DEPLOYING

local function command(sim: Sim.Sim, player: number, ids: { number }, cmdType: number, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = cmdType, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function steps(sim: Sim.Sim, n: number, each: ((number) -> ())?)
	for i = 1, n do
		Sim.step(sim)
		if each then
			each(i)
		end
	end
end

return function(t: RunAll.Context)
	t.test("a Warden standing still unpacks in 4 s, and fires only deployed", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local warden = Spawn.unit(sim, "ord_warden", 1, -100, 0, math.pi / 2)
		local target = Spawn.unit(sim, "chs_goliath", 2, 150, 0, -math.pi / 2) -- 250 studs: in the gun's range
		World.setFireState(w, target, World.FireState.HOLD_FIRE)
		World.setHealth(w, target, 1e6)
		local firstShot, deployedAt = nil, nil
		steps(sim, 120, function(i)
			if deployedAt == nil and bit32.band(w.state[warden], DEPLOYED) ~= 0 then
				deployedAt = i
			end
			if i < 58 then
				t.expect(bit32.band(w.state[warden], DEPLOYED) == 0, `not deployed yet at tick {i}`)
				t.expect(i < 2 or bit32.band(w.state[warden], DEPLOYING) ~= 0, `unpacking at tick {i}`)
			end
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == warden and firstShot == nil then
					firstShot = i
				end
			end
		end)
		t.expect(deployedAt ~= nil and math.abs(deployedAt - 60) <= 2, `deployed after 4 s (tick {deployedAt})`)
		t.expect(firstShot ~= nil and firstShot >= (deployedAt :: number), `first shot at tick {firstShot}, once deployed`)
		t.equal(bit32.band(w.state[warden], DEPLOYING), 0, "no longer unpacking")
	end)

	t.test("a move order packs the Warden for 4 s, then it drives off", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local warden = Spawn.unit(sim, "ord_warden", 1, 0, 0, math.pi / 2)
		steps(sim, 70)
		t.equal(w.deploy[warden], 1, "deployed")
		local x0 = w.posX[warden]
		command(sim, 1, { warden }, CT.MOVE, 120, 0)
		local movedAt = nil
		steps(sim, 150, function(i)
			if movedAt == nil and math.abs(w.posX[warden] - x0) > 0.5 then
				movedAt = i
			end
		end)
		t.expect(movedAt ~= nil and movedAt >= 58 and movedAt <= 66, `held still while packing, moved at tick {movedAt}`)
		t.equal(w.deploy[warden], 0, "packed")
	end)

	t.test("a deployed Warden takes damage / 1.5 and isn't pushed", function()
		local sim = Sim.new({ seed = 3, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local warden = Spawn.unit(sim, "ord_warden", 1, 0, 0, 0)
		local packed = Spawn.unit(sim, "ord_warden", 1, 0, 60, 0)
		World.setFireState(w, warden, World.FireState.HOLD_FIRE)
		steps(sim, 70)
		local h = w.health[warden]
		Combat.queueDamage(sim.combat, warden, 300, 0)
		Sim.step(sim)
		t.expect(math.abs(h - w.health[warden] - 200) < 1e-6, `300 damage took {h - w.health[warden]}`)
		-- a tank driving through the deployed Warden's spot goes round it
		local x0, z0 = w.posX[warden], w.posZ[warden]
		local tank = Spawn.unit(sim, "ord_lancer", 1, -40, 0, math.pi / 2)
		command(sim, 1, { tank }, CT.MOVE, 40, 0)
		steps(sim, 120)
		t.equal(w.posX[warden], x0, "not pushed (x)")
		t.equal(w.posZ[warden], z0, "not pushed (z)")
		t.expect(w.deploy[packed] == 1, "an idle Warden deploys on its own")
	end)

	t.test("on an attack-move the Warden holds to engage, deploys and fires", function()
		local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local warden = Spawn.unit(sim, "ord_warden", 1, -300, 0, math.pi / 2)
		local target = Spawn.unit(sim, "chs_ravager", 2, 200, 0, -math.pi / 2)
		World.setFireState(w, target, World.FireState.HOLD_FIRE)
		World.setHealth(w, target, 1e6)
		command(sim, 1, { warden }, CT.FIGHT, 200, 0)
		local shots = 0
		steps(sim, 900, function()
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == warden then
					shots += 1
				end
			end
		end)
		local d = math.abs(w.posX[target] - w.posX[warden])
		t.expect(shots >= 5, `it fired ({shots} shots)`)
		t.equal(w.deploy[warden], 1, "deployed while engaged")
		t.expect(d > 200 and d <= 290, `it stopped at its range ({d} studs off)`)
	end)

	t.test("the Minotaur's demolition charge levels a structure up close, and ignores units", function()
		local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:64" })
		local w = sim.world
		local defs = sim.defs
		t.equal(defs.weapons.chs_ram_cannon.damage.STRUCTURE, defs.weapons.chs_ram_cannon.damage.LIGHT * 1.5, "its gun does +50% to structures")
		local minotaur = Spawn.unit(sim, "chs_minotaur", 2, 0, 0, math.pi / 2)
		local bunker = Spawn.unit(sim, "ord_bulwark", 1, 30, 0, 0) -- 1,800 health, inside the charge's reach
		local tank = Spawn.unit(sim, "ord_lancer", 1, -25, 0, 0)
		World.setFireState(w, bunker, World.FireState.HOLD_FIRE)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setHealth(w, tank, 1e6)
		local charges = {}
		steps(sim, 120, function()
			for _, e in sim.combat.events do
				if e.kind == "FIRE" and e.unit == minotaur and e.slot == 2 then
					table.insert(charges, e.other)
				end
			end
		end)
		t.expect(not World.isAlive(w, bunker), "the Bulwark is gone")
		t.expect(#charges >= 1 and charges[1] == bunker, `the charge went off on the Bulwark ({#charges})`)
		t.expect(#charges == 1, "one charge in 8 s (20 s reload); none at the tank")
	end)
end

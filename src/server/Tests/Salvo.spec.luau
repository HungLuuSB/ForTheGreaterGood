--!strict
-- Weapons depth (S-69, audit item 7): salvos, and shells that lead moving
-- targets.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("an MLRS fires its salvo, delay apart, then reloads from the first rocket", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local hydra = Spawn.unit(sim, "chs_hydra", 2, 200, 0, -math.pi / 2)
		local target = Spawn.unit(sim, "ord_bulwark", 1, 60, 0) -- a structure 140 studs off: in sight and range
		World.setFireState(w, target, World.FireState.HOLD_FIRE)
		World.setHealth(w, target, 1e6)
		local ticks = {}
		for _ = 1, 150 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == hydra then
					table.insert(ticks, sim.tick)
				end
			end
		end
		local weapon = sim.defs.weapons.chs_mlrs
		local salvo = weapon.salvo :: { count: number, delay: number }
		t.expect(#ticks >= salvo.count * 2, `two salvos in 10 s ({#ticks} rockets)`)
		for i = 2, salvo.count do
			local gap = (ticks[i] - ticks[i - 1]) / 15
			t.expect(math.abs(gap - salvo.delay) <= 1 / 15 + 1e-9, `rocket {i} {gap} s after the one before`)
		end
		local cycle = (ticks[salvo.count + 1] - ticks[1]) / 15
		t.expect(math.abs(cycle - weapon.reload) <= 1 / 15 + 1e-9, `the next salvo {cycle} s after the first rocket (reload {weapon.reload})`)
	end)

	t.test("artillery leads a target driving across its line of fire", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		-- the tank crosses the gun's line of fire half its range away (S-179
		-- halved artillery range), from out of range to out of range: at full
		-- speed while the gun can reach it, stopping only beyond it
		local range = sim.defs.weapons.ord_howitzer.range
		local laneX, half = -250 + range / 2, range * 1.2
		local gun = Spawn.unit(sim, "ord_verdict", 1, -250, 0, math.pi / 2)
		local spotter = Spawn.unit(sim, "ord_herald", 1, laneX - 50, 0, math.pi / 2) -- keeps the target in sight
		World.setFireState(w, spotter, World.FireState.HOLD_FIRE)
		local tank = Spawn.unit(sim, "chs_ravager", 2, laneX, -half, 0)
		World.setFireState(w, tank, World.FireState.HOLD_FIRE)
		World.setHealth(w, tank, 1e6)
		local cell, ox, oz = (sim.map :: any).grid:encode(laneX, half)
		local wr = Packer.Writer.new()
		Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = { tank }, cell = cell, offX = ox, offZ = oz })
		assert(Sim.submit(sim, 2, wr:finish()))
		local mine: { [number]: boolean } = {}
		local shells, near = 0, 0
		for _ = 1, 270 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == gun then
					mine[e.other] = true
					shells += 1
				elseif e.kind == "IMPACT" and mine[e.other] and e.x then
					mine[e.other] = nil
					local moving = w.speed[tank] > 1
					if moving and math.sqrt((e.x - w.posX[tank]) ^ 2 + ((e.z :: number) - w.posZ[tank]) ^ 2) <= 14 then
						near += 1
					end
				end
			end
		end
		print(`    a Verdict on a Ravager crossing {range / 2} studs off: {near} of {shells} shells within 14 studs`)
		t.expect(shells >= 3, `it fired ({shells})`)
		t.expect(near >= shells - 1, `{near} of {shells} shells burst within 14 studs of the moving tank`)
	end)
end

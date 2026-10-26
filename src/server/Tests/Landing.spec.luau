--!strict
-- Landing details (S-71, guide 12.2, audit item 10): a landed aircraft is a
-- ground target, and aircraft pick a rearm pad with a free spot.
local Air = require("../Sim/Air")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local AmmoDefs = require("./Support/AmmoDefs") -- the aircraft with ammo, as before S-194
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	t.test("tanks shoot an aircraft parked on its pad, as a light ground unit; SAMs don't", function()
		local sim = Sim.new({ defs = AmmoDefs.load(), seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local pad = Spawn.unit(sim, "ord_airpad", 1, 0, 0)
		World.setHealth(w, pad, 1e6)
		local jet = Spawn.unit(sim, "ord_falcon", 1, 400, 200, 0)
		sim.air.ammo[jet] = 0
		Air.onEmpty(sim, jet) -- home to the pad, land and rearm
		for _ = 1, 3000 do
			Sim.step(sim)
			if bit32.band(w.state[jet], World.State.LANDED) ~= 0 then
				break
			end
		end
		t.expect(bit32.band(w.state[jet], World.State.LANDED) ~= 0, "it landed on the pad")
		-- in the Ravager's cannon range of the parked jet (and the Hornet's SAM range)
		local x = w.posX[jet] - sim.defs.weapons.chs_ravager_cannon.range * 0.8
		local tank = Spawn.unit(sim, "chs_ravager", 2, x, w.posZ[jet], math.pi / 2)
		local sam = Spawn.unit(sim, "chs_hornet", 2, x, w.posZ[jet] + 40, math.pi / 2)
		World.setFireState(w, pad, World.FireState.HOLD_FIRE)
		local hits, samShots = 0, 0
		local hp = w.health[jet]
		for _ = 1, 150 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "SPAWN_PROJ" and e.unit == sam and bit32.band(w.state[jet], World.State.LANDED) ~= 0 then
					samShots += 1
				end
			end
			if not World.isAlive(w, jet) or bit32.band(w.state[jet], World.State.LANDED) == 0 then
				break -- (rearmed, it takes off: then it's a target in the air again)
			end
		end
		hits = if World.isAlive(w, jet) then hp - w.health[jet] else hp
		t.expect(hits > 0, `the tank damaged it ({hits})`)
		t.equal(samShots, 0, "the SAM held its fire while it sat on the pad")
	end)

	t.test("an empty aircraft skips a full pad for a free one", function()
		local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local near = Spawn.unit(sim, "ord_airpad", 1, -100, 0)
		local far = Spawn.unit(sim, "ord_airpad", 1, -400, 0)
		local pads = sim.defs.units.ord_airpad.rearmPads :: number
		for i = 1, pads do
			local other = Spawn.unit(sim, "ord_falcon", 1, -100, 50 + i * 10, 0)
			sim.air.pad[other], sim.air.padGen[other] = near, w.gen[near]
		end
		local jet = Spawn.unit(sim, "ord_falcon", 1, 0, 0, 0)
		sim.air.ammo[jet] = 0
		Air.onEmpty(sim, jet)
		t.equal(sim.air.pad[jet], far, `the near pad's {pads} spot(s) are taken: the far one`)
	end)
end

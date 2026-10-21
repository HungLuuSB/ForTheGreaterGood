--!strict
-- Fog on the client (the user's question, 2026-10-22): an enemy the client
-- draws as a model (a tactical unit) is always VISIBLE to the player's ally
-- team on the server; radar-only contacts arrive only as strategic records
-- (blips, icon 0 unless tracked) and never get a model.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sensors = require("../../src/server/Sim/Sensors")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("models only for VISIBLE enemies; radar contacts stay blips (EW scenario)", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "ew_test" })
		-- plus a clean radar case: an Order watchtower (radar 650, sight 160)
		-- and Ravagers 400 studs away, inside radar but outside anyone's sight
		Spawn.unit(sim, "ord_watchtower", 1, -300, 380)
		for k = 0, 3 do
			Spawn.unit(sim, "chs_ravager", 2, 100, 340 + k * 25, -math.pi / 2)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127))) -- the whole map in view
		local ally = sim.allyOf[sim.players[1].team]
		local tacticalEnemies, radarBlips, wrong = 0, 0, 0
		for tick = 1, 600 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.died)
			for id, u in world.units do
				if u.team == world.me.team then
					continue
				end
				if u.tier == "tactical" then
					tacticalEnemies += 1
					-- drawn as a model: the server must have it VISIBLE for our ally team
					-- (checked against this tick's sensors; a LEAVE can trail by a tick)
					local level = Sensors.level(sim, ally, id)
					if level ~= Sensors.Level.VISIBLE then
						wrong += 1
					end
				elseif bit32.band(u.flags or 0, Schema.StrategicFlag.RADAR_ONLY) ~= 0 then
					radarBlips += 1
					t.expect(u.defIndex == nil, "a radar contact never carries its def")
				end
			end
		end
		print(string.format("    600 ticks: %d tactical enemy unit-ticks (models), %d radar-blip unit-ticks, %d models not VISIBLE on the server", tacticalEnemies, radarBlips, wrong))
		t.expect(radarBlips > 0, "the scenario has radar-only contacts")
		t.expect(tacticalEnemies > 0, "and enemies in sight")
		t.expect(wrong <= tacticalEnemies * 0.02, "models only for VISIBLE enemies (a tick of LEAVE latency at most)")
	end)
end

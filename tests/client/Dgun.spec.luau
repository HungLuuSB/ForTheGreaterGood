--!strict
-- The D-Gun (S-194, the user's G5): a Commander fires it from the client
-- API (D, then a left click), and the client draws its bolt with the
-- server's to the end of its range (its one IMPACT), riding 5 studs over
-- the ground; the units it burns through die on its way (their DEATHs).

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

return function(t: any)
	t.test("a D-Gun bolt burns through a row of tanks, drawn with the server's to the end of its range", function()
		local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		local world = World.new(sim.defs)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local cmd = Spawn.unit(sim, "ord_sovereign", 1, -60, 0, math.pi / 2)
		local tanks = {}
		for i = 0, 2 do
			table.insert(tanks, Spawn.unit(sim, "chs_ravager", 2, -10 + i * 30, 0, 0))
		end
		local burned: { [number]: boolean } = {}
		for _, id in tanks do
			burned[id] = false
		end
		local fx = Effects.new()
		local tick = 0
		local function step()
			tick += 1
			local acc = sim.eco.accounts[1] -- (a shot costs 500 power)
			acc.power.storage, acc.power.stored = 1e6, 1e6
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, d in world.died do
				if burned[d.id] == false then
					burned[d.id] = true
				end
			end
			table.clear(world.died)
		end
		for _ = 1, 3 do
			step()
		end
		api.actions.select({ cmd })
		t.expect(api.actions.setCommandMode("dgun"))
		t.expect(api.actions.commandAt(100, 0, nil, false, false), "the D-Gun order went out")
		local bolt, impacts, flights, worst, heightOff = nil, 0, 0, 0, 0
		for _ = 1, 15 * 6 do
			step()
			for _, e in sim.combat.events do
				if e.kind == "IMPACT" and bolt and e.other == bolt then
					impacts += 1
				end
				if e.kind == "SPAWN_PROJ" and e.unit == cmd then
					bolt = e.other
				end
			end
			local c = sim.combat
			local p = bolt and fx.projectiles[bolt]
			if p and c.projSlot[bolt] then
				flights += 1
				worst = math.max(worst, math.sqrt((p.x - c.px[bolt]) ^ 2 + (p.z - c.pz[bolt]) ^ 2))
				heightOff = math.max(heightOff, math.abs(p.y - (World.simGroundY(world, p.x, p.z) + Effects.BOLT_HEIGHT)))
			end
		end
		local alive, deaths = 0, 0
		for _, id in tanks do
			if sim.world.slot[id] then
				alive += 1
			end
			if burned[id] then
				deaths += 1
			end
		end
		print(string.format("    bolt drawn %d ticks with the server's, at most %.2f studs off, %.2f off its riding height; %d IMPACT; %d of 3 tanks left, %d DEATHs on the client", flights, worst, heightOff, impacts, alive, deaths))
		t.expect(bolt ~= nil, "the Sovereign fired its D-Gun")
		t.equal(alive, 0, "every tank on its path burned")
		t.equal(deaths, 3, "the client saw each tank die on the bolt's path")
		t.equal(impacts, 1, "the bolt's one IMPACT, at the end of its range")
		t.expect(flights >= 25, `drawn on through the tanks to the end of its range ({flights} ticks)`)
		t.expect(worst < 1, `with the server's bolt ({worst})`)
		t.expect(heightOff < 1e-6, "riding 5 studs over the ground")
		t.equal(fx.projectiles[bolt :: number], nil, "gone at the end")
	end)
end

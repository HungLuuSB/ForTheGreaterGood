--!strict
-- Radar accuracy in the sensor view (C-181, S-147): the Eco record's
-- numbers become a circle round each radar blip, the radius radar-fired
-- shots miss by; Pinpointers shrink it; the readout says so.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local RadarAccuracy = require("../../src/client/Core/RadarAccuracy")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sensors = require("../../src/server/Sim/Sensors")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")

return function(t: any)
	t.test("a circle the server's miss radius round each radar blip; Pinpointers shrink it", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
		Spawn.unit(sim, "ord_beacon", 1, -200, 0, 0)
		local tank = Spawn.unit(sim, "chs_ravager", 2, 120, 0, 0)
		sim.world.fireState[tank] = ServerWorld.FireState.HOLD_FIRE
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local tick = 0
		local function run(n: number)
			for _ = 1, n do
				tick += 1
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick / 15)
			end
		end
		run(30)
		local acc = RadarAccuracy.of(world.economy)
		t.expect(acc ~= nil and acc.radar ~= nil, "the Eco record brought the radar accuracy")
		local a = acc :: RadarAccuracy.Accuracy
		local ally = sim.players[1].allyTeam
		t.expect(math.abs((a.radar :: number) - sim.sensors.radarError[ally]) <= 0.05, `the server's radius ({a.radar} vs {sim.sensors.radarError[ally]})`)
		t.equal(a.precision, 0)
		local rings = RadarAccuracy.rings(world, a)
		t.equal(#rings, 1, "the tank is a radar blip with a circle")
		t.equal(rings[1].id, tank)
		t.equal(rings[1].radius, a.radar)
		t.expect(not rings[1].tracked)
		local before = RadarAccuracy.readout(a)
		t.expect(string.find(before, "Radar accuracy ±", 1, true) ~= nil and string.find(before, "no Pinpointers", 1, true) ~= nil, before)
		-- two Pinpointers: the circle shrinks by the server's scale
		Spawn.unit(sim, "ord_witness", 1, -220, -60, 0)
		Spawn.unit(sim, "ord_witness", 1, -220, 60, 0)
		run(30)
		local b = RadarAccuracy.of(world.economy) :: RadarAccuracy.Accuracy
		local p = Sensors.precision(sim.sensors, ally)
		t.expect(p > 0 and math.abs(b.precision - p) <= 1 / 255, `precision {b.precision} vs {p}`)
		t.expect((b.radar :: number) < (a.radar :: number), `smaller with Pinpointers ({b.radar} < {a.radar})`)
		t.equal(RadarAccuracy.rings(world, b)[1].radius, b.radar)
		local after = RadarAccuracy.readout(b)
		t.expect(string.find(after, string.format("Pinpointers %d%%", math.floor(p * 100 + 0.5)), 1, true) ~= nil, after)
		print(`    {before}\n    {after}`)
	end)

	t.test("no radar: no circles, and the readout says so", function()
		t.equal(RadarAccuracy.readout(nil), "Radar accuracy: no radar")
		local acc = RadarAccuracy.of({ team = 1, supply = {} :: any, power = {} :: any, wind = 0, radarError = 0, trackError = 0, precision = 0 })
		t.equal(RadarAccuracy.readout(acc), "Radar accuracy: no radar")
		local tracked = RadarAccuracy.of({ team = 1, supply = {} :: any, power = {} :: any, wind = 0, radarError = 160, trackError = 4, precision = 128 }) :: RadarAccuracy.Accuracy
		t.equal(RadarAccuracy.readout(tracked), "Radar accuracy ±16 studs  ·  tracked ±0.4  ·  Pinpointers 50%")
		t.equal(RadarAccuracy.readout(tracked, true), "Radar accuracy ±16 studs  ·  tracked ±0.4  ·  Pinpointers 50%")
		t.equal(RadarAccuracy.readout(tracked, false), `Radar accuracy ±16 studs  ·  <font color="{RadarAccuracy.GREY}">tracked ±0.4</font>  ·  Pinpointers 50%`, "greyed while no blip is tracked")
	end)
end

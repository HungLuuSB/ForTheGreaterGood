--!strict
-- Water splashes (C-82): shells that end at the water surface make splash
-- bursts (the renderer draws a column, spray and foam instead of fire and
-- dust); impacts on land don't.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

local function fight(mapId: string, a: string, b: string, gap: number): (number, number)
	local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = mapId, scenario = "empty" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	for i = 0, 2 do
		Spawn.unit(sim, a, 1, -gap / 2, -30 + i * 30, math.pi / 2)
		Spawn.unit(sim, b, 2, gap / 2, -30 + i * 30, -math.pi / 2)
	end
	local fx = Effects.new()
	local splashes, impacts = 0, 0
	local seen: { [any]: boolean } = {}
	for tick = 1, 15 * 25 do
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		Effects.update(fx, world, tick, tick * DT, 0, 0)
		for _, burst in fx.bursts do
			if burst.kind == "impact" and not seen[burst] then
				seen[burst] = true
				impacts += 1
				if burst.water then
					splashes += 1
					assert(math.abs(burst.water - burst.y) <= Effects.SPLASH_ABOVE + 1, "the splash sits on the surface")
				end
			end
		end
		table.clear(world.died)
	end
	return splashes, impacts
end

return function(t: any)
	t.test("shells landing in the sea splash; on land they don't", function()
		local seaSplash, seaImpacts = fight("sea:64", "ord_sentry", "chs_barracuda", 160)
		t.expect(seaImpacts > 0, "the corvettes fought")
		t.expect(seaSplash > 0, `misses splash ({seaSplash} of {seaImpacts} impacts)`)
		t.expect(seaSplash < seaImpacts, "hits on the ships explode")
		local landSplash, landImpacts = fight("flat:64", "ord_lancer", "chs_ravager", 140)
		t.expect(landImpacts > 0, "the tanks fought")
		t.equal(landSplash, 0, "no splashes on land")
		print(string.format("    sea: %d of %d impacts splash; land: %d of %d", seaSplash, seaImpacts, landSplash, landImpacts))
	end)
end

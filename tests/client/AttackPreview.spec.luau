--!strict
-- Attack mode's arc preview (C-58, S-51): the path drawn for a selected silo is
-- the path its nuke then flies on the server, its flight time and apex.

local AttackPreview = require("../../src/client/Core/AttackPreview")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local TX, TZ = 450, 300

return function(t: any)
	t.test("the previewed arc is the nuke's flight", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:256", scenario = "empty" })
		local silo = Spawn.unit(sim, "ord_reckoning", 1, -800, -100, 0)
		Spawn.unit(sim, "ord_lancer", 1, -700, -100, 0)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, DT)

		-- an enemy unit and no lofted weapon: no arcs
		t.equal(#AttackPreview.arcs(world, {}, TX, TZ), 0)
		local arcs = AttackPreview.arcs(world, { silo }, TX, TZ)
		t.equal(#arcs, 1)
		local arc = arcs[1]
		t.expect(arc.inRange, "the spot is in range")
		t.equal(arc.stock, 2)
		local last = arc.points[#arc.points]
		t.expect(math.abs(last[1] - TX) < 1 and math.abs(last[3] - TZ) < 1, `the arc ends on the spot ({last[1]}, {last[3]})`)

		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.ATTACK_GROUND, { silo }, TX, TZ)))
		local worst, peak, born, ended, compared = 0, -math.huge, nil, nil, 0
		local leaned: number? = nil
		local c = sim.combat
		for tick = 2, 15 * 25 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "IMPACT" and born then
					ended = tick
				end
			end
			for id in c.projSlot do
				born = born or tick
				local age = tick - (born :: number) + 1 -- steps the server has taken
				if leaned == nil and (c.pvx[id] ~= 0 or c.pvz[id] ~= 0) then
					leaned = c.py[id]
				end
				if age % AttackPreview.EVERY == 0 then
					local q = arc.points[age // AttackPreview.EVERY + 1]
					if q then
						compared += 1
						worst = math.max(worst, math.sqrt((c.px[id] - q[1]) ^ 2 + (c.py[id] - q[2]) ^ 2 + (c.pz[id] - q[3]) ^ 2))
					end
				end
				peak = math.max(peak, c.py[id])
			end
			if ended then
				break
			end
		end
		t.expect(born ~= nil and ended ~= nil, "the nuke flew and landed")
		local flown = ((ended :: number) - (born :: number)) * DT
		print(string.format("    preview: %.2f s, apex %.0f; server: %.2f s, apex %.0f, leans over at %.0f; %d points compared, worst %.2f studs", arc.seconds, arc.apexY, flown, peak, leaned or -1, compared, worst))
		t.expect(compared > 50 and worst < 1, `the server's nuke follows the previewed path (worst {worst} studs)`)
		t.expect(math.abs(flown - arc.seconds) < 0.2, `flight time {arc.seconds} s, flown {flown} s`)
		t.expect(math.abs(peak - arc.apexY) < 1, `apex {arc.apexY}, flown {peak}`)
	end)

	t.test("a bomber's carpet: the preview's spots are where its salvo lands (S-178, F33)", function()
		local sim = Sim.new({ seed = 9, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		local bomber = Spawn.unit(sim, "ord_absolution", 1, -380, 0, math.pi / 2)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, DT)
		local tx, tz = 120, 0 -- dead ahead: a straight run
		local carpets = AttackPreview.carpets(world, { bomber }, tx, tz)
		t.equal(#carpets, 1)
		local pts = carpets[1].points
		t.equal(#pts, 3, "three bombs")
		local w = carpets[1].weapon
		local step = w.salvo.delay * sim.defs.units.ord_absolution.movement.maxSpeed
		t.expect(math.abs(math.sqrt((pts[2][1] - pts[1][1]) ^ 2 + (pts[2][2] - pts[1][2]) ^ 2) - step) < 1e-6, "salvo.delay x speed apart")
		t.deepEqual({ pts[1][1], pts[1][2] }, { tx, tz }, "the first on the spot")
		-- the server's run: where the three bombs burst
		local cell, ox, oz = g:encode(tx, tz)
		assert(Sim.submit(sim, 1, Commands.encode({ cmdType = Schema.CmdType.ATTACK_GROUND, flags = 0, unitIds = { bomber }, cell = cell, offX = ox, offZ = oz })))
		local impacts = {}
		for _ = 1, 15 * 20 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "IMPACT" and e.x then
					table.insert(impacts, { e.x, e.z })
				end
			end
			if #impacts >= 3 then
				break
			end
		end
		t.expect(#impacts >= 3, `the salvo landed ({#impacts})`)
		-- the first bomb on the spot, each next one salvo.delay x speed on
		-- (the server's bomber still turns away during its salvo: until it
		-- holds its heading, sim-A, only the first spot is checked exactly)
		local first = math.sqrt((impacts[1][1] - tx) ^ 2 + (impacts[1][2] - tz) ^ 2)
		local gap = math.sqrt((impacts[2][1] - impacts[1][1]) ^ 2 + (impacts[2][2] - impacts[1][2]) ^ 2)
		print(string.format("    carpet: first bomb %.1f studs from the spot (blast %d), the next %.1f on (previewed %.1f)", first, w.aoe, gap, step))
		t.expect(first <= w.aoe, `the first bomb inside the first ring ({first})`)
		t.expect(math.abs(gap - step) <= w.aoe, `the bombs' spacing is the preview's ({gap} vs {step})`)
	end)
end

--!strict
-- Attack mode's arc preview (C-58): the arc drawn for a selected silo is
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
		t.expect(math.abs(last[1] - TX) < 1e-6 and math.abs(last[3] - TZ) < 1e-6, "the arc ends on the spot")

		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.ATTACK_GROUND, { silo }, TX, TZ)))
		local x0, z0 = arc.points[1][1], arc.points[1][3]
		local total = math.sqrt((TX - x0) ^ 2 + (TZ - z0) ^ 2)
		local worst, peak, born, ended = 0, -math.huge, nil, nil
		local c = sim.combat
		for tick = 2, 15 * 20 do
			Sim.step(sim)
			for _, e in c.events do
				if e.kind == "IMPACT" and born then
					ended = tick
				end
			end
			for id in c.projSlot do
				born = born or tick
				local frac = math.sqrt((c.px[id] - x0) ^ 2 + (c.pz[id] - z0) ^ 2) / total
				-- the arc's height at the same share of the way
				local s = frac * arc.seconds
				local yArc = arc.points[1][2] + math.sqrt(2 * arc.weapon.gravity * arc.weapon.apex) * s - 0.5 * arc.weapon.gravity * s * s
				worst = math.max(worst, math.abs(c.py[id] - yArc))
				peak = math.max(peak, c.py[id])
			end
			if ended then
				break
			end
		end
		t.expect(born ~= nil and ended ~= nil, "the nuke flew and landed")
		local flown = ((ended :: number) - (born :: number)) * DT
		print(string.format("    preview: %.2f s, apex %.0f; server: %.2f s, apex %.0f; worst height gap %.2f studs", arc.seconds, arc.apexY, flown, peak, worst))
		t.expect(worst < 3, `the server's nuke follows the arc (worst {worst} studs off)`)
		t.expect(math.abs(flown - arc.seconds) < 0.2, `flight time {arc.seconds} s, flown {flown} s`)
		t.expect(math.abs(peak - arc.apexY) < 3, `apex {arc.apexY}, flown {peak}`)
	end)
end

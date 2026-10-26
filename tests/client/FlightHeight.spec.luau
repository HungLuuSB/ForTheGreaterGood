--!strict
-- An aircraft's drawn height (G16, the user's playtest: a plane crossing a
-- mountain on Twin Lakes snapped instead of climbing): the snapshots' own
-- heights interpolated, smooth where ground(x(t)) + alt(t) spikes as a
-- cliff passes under the plane between two snapshots.

local Commands = require("../../src/client/Core/Commands")
local Interp = require("../../src/client/Core/Interp")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("a plane over a cliff: its height moves no faster than the sim climbs (G16)", function()
		-- ground: a 40-stud cliff at x = 100; the sim keeps the plane at an
		-- absolute 120 (alt 120 before the cliff, 80 after), as it flies
		local function ground(x: number, _z: number): number
			return if x < 100 then 0 else 40
		end
		local snaps = {}
		for tick = 0, 10 do
			local x = tick * 24 -- 24 studs a tick: the cliff falls between ticks 4 and 5
			table.insert(snaps, { tick = tick, x = x, z = 0, alt = 120 - ground(x, 0), heading = 0 })
		end
		local unit: any = { snaps = snaps, x = 240, z = 0, alt = 80, heading = 0, state = World.State.MOVING }
		local worstNew, worstOld = 0, 0
		local prevNew, prevOld = nil, nil
		for step = 0, 100 do
			local rt = step / 10
			local x, z, alt = Interp.sample(unit, rt)
			local yNew = Interp.height(unit, rt, ground)
			local yOld = ground(x, z) + alt
			if prevNew then
				worstNew = math.max(worstNew, math.abs(yNew - prevNew))
				worstOld = math.max(worstOld, math.abs(yOld - (prevOld :: number)))
			end
			prevNew, prevOld = yNew, yOld
		end
		print(string.format("    largest change in a tenth of a tick: interpolated heights %.2f, ground + alt %.2f", worstNew, worstOld))
		t.expect(worstNew < 0.01, `steady at 120 ({worstNew})`)
		t.expect(worstOld > 10, "the old way spiked at the cliff (why this exists)")
	end)

	t.test("a Falcon over Twin Lakes' highest peak, drawn from the wire: no faster than the sim climbs (G16)", function()
		local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "map:twin_lakes", scenario = "empty" })
		local f = Spawn.unit(sim, "ord_falcon", 1, -76, -1000, 0)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.MOVE, { f }, -76, -150)))
		local function ground(x: number, z: number): number
			return World.simGroundY(world, x, z)
		end
		local SUBS = 6
		local worst, smooth, prev, flown = 0, 0, nil, 0
		for tick = 1, 15 * 14 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local u = world.units[f]
			if u and u.tier == "tactical" and tick > 3 then
				for k = 1, SUBS do
					local rt = tick - 2 + k / SUBS -- drawn two ticks behind, as Interp.DELAY_TICKS
					local x, z, alt = Interp.sample(u, rt)
					local y = Interp.height(u, rt, ground)
					if prev then
						worst = math.max(worst, math.abs(y - prev[1]))
						smooth = math.max(smooth, math.abs((World.groundY(world, x, z) + alt) - prev[2]))
					end
					prev = { y, World.groundY(world, x, z) + alt }
					flown += 1
				end
			end
		end
		-- the sim's climb a tick (40 studs/s), plus the wire's whole-stud
		-- altitude (up to half a stud off each snapshot), per render step
		local limit = (40 / 15 + 1) / SUBS
		print(string.format("    %d steps over the peak: largest step %.2f (limit %.2f); smooth ground + alt: %.2f", flown, worst, limit, smooth))
		t.expect(flown > 600, "it flew")
		t.expect(worst <= limit, `as smooth as the sim's climb ({worst})`)
		t.expect(smooth > 4 * limit, "drawn on the smooth ground it zigzagged (why this exists)")
	end)

end

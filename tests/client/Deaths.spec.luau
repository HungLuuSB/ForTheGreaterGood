--!strict
-- Deaths and wrecks (guide 14.6, C-34): a death that leaves a wreck shakes
-- and then shows the wreck; a big overkill (no wreck) flings 1–3 jointed
-- pieces up and away, the same way each time for the same unit; and every
-- death of a real duel gets the plan its DEATH event calls for.

local Commands = require("../../src/client/Core/Commands")
local Deaths = require("../../src/client/Core/Deaths")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Defs = require("@shared/Defs/Defs")

local DT = 1 / 15
local defs = Defs.load()

return function(t: any)
	t.test("a wreck means a shake; no wreck means flung pieces", function()
		local def = defs.units.chs_juggernaut
		local shake = Deaths.plan(4, def, 60, 17)
		t.equal(shake.kind, "shake")
		t.expect(shake.wreck and #shake.pieces == 0)
		local fling = Deaths.plan(4, def, 230, 0)
		t.equal(fling.kind, "fling")
		t.expect(not fling.wreck, "nothing left")
		t.expect(#fling.pieces >= 1 and #fling.pieces <= Deaths.MAX_PIECES, `1–3 pieces ({#fling.pieces})`)
		local seen = {}
		for _, p in fling.pieces do
			t.expect(table.find(def.pieces, p.name) ~= nil and p.name ~= "base" and p.name ~= "muzzle", `{p.name} is a jointed piece`)
			t.expect(not seen[p.name], "each piece once")
			seen[p.name] = true
			-- up, then back down past where it started within the animation
			local _, yMid = Deaths.pieceAt(p, Deaths.FLING_SECONDS / 2)
			local _, yEnd = Deaths.pieceAt(p, Deaths.FLING_SECONDS)
			t.expect(yMid > 3, "flies up")
			t.expect(yEnd < yMid, "and falls")
		end
		local again = Deaths.plan(4, def, 230, 0)
		t.deepEqual(again, fling, "the same death plays the same way")
		local sx, sz = Deaths.shakeAt(4, 0)
		local ex, ez = Deaths.shakeAt(4, Deaths.SHAKE_SECONDS)
		t.expect(math.abs(sx) + math.abs(sz) > 0 and ex == 0 and ez == 0, "the shake eases out")
	end)

	t.test("every death in a duel gets the plan its DEATH event calls for", function()
		local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
		local deaths, shakes, flings = 0, 0, 0
		for tick = 1, 400 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, d in world.died do
				deaths += 1
				local def = sim.defs.unitByIndex[d.defIndex :: number]
				local plan = Deaths.plan(d.id, def, d.severity, d.wreckId)
				-- the server leaves a wreck only for an overkill of at most half the max health
				t.equal(plan.wreck, d.wreckId ~= 0)
				if d.wreckId ~= 0 then
					t.expect(d.severity <= 0.5 * 255 + 1, `a wreck only after a small overkill ({d.severity})`)
					shakes += 1
				else
					flings += 1
				end
			end
			table.clear(world.died)
		end
		print(string.format("    duel: %d deaths, %d shakes into wrecks, %d flung apart", deaths, shakes, flings))
		t.expect(deaths > 5, "plenty of deaths")
	end)
end

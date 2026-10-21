--!strict
-- Health bars and hits (C-49): a health change shows when the render clock
-- reaches the tick it happened on, with the explosion of the hit that caused
-- it, not when its State record arrives (the render clock runs ~2 ticks
-- behind the newest record).

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15
local LAG = 2 -- render ticks behind the newest record, as the client runs

return function(t: any)
	t.test("SAM hits on jets: the bar drops on the hit's tick, never before", function()
		local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		local jets = {}
		for i = 0, 3 do
			table.insert(jets, Spawn.unit(sim, "ord_falcon", 1, -60, -60 + i * 40, math.pi / 2))
			Spawn.unit(sim, "chs_thorn", 2, -100 + (i % 2) * 200, -100 + (i // 2) * 200, 0)
		end
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
		local hitTicks: { [number]: { number } } = {}
		local shown: { [number]: number } = {}
		local drops, early, late = 0, 0, 0
		for tick = 1, 15 * 20 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "IMPACT" and e.unit ~= 0 and table.find(jets, e.unit) then
					hitTicks[e.unit] = hitTicks[e.unit] or {}
					table.insert(hitTicks[e.unit], tick)
				end
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local rt = tick - LAG
			World.settle(world, rt)
			for _, id in jets do
				local u = world.units[id]
				local h = u and World.shownHealth(world, u)
				if h and shown[id] and h < shown[id] - 1e-6 then
					drops += 1
					-- the hit that caused it: the latest at or before the render tick
					local prior: number? = nil
					for _, ht in hitTicks[id] or {} do
						if ht <= rt then
							prior = ht
						end
					end
					if prior == nil then
						early += 1 -- shown before any hit's tick came round
					elseif rt - prior > 1 then
						late += 1
					end
				end
				if h then
					shown[id] = h
				end
			end
		end
		print(string.format("    %d bar drops on hit jets: %d before their hit's tick, %d more than a tick from a hit", drops, early, late))
		t.expect(drops >= 5, "jets were hit and their bars dropped")
		t.equal(early, 0)
		t.equal(late, 0)
		-- without settling (or before it) the latest health is what's known
		local w2 = World.new(sim.defs)
		t.expect(w2.shownTick == nil, "a world that never settles shows the latest health")
	end)
end

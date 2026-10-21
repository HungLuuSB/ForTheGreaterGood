--!strict
-- The target line's target: own units' targets from the wire equal the
-- server's every tick (C-25); without them (an ally's units) the guess
-- from the turret aim (C-20) mostly matches.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Targets = require("../../src/client/Core/Targets")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local ServerWorld = require("../../src/server/Sim/World")

local DT = 1 / 15

return function(t: any)
	-- the server's target the line should show: the first weapon slot with
	-- one; a target that died this tick (kept until the next targeting pass)
	-- shows no line
	local function serverTarget(sim: any, id: number): number
		for slot = 1, sim.world.weaponCount[id] or 0 do
			local tg = sim.world.wTarget[ServerWorld.slotKey(id, slot)] or 0
			if tg ~= 0 then
				return if sim.world.slot[tg] ~= nil then tg else 0
			end
		end
		return 0
	end

	local function duel(each: (sim: any, world: World.World) -> ())
		local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
		for tick = 1, 200 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.died)
			each(sim, world)
		end
	end

	t.test("own units' targets from the wire equal the server's, every tick", function()
		local checked, engaged = 0, 0
		duel(function(sim, world)
			for _, id in World.ownIds(world) do
				local real = serverTarget(sim, id)
				local shown = Targets.of(world, id)
				t.equal(shown or 0, real, `unit {id} at tick {sim.tick}`)
				checked += 1
				if real ~= 0 then
					engaged += 1
				end
			end
		end)
		t.expect(engaged > 100, `plenty of engaged ticks ({engaged} of {checked})`)
	end)

	t.test("without wire targets (an ally's units) the aim guess mostly matches", function()
		local checked, agreed = 0, 0
		duel(function(sim, world)
			for _, id in World.ownIds(world) do
				world.units[id].targets = nil -- as for a unit whose targets aren't sent
				local guess = Targets.of(world, id)
				local real = sim.world.wTarget[ServerWorld.slotKey(id, 1)] or 0
				if guess ~= nil and real ~= 0 then
					checked += 1
					if guess == real then
						agreed += 1
					end
				end
			end
		end)
		print(string.format("    %d of %d guesses equal the server's target", agreed, checked))
		t.expect(checked > 100, "plenty of engaged ticks")
		t.expect(agreed / checked >= 0.9, `at least 90 % agree ({agreed} / {checked})`)
	end)

	t.test("an attack order is the target, exactly", function()
		local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local api = Api.new(world, function(p: buffer)
			assert(Sim.submit(sim, 1, p))
		end)
		api.send(Commands.camera(0, 0, 47, 47))
		for tick = 1, 2 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		end
		local own = World.ownIds(world)
		local enemy
		for id, u in world.units do
			if u.team == 2 then
				enemy = id
			end
		end
		api.actions.select({ own[1] })
		api.actions.order("attack", enemy, false)
		t.equal(Targets.of(world, own[1], api.waypoints.byUnit), enemy)
		t.equal(Targets.of(world, own[2], api.waypoints.byUnit), nil, "idle at the start: no target yet")
	end)
end

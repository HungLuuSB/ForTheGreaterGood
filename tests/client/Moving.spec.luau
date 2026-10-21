--!strict
-- Moving units (C-45): the server doesn't set the MOVING state bit, so the
-- client tells movement from its position records. A move line (Waypoints)
-- stays until the unit gets there, for a tank and for a jet, and goes once
-- the unit stands still.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Waypoints = require("../../src/client/Core/Waypoints")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Air = require("../../src/server/Sim/Air")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local CT = Schema.CmdType

local function scene(def: string, startX: number?)
	local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
	local id = Spawn.unit(sim, def, 1, startX or -300, 0, math.pi / 2)
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, 127, 127)))
	return sim, world, id
end

return function(t: any)
	t.test("aircraft reach their point where the server says they arrive", function()
		t.equal(Waypoints.AIR_REACH, Air.LOITER_RADIUS)
	end)

	-- the jet arrives at the loiter radius and circles from then on
	for _, case in { { def = "ord_lancer", x = 100, seconds = 40, near = 40 }, { def = "ord_falcon", from = -480, x = 480, seconds = 20, near = 220 } } do
		t.test(`{case.def}: moving while it drives or flies to the point, its move line lasting until it gets there`, function()
			local sim, world, id = scene(case.def, case.from)
			local wp = Waypoints.new()
			local moving, still, reachedAt, droppedAt = 0, 0, nil, nil
			for tick = 1, 15 * case.seconds do
				if tick == 2 then
					assert(Sim.submit(sim, 1, Commands.toPoint(world.grid, CT.MOVE, { id }, case.x, 0)))
					Waypoints.issue(wp, world, { cmdType = CT.MOVE, queue = false, x = case.x, z = 0 }, { id })
				end
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				Waypoints.update(wp, world, tick * DT)
				local u = world.units[id]
				t.equal(bit32.band(u.state, World.State.MOVING), 0) -- the server still doesn't set it
				local sx, sz = sim.world.posX[id], sim.world.posZ[id]
				local near = (sx - case.x) ^ 2 + sz ^ 2 < case.near ^ 2
				if reachedAt == nil and near then
					reachedAt = tick
				end
				if tick > 4 and reachedAt == nil then
					if World.moving(world, u) then
						moving += 1
					else
						still += 1
					end
					t.expect(wp.byUnit[id] ~= nil, `the move line is still there at tick {tick}, before the unit got there`)
				end
				if droppedAt == nil and tick > 2 and wp.byUnit[id] == nil then
					droppedAt = tick
				end
			end
			print(string.format("    %s: moving %d of %d ticks on the way, there at tick %s, line gone at tick %s", case.def, moving, moving + still, tostring(reachedAt), tostring(droppedAt)))
			t.expect(reachedAt ~= nil, "it got there")
			t.expect(still == 0, "moving on every tick of the way")
			t.expect((reachedAt :: number) > 2 + 15 * Waypoints.IDLE_SECONDS, "the trip takes longer than the idle timeout that used to drop the line")
			t.expect(droppedAt ~= nil and droppedAt >= (reachedAt :: number) - 15, "the line goes when it gets there, not before")
		end)
	end

	t.test("a unit that stops counts as standing still within MOVING_TICKS", function()
		local sim, world, id = scene("ord_lancer")
		assert(Sim.submit(sim, 1, Commands.toPoint(world.grid, CT.MOVE, { id }, -250, 0)))
		local stoppedAt
		for tick = 1, 15 * 20 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			local u = world.units[id]
			if stoppedAt == nil and tick > 15 and not World.moving(world, u) then
				stoppedAt = tick
			end
		end
		t.expect(stoppedAt ~= nil, "it stopped")
		t.expect(world.latestTick - (world.units[id].movedTick :: number) > World.MOVING_TICKS.tactical, "no movement since")
	end)
end

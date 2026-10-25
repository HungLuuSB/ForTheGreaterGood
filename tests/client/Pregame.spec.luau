--!strict
-- The pre-game on the client (C-218, net.md 9b, S-169): the real Sim with
-- startMode "choose" through NetOut → NetIn. The client's spawn boxes are
-- the server's; picks, ready flags and the countdown arrive; a pick outside
-- the own box is refused before it's sent; the match starts on COUNTDOWN 0
-- with the Commanders on the picks.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Pregame = require("../../src/client/Core/Pregame")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local ServerPregame = require("../../src/server/Sim/Pregame")
local Sim = require("../../src/server/Sim/Sim")

local DT = 1 / 15

local function newMatch()
	local sim = Sim.new({
		seed = 3,
		players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 2 } },
		mapId = "map:ridgeline",
		scenario = "standard_start",
		match = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose" },
	})
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, math.min(g.cellsX, 256) - 1, math.min(g.cellsZ, 256) - 1)))
	return sim, world
end

local function step(sim: any, world: any, n: number?)
	for _ = 1, n or 1 do
		Sim.step(sim)
		NetIn.applyOutbox(world, sim.net.players[1].outbox, sim.tick * DT)
	end
end

return function(t: any)
	t.test("the client's timeout is the server's", function()
		t.equal(Pregame.TIMEOUT, ServerPregame.TIMEOUT)
	end)

	t.test("spawn boxes and hints match the server's; picks, ready and the countdown arrive; the match starts on 0", function()
		local sim, world = newMatch()
		step(sim, world)
		local pg = world.pregame
		t.expect(pg.active and not pg.started, "the pre-game is on")
		t.equal(next(world.units), nil, "no units yet")
		local areas = Pregame.areas(world)
		assert(areas, "areas")
		t.deepEqual(areas.boxes, sim.pregame.boxes, "the same boxes the server checks with")
		t.equal(#areas.hints, #sim.map.layers.starts)
		t.expect(Pregame.areas(world) == areas, "cached")

		-- the own box's middle is pickable; the other side's isn't
		local own, other = areas.boxes[1], areas.boxes[2]
		local ox, oz = (own[1] + own[3]) / 2, (own[2] + own[4]) / 2
		t.expect(Pregame.canPick(world, areas, ox, oz), "in the own box")
		t.expect(not Pregame.canPick(world, areas, (other[1] + other[3]) / 2, (other[2] + other[4]) / 2), "the enemy's box")
		local fx, fz = Pregame.focus(world, areas)
		t.deepEqual({ fx, fz }, { ox, oz }, "the camera opens on the own box")

		-- player 1 picks the hint; player 2 picks its own
		local h1, h2 = areas.hints[1], areas.hints[#areas.hints]
		t.equal(h1.ally, 1)
		assert(Sim.submit(sim, 1, Pregame.startPos(world.grid, h1.x, h1.z)))
		assert(Sim.submit(sim, 2, Pregame.startPos(world.grid, h2.x, h2.z)))
		step(sim, world, 2)
		local p1, p2 = pg.picks[1], pg.picks[2]
		t.expect(p1 and p1.x and math.abs((p1.x :: number) - h1.x) < 1 and math.abs((p1.z :: number) - h1.z) < 1, "own pick shown")
		t.expect(p2 and p2.x ~= nil, "the enemy's pick shown too")
		t.expect(Pregame.canPick(world, areas, h1.x + 10, h1.z), "moving the own pick a little is fine")
		pg.picks[9] = { flags = 1, x = ox, z = oz } -- an ally's pick (made up)
		t.expect(not Pregame.canPick(world, areas, ox + 20, oz), "too close to another player's pick")
		pg.picks[9] = nil
		fx, fz = Pregame.focus(world, areas)
		t.expect(math.abs(fx - h1.x) < 1 and math.abs(fz - h1.z) < 1, "the camera opens on the own pick")

		-- ready both: 5..1, then 0 and the Commanders
		assert(Sim.submit(sim, 1, Pregame.ready(true)))
		assert(Sim.submit(sim, 2, Pregame.ready(true)))
		step(sim, world, 2)
		t.expect(Pregame.isReady(world, 1) and Pregame.isReady(world, 2), "both ready")
		t.equal(pg.countdown, 5)
		local seen = { [5] = true }
		for _ = 1, 6 * 15 do
			step(sim, world)
			if pg.countdown then
				seen[pg.countdown] = true
			end
			if pg.started then
				break
			end
		end
		t.expect(seen[1] and seen[3], "counted down")
		t.expect(pg.started and not pg.active, "started")
		t.equal(pg.countdown, nil)
		local commander = false
		for _, u in world.units do
			if u.team == 1 and math.abs(u.x - h1.x) < 8 and math.abs(u.z - h1.z) < 8 then
				commander = true
			end
		end
		t.expect(commander, "the Commander entered on the pick")
	end)

	t.test("un-readying cancels the countdown; a spectator can't pick", function()
		local sim, world = newMatch()
		step(sim, world)
		assert(Sim.submit(sim, 1, Pregame.ready(true)))
		assert(Sim.submit(sim, 2, Pregame.ready(true)))
		step(sim, world, 20)
		t.expect(world.pregame.countdown ~= nil, "counting")
		assert(Sim.submit(sim, 2, Pregame.ready(false)))
		step(sim, world, 2)
		t.equal(world.pregame.countdown, nil, "cancelled")
		t.expect(world.pregame.active, "still the pre-game")
		local areas = Pregame.areas(world) :: Pregame.Areas
		world.me.player = 0
		local b = areas.boxes[1]
		t.expect(not Pregame.canPick(world, areas, (b[1] + b[3]) / 2, (b[2] + b[4]) / 2), "spectators don't pick")
	end)
end

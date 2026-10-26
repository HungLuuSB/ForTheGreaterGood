--!strict
-- Placeholder minimap and resource bar (client task 9): coordinates round
-- trip, terrain tiles cover the map, dots follow knowledge, the camera box,
-- and resource text from a real Eco record (stall included).

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local Defs = require("@shared/Defs/Defs")
local Minimap = require("../../src/client/Core/Minimap")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local MapRegistry = require("@shared/Grid/MapRegistry")

local DT = 1 / 15

return function(t: any)
	t.test("coordinates round-trip; terrain tiles cover the map exactly once", function()
		local layers = MapRegistry.load("gen:11:48") :: any
		local g = layers.grid
		for _, p in { { -100, 50 }, { 0, 0 }, { 191, -191 } } do
			local u, v = Minimap.toMap(g, p[1], p[2])
			local x, z = Minimap.toWorld(g, u, v)
			t.expect(math.abs(x - p[1]) < 1e-9 and math.abs(z - p[2]) < 1e-9)
		end
		local u, v = Minimap.toMap(g, g.originX, g.originZ)
		t.expect(u == 0 and v == 0, "north-west corner is (0, 0)")
		local tiles = Minimap.terrain(layers)
		local area = 0
		for _, tile in tiles do
			area += tile.w * tile.h
		end
		t.expect(math.abs(area - 1) < 1e-9, `tiles cover the map once ({area})`)
		t.expect(#tiles < 48 * 48 / 4, `merged ({#tiles} tiles)`)
		local wet = 0
		for _, tile in tiles do
			if tile.water > 0 then
				wet += 1
			end
		end
		t.expect(wet > 0, "the generated map's lakes show")
	end)

	t.test("dots, camera box and resource lines from a live match", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 } }, mapId = "start:48", scenario = "standard_start" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local api = Api.new(world, function(payload: buffer)
			assert(Sim.submit(sim, 1, payload))
		end)
		api.send(Commands.camera(0, 0, 47, 47))
		local function run(n: number)
			for tick = sim.tick + 1, sim.tick + n do
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
				Api.frame(api, tick * DT)
			end
		end
		run(3)
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		local dots = Minimap.dots(world, api.selection.set)
		t.equal(#dots, 1, "the Command Vehicle")
		t.expect(dots[1].selected and dots[1].kind == "unit")
		t.equal(dots[1].id, cv, "each dot names its unit (the minimap draws its icon, C-122)")
		-- past the edge (an aircraft out to Grid.OVERFLY, S-189): on the minimap's edge
		local u = world.units[cv]
		local x, z, rx, rz, sx, sz = u.x, u.z, u.rx, u.rz, u.sx, u.sz
		u.x, u.z, u.rx, u.rz, u.sx, u.sz = world.grid.originX + world.grid.sizeX + 300, world.grid.originZ - 200, nil, nil, nil, nil
		local out = Minimap.dots(world, api.selection.set)[1]
		t.deepEqual({ out.u, out.v }, { 1, 0 }, "pinned to the minimap's edge")
		u.x, u.z, u.rx, u.rz, u.sx, u.sz = x, z, rx, rz, sx, sz
		local u0, v0, u1, v1 = Minimap.cameraBox(world.grid, { 0, 0, 47, 47 })
		t.deepEqual({ u0, v0, u1, v1 }, { 0, 0, 1, 1 })
		-- the economy: a full bar at the start
		local supply = Minimap.resLine("Supply", (api.state.economy :: any).supply)
		t.expect(string.find(supply.text, "Supply 1.0k / 1.0k", 1, true) ~= nil, supply.text)
		t.equal(supply.fill, 1)
		t.expect(not supply.stalling)
		-- build a lot at once: power runs dry and the bar says so
		t.expect(api.actions.beginPlacement("ord_vehplant"))
		local u = world.units[cv]
		api.actions.place(u.x + 40, u.z, false, true)
		api.actions.place(u.x + 40, u.z + 40, true, true)
		api.actions.place(u.x + 40, u.z - 40, true, false)
		local stalled = false
		for _ = 1, 60 do
			run(15)
			local p = Minimap.resLine("Power", (api.state.economy :: any).power)
			local s = Minimap.resLine("Supply", (api.state.economy :: any).supply)
			if p.stalling or s.stalling then
				stalled = true
				t.expect(string.find(p.text .. s.text, "STALL", 1, true) ~= nil)
				break
			end
		end
		t.expect(stalled, "a stall shows in the bar")
		t.equal(Minimap.resLine("Power", nil).text, "Power: waiting for the server")
	end)

	t.test("radar blips glide toward each new reading; a far jump snaps (C-151)", function()
		local world = World.new(Defs.load())
		world.units[9] = { id = 9, tier = "strategic", team = 2, x = 0, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} }
		World.smoothStrategic(world, 1 / 60)
		t.expect(world.units[9].sx == 0, "starts on its spot")
		world.units[9].x = 30 -- a new wobbled reading
		World.smoothStrategic(world, 1 / 60)
		local u = world.units[9]
		t.expect((u.sx :: number) > 0 and (u.sx :: number) < 5, "moves only a little in one frame")
		for _ = 1, 120 do
			World.smoothStrategic(world, 1 / 60)
		end
		t.expect(math.abs((u.sx :: number) - 30) < 0.5, "arrives within two seconds")
		u.x = 900
		World.smoothStrategic(world, 1 / 60)
		t.equal(u.sx, 900, "a contact reappearing far away snaps")
	end)

	t.test("radar blips circle their spot 1.5 studs out, once in 6 s; other records don't (C-154)", function()
		local world = World.new(Defs.load())
		local SF = require("@shared/Net/Schema").StrategicFlag
		local function rec(id: number, flags: number): any
			return { id = id, tier = "strategic", team = 2, flags = flags, x = 100, z = 50, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} }
		end
		world.units[3] = rec(3, SF.RADAR_ONLY)
		world.units[4] = rec(4, SF.RADAR_ONLY)
		world.units[5] = rec(5, 0) -- an ally's unit out of view: exact
		local angles: { number } = {}
		local worst, total = 0, 0
		local last: number? = nil
		for f = 0, 360 do
			World.smoothStrategic(world, 1 / 60, f / 60)
			local u = world.units[3]
			local dx, dz = (u.sx :: number) - 100, (u.sz :: number) - 50
			worst = math.max(worst, math.abs(math.sqrt(dx * dx + dz * dz) - World.BLIP_ORBIT))
			local a = math.atan2(dz, dx)
			if last then
				local d = (a - last + math.pi) % (2 * math.pi) - math.pi
				total += d
			end
			last = a
			table.insert(angles, a)
		end
		t.expect(worst < 1e-6, `on the circle (off by {worst})`)
		t.expect(math.abs(math.abs(total) - 2 * math.pi) < 0.05, `one turn in 6 s ({total})`)
		local b = world.units[4]
		t.expect(math.abs((b.sx :: number) - (world.units[3].sx :: number)) + math.abs((b.sz :: number) - (world.units[3].sz :: number)) > 0.01, "contacts circle out of step")
		t.equal(world.units[5].sx, 100, "a non-blip record sits on its spot")
	end)
end

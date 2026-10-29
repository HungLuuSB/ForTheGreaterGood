--!strict
-- The build ghost (client task 6): the client's placement check agrees with
-- the server's, and placing sends BUILDs the server turns into frames.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Placement = require("../../src/client/Core/Placement")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local ServerPlacement = require("../../src/server/Sim/Placement")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Grid = require("@shared/Grid/Grid")
local Prng = require("@shared/Util/Prng")

local DT = 1 / 15

local function setup(mapId: string, scenario: string)
	local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 } }, mapId = mapId, scenario = scenario })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local sent = 0
	local api = Api.new(world, function(payload: buffer)
		sent += 1
		assert(Sim.submit(sim, 1, payload))
	end)
	local cells = (sim.map :: any).grid.cellsX
	api.send(Commands.camera(0, 0, cells - 1, cells - 1))
	local tick = 0
	local function run(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.entered)
			table.clear(world.left)
			table.clear(world.died)
			Api.frame(api, tick * DT)
		end
	end
	run(2)
	return sim, world, api, run, function()
		return sent
	end
end

local function defOf(sim: any, id: string): any
	return sim.defs.units[id]
end

return function(t: any)
	t.test("the client check matches the server's on hills, lakes and structures", function()
		local sim, world, _, run = setup("gen:11:48", "empty")
		-- a few structures and a tank the client sees
		local generator = defOf(sim, "ord_generator")
		local placedAny = 0
		local rng = Prng.new(3)
		for _ = 1, 40 do
			local x, z = rng:nextNumber(-170, 170), rng:nextNumber(-170, 170)
			if ServerPlacement.check(sim, generator, x, z) and placedAny < 6 then
				local _, _, _, _, cx, cz = ServerPlacement.check(sim, generator, x, z)
				Spawn.unit(sim, "ord_generator", 1, cx, cz)
				placedAny += 1
			end
		end
		Spawn.unit(sim, "ord_lancer", 1, 20, 20)
		run(3)
		t.expect(placedAny >= 4, "structures placed")
		local knower = sim.players[1].allyTeam
		local agree, total = 0, 0
		local reasons: { [string]: number } = {}
		for _, defId in { "ord_generator", "ord_extractor", "ord_shipyard", "ord_solar", "ord_vehplant" } do
			local def = defOf(sim, defId)
			for _ = 1, 150 do
				local x, z = rng:nextNumber(-200, 200), rng:nextNumber(-200, 200)
				-- the frame-start form (owner, no knower): own units walk out of
				-- the footprint (S-155), as the client's preview has it (C-195)
				local sok, sreason = ServerPlacement.check(sim, def, x, z, 1)
				local r = Placement.check(world, def, x, z)
				total += 1
				if r.ok == sok and r.reason == sreason then
					agree += 1
				else
					t.expect(false, `{defId} at ({x}, {z}): client {r.ok} {r.reason}, server {sok} {sreason}`)
				end
				local key = sreason or "ok"
				reasons[key] = (reasons[key] or 0) + 1
			end
		end
		t.equal(agree, total)
		t.expect((reasons.ok or 0) > 0 and (reasons.terrain or 0) > 0 and (reasons.occupied or 0) > 0, "the sample covers ok, terrain and occupied")
		t.expect((reasons["no deposit"] or 0) > 0 and (reasons["out of bounds"] or 0) > 0, "and deposits and bounds")
	end)

	t.test("an extractor ghost snaps onto a nearby deposit, and the server accepts it", function()
		local sim, world, api, run = setup("start:48", "standard_start")
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		local layers = world.layers :: any
		local g = world.grid
		local Layers = require("@shared/Grid/Layers")
		local checked = 0
		for cz = 0, g.cellsZ - 1 do
			for cx = 0, g.cellsX - 1 do
				if Layers.getSupply(layers, g:index(cx, cz)) > 0 then
					local wx, wz = g:cellCenter(cx, cz)
					t.expect(api.actions.beginPlacement("ord_extractor"))
					-- anywhere within the snap radius, including off the cell
					for _, off in { { 0, 0 }, { 5, 5 }, { -6, 4 }, { 9, 0 }, { 0, -10 } } do
						local ok, why = api.actions.updatePlacement(wx + off[1], wz + off[2])
						t.expect(ok, `deposit ({cx}, {cz}) from offset {off[1]}, {off[2]}: {why}`)
						local p = api.state.placement :: any
						-- S-104: the extractor's footprint (2 cells, centred on a corner) covers the deposit
						local fp = defOf(sim, "ord_extractor").footprint
						local x0, z0 = require("@shared/Grid/PlacementRules").snap(g, fp, p.x, p.z)
						t.expect(cx >= x0 and cx < x0 + fp and cz >= z0 and cz < z0 + fp, "the ghost covers the deposit")
						local sok = ServerPlacement.check(sim, defOf(sim, "ord_extractor"), p.x, p.z, 1, sim.players[1].allyTeam)
						t.expect(sok, "the server agrees")
						checked += 1
					end
					api.actions.cancelPlacement()
				end
			end
		end
		t.expect(checked >= 40, `checked {checked} spots`)
		-- far from any deposit nothing snaps
		t.expect(api.actions.beginPlacement("ord_extractor"))
		local ok, why = api.actions.updatePlacement(0, 150)
		t.expect(not ok and why == "no deposit")
		local _ = run
	end)

	t.test("a builder's queue: each queued build stays until its frame starts, through long standstills (C-23)", function()
		local sim, world, api, run = setup("start:48", "standard_start")
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		local u = world.units[cv]
		t.expect(api.actions.beginPlacement("ord_solar"))
		t.expect(api.actions.place(u.x + 36, u.z - 20, false, false))
		t.expect(api.actions.beginPlacement("ord_solar"))
		t.expect(api.actions.placeRow(u.x + 20, u.z + 40, u.x + 44, u.z + 40, true, false))
		local queued = #api.waypoints.byUnit[cv]
		t.expect(queued >= 3, `a solar + a row of solars queued ({queued})`)
		local function serverBuilds(): number
			local n = 0
			for _, o in sim.orders.queue[cv] or {} do
				if o.kind == "build" and not o.started then
					n += 1
				end
			end
			return n
		end
		local seen: { [number]: boolean } = { [queued] = true }
		local maxGap = 0
		for _ = 1, 15 * 120 do
			run(1)
			local list = api.waypoints.byUnit[cv]
			local n = if list then #list else 0
			seen[n] = true
			-- never more than one ahead of the server (the one whose frame just started)
			local gap = serverBuilds() - n
			maxGap = math.max(maxGap, math.abs(gap))
			if n == 0 and serverBuilds() == 0 then
				break
			end
		end
		t.expect(maxGap <= 1, `the client's queue follows the server's (worst gap {maxGap})`)
		for k = queued, 0, -1 do
			t.expect(seen[k], `the queue went through {k} items left`)
		end
		local frames = 0
		for _, s in world.units do
			local d = World.def(world, s)
			if d and d.id == "ord_solar" then
				frames += 1
			end
		end
		t.equal(frames, queued, "every queued structure was built")
	end)

	t.test("a ghost can't overlap a build already queued (C-165)", function()
		local _sim, world, api, run = setup("start:48", "standard_start")
		run(3)
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		t.expect(api.actions.beginPlacement("ord_solar"))
		local u = world.units[cv]
		local x, z = u.x + 80, u.z + 80
		t.expect(api.actions.place(x, z, true, true), "the first one, queued, placing kept (Shift)")
		local size = world.defs.units.ord_solar.footprint * 8
		local ok, why = api.actions.updatePlacement(x + size / 2, z)
		t.expect(not ok and why == "occupied", `half over the queued one: {why}`)
		t.expect(not api.actions.place(x + size / 2, z, true, true), "and it isn't sent")
		t.expect(api.actions.updatePlacement(x + size, z), "right next to it is fine")
		-- a dragged row over the queued one skips the taken spot
		local before = #(api.waypoints.byUnit[cv] or {})
		api.actions.placeRow(x - size, z, x + size, z, true, true)
		local after = #(api.waypoints.byUnit[cv] or {})
		t.equal(after - before, 2, "the row's two free spots, not the queued one")
	end)

	t.test("placing sends a BUILD and the server raises the frame", function()
		local sim, world, api, run, sentCount = setup("start:48", "standard_start")
		local cv = World.ownIds(world)[1]
		t.expect(cv ~= nil, "the Command Vehicle is known")
		local ok, why = api.actions.beginPlacement("ord_solar")
		t.expect(not ok and why == "no selected builder can build it", "needs a builder selected")
		api.actions.select({ cv })
		t.expect(api.actions.beginPlacement("ord_solar"))
		local u = world.units[cv]
		local x, z = u.x + 40, u.z
		t.expect(api.actions.updatePlacement(x, z), "a free spot is valid")
		local p = api.state.placement :: any
		t.equal(p.defId, "ord_solar")
		t.expect(api.actions.rotatePlacement())
		t.equal(p.facing, 1)
		local before = sentCount()
		t.expect(api.actions.place(x, z, false, false))
		t.equal(sentCount(), before + 1, "one BUILD")
		t.equal(api.state.placement, nil, "placing ends without Shift")
		run(15 * 20)
		local frame
		for _, w in world.units do
			local d = World.def(world, w)
			if d and d.id == "ord_solar" then
				frame = w
			end
		end
		t.expect(frame ~= nil, "the solar frame entered the client world")
		t.expect(math.abs(frame.x - p.x) < 0.1 and math.abs(frame.z - p.z) < 0.1, "at the ghost's snapped spot")
		t.expect((frame.build or 0) > 0, "construction has started")
	end)

	t.test("extractors need a deposit; invalid spots aren't sent; rows queue", function()
		local sim, world, api, run, sentCount = setup("start:48", "standard_start")
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		local u = world.units[cv]
		local layers = world.layers :: any
		local g = world.grid
		-- a deposit near the start (start maps put four around each start)
		local depositX, depositZ
		for cz = 0, g.cellsZ - 1 do
			for cx = 0, g.cellsX - 1 do
				if require("@shared/Grid/Layers").getSupply(layers, g:index(cx, cz)) > 0 then
					local wx, wz = g:cellCenter(cx, cz)
					if depositX == nil or (wx - u.x) ^ 2 + (wz - u.z) ^ 2 < (depositX - u.x) ^ 2 + (depositZ - u.z) ^ 2 then
						depositX, depositZ = wx, wz
					end
				end
			end
		end
		t.expect(api.actions.beginPlacement("ord_extractor"))
		local ok, why = api.actions.updatePlacement(depositX + 24, depositZ + 24)
		t.expect(not ok and why == "no deposit")
		local before = sentCount()
		ok = api.actions.place(depositX + 24, depositZ + 24, false, true)
		t.expect(not ok, "an invalid spot isn't placed")
		t.equal(sentCount(), before, "and nothing is sent")
		t.expect(api.actions.place(depositX, depositZ, false, true), "on the deposit")
		t.expect(api.state.placement ~= nil, "Shift keeps placing")
		t.expect(api.actions.cancelPlacement())
		-- a row of solars
		t.expect(api.actions.beginPlacement("ord_solar"))
		before = sentCount()
		-- with Shift (queue) the row goes after the extractor; without, it would replace it
		t.expect(api.actions.placeRow(u.x - 30, u.z - 50, u.x + 30, u.z - 50, true, false))
		local n = sentCount() - before
		t.expect(n >= 3, `a row of {n} solars`)
		run(2)
		local kinds = {}
		for _, o in sim.orders.queue[cv] do
			table.insert(kinds, `{o.kind}:{o.defIndex}@{math.floor(o.x or 0)},{math.floor(o.z or 0)}`)
		end
		t.equal(#sim.orders.queue[cv], 1 + n, "extractor then the row, all queued on the server: " .. table.concat(kinds, " "))
	end)

	t.test("a longer row only adds spots, one footprint apart (H2)", function()
		local sim, world = setup("gen:11:48", "empty")
		local solar = defOf(sim, "ord_solar")
		local step = solar.footprint * Grid.CELL_SIZE
		for _, dir in { { 1, 0 }, { 0, -1 }, { 1, 0.4 }, { -0.7, 1 } } do
			local last: { { number } } = {}
			for len = 0, 60, 1.5 do
				local spots = Placement.row(world, solar, 3, 5, 3 + dir[1] * len, 5 + dir[2] * len)
				t.expect(#spots >= #last, `the row never shrinks as it grows ({#last} → {#spots})`)
				for i, s in last do
					t.equal(spots[i][1], s[1], `spot {i} stays put (x)`)
					t.equal(spots[i][2], s[2], `spot {i} stays put (z)`)
				end
				for i = 2, #spots do
					local a, b = spots[i - 1], spots[i]
					local gap = math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2]))
					t.equal(gap, step, `neighbours one footprint apart, no overlap or gap ({gap})`)
				end
				last = spots
			end
			t.expect(#last >= 3, `a long drag lays a long row ({#last})`)
		end
	end)

	t.test("Alt + drag lays a grid; a bigger box only adds spots (H4)", function()
		local sim, world = setup("gen:11:48", "empty")
		local solar = defOf(sim, "ord_solar")
		local step = solar.footprint * Grid.CELL_SIZE
		local spots = Placement.grid(world, solar, 3, 5, 3 + 3 * step, 5 - 1 * step)
		t.equal(#spots, 8, "4 columns by 2 rows")
		local seen = {}
		for i, s in spots do
			seen[`{s[1]},{s[2]}`] = true
			if i > 1 then
				local a = spots[i - 1]
				t.equal(math.abs(s[1] - a[1]) + math.abs(s[2] - a[2]), step, "the serpentine walks to a neighbour each time")
			end
		end
		local bigger = Placement.grid(world, solar, 3, 5, 3 + 4.2 * step, 5 - 2.1 * step)
		t.equal(#bigger, 15, "5 by 3")
		for _, s in bigger do
			seen[`{s[1]},{s[2]}`] = nil
		end
		t.equal(next(seen), nil, "every spot of the smaller grid is in the bigger one")
		t.equal(#Placement.drag(world, solar, 3, 5, 3 + 3 * step, 5 - step, false), #Placement.row(world, solar, 3, 5, 3 + 3 * step, 5 - step), "without Alt a drag is a row")
	end)
end

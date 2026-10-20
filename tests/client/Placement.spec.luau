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
				local sok, sreason = ServerPlacement.check(sim, def, x, z, 1, knower)
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

	t.test("placing sends a BUILD and the server raises the frame", function()
		local sim, world, api, run, sentCount = setup("start:48", "standard_start")
		local cv = World.ownIds(world)[1]
		t.expect(cv ~= nil, "the Command Vehicle is known")
		local ok, why = api.actions.beginPlacement("ord_generator")
		t.expect(not ok and why == "no selected builder can build it", "needs a builder selected")
		api.actions.select({ cv })
		t.expect(api.actions.beginPlacement("ord_generator"))
		local u = world.units[cv]
		local x, z = u.x + 40, u.z
		t.expect(api.actions.updatePlacement(x, z), "a free spot is valid")
		local p = api.state.placement :: any
		t.equal(p.defId, "ord_generator")
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
			if d and d.id == "ord_generator" then
				frame = w
			end
		end
		t.expect(frame ~= nil, "the generator frame entered the client world")
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
end

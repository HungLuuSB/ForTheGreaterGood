--!strict
-- Extractor upgrades in place (C-121): a T2 builder's extractor ghost snaps
-- onto the player's own T1 extractors and the server accepts it; Upgrade
-- extractors queues every one in a circle, nearest first; an extractor drag
-- queues every free deposit and upgrade in its circle.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Upgrades = require("../../src/client/Core/Upgrades")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local ServerPlacement = require("../../src/server/Sim/Placement")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Layers = require("@shared/Grid/Layers")

local DT = 1 / 15

-- A start map with the player's T1 extractors on the three deposits nearest
-- the start, a T2 builder and a T1 builder.
local function setup()
	local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 } }, mapId = "start:48", scenario = "standard_start" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local api = Api.new(world, function(payload: buffer)
		assert(Sim.submit(sim, 1, payload))
	end)
	local grid = (sim.map :: any).grid
	api.send(Commands.camera(0, 0, grid.cellsX - 1, grid.cellsZ - 1))
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
	local start = sim.world.ids[1]
	local sx, sz = sim.world.posX[start], sim.world.posZ[start]
	local deposits = {}
	local layers = (sim.map :: any).layers
	for cz = 0, grid.cellsZ - 1 do
		for cx = 0, grid.cellsX - 1 do
			if Layers.getSupply(layers, grid:index(cx, cz)) > 0 then
				local wx, wz = grid:cellCenter(cx, cz)
				table.insert(deposits, { wx, wz, (wx - sx) ^ 2 + (wz - sz) ^ 2 })
			end
		end
	end
	table.sort(deposits, function(a, b)
		return a[3] < b[3]
	end)
	local t1 = {}
	for i = 1, 3 do
		table.insert(t1, Spawn.unit(sim, "ord_extractor", 1, deposits[i][1], deposits[i][2]))
	end
	local architect = Spawn.unit(sim, "ord_architect", 1, sx + 70, sz + 70) -- clear of the T2s' 3×3 footprints (S-104)
	local mason = Spawn.unit(sim, "ord_mason", 1, sx - 70, sz + 70)
	run(3)
	return sim, world, api, run, { t1 = t1, architect = architect, mason = mason, deposits = deposits }
end

return function(t: any)
	t.test("which defs upgrade, and which builders can", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:64", scenario = "empty" })
		local defs = sim.defs
		t.expect(Upgrades.isUpgrade(defs, defs.units.ord_advextractor), "the advanced extractor upgrades")
		t.expect(Upgrades.isUpgrade(defs, defs.units.chs_advextractor), "both factions'")
		t.expect(not Upgrades.isUpgrade(defs, defs.units.ord_extractor), "a T1 extractor doesn't")
		t.expect(not Upgrades.isUpgrade(defs, defs.units.ord_generator), "nor anything else")
		t.equal((Upgrades.upgraderFor(defs, { defs.units.ord_architect }) :: any).id, "ord_advextractor")
		t.equal(Upgrades.upgraderFor(defs, { defs.units.ord_mason }), nil, "a T1 builder can't upgrade")
		t.expect(Upgrades.replaces(defs.units.ord_advextractor, defs.units.ord_extractor), "Order's T2 replaces Order's T1")
		t.expect(not Upgrades.replaces(defs.units.ord_advextractor, defs.units.chs_extractor), "not the other faction's")
	end)

	t.test("a T2 extractor ghost snaps onto an own T1 and the server accepts it", function()
		local sim, world, api, _, s = setup()
		local adv = sim.defs.units.ord_advextractor
		t.equal(#Upgrades.targets(world, adv), 3, "the three T1 extractors are targets")
		t.equal(#Upgrades.targets(world, sim.defs.units.ord_extractor), 0, "a T1 doesn't upgrade a T1")
		api.actions.select({ s.architect })
		t.expect(api.actions.beginPlacement("ord_advextractor"))
		for _, id in s.t1 do
			local u = world.units[id]
			local ok, why = api.actions.updatePlacement(u.x + 7, u.z - 6)
			t.expect(ok, `onto T1 {id}: {why}`)
			local p = api.state.placement :: any
			local sx, sz = Upgrades.site(world, adv, id)
			t.expect(math.abs(p.x - sx) < 1e-6 and math.abs(p.z - sz) < 1e-6, "the ghost sits on the T1's deposit")
			local sok, swhy, _, _, _, _, replaces = ServerPlacement.check(sim, adv, p.x, p.z, 1)
			t.expect(sok, `the server agrees: {swhy}`)
			t.equal(replaces, id, "and replaces that T1")
		end
		api.actions.cancelPlacement()
		-- the T1 builder's T1 ghost over its own T1: occupied
		api.actions.select({ s.mason })
		t.expect(api.actions.beginPlacement("ord_extractor"))
		local u = world.units[s.t1[1]]
		local ok, why = api.actions.updatePlacement(u.x, u.z)
		t.expect(not ok and why == "occupied", `a T1 onto a T1: {why}`)
	end)

	t.test("Upgrade extractors queues every own T1 in the circle, nearest the builder first", function()
		local sim, world, api, run, s = setup()
		api.actions.select({ s.architect })
		local b = world.units[s.architect]
		-- a circle around all three T1s
		local cx, cz = 0, 0
		for _, id in s.t1 do
			cx += world.units[id].x / 3
			cz += world.units[id].z / 3
		end
		local ok, why = api.actions.upgradeArea(cx, cz, 200, false)
		t.expect(ok, why)
		run(2)
		-- the T1s under the queued builds don't count as their frames (Waypoints):
		-- every upgrade is either started (a frame stands) or still drawn
		local started = 0
		for _, u in world.units do
			if u.defIndex == sim.defs.units.ord_advextractor.index then
				started += 1
			end
		end
		t.equal(started + #(api.waypoints.byUnit[s.architect] or {}), 3, `every queued upgrade started or still drawn ({started} started)`)
		local q = sim.orders.queue[s.architect] or {}
		t.equal(#q, 3, "one BUILD per T1")
		local expected = Upgrades.inCircle(world, sim.defs.units.ord_advextractor, cx, cz, 200, b.x, b.z)
		local adv = sim.defs.units.ord_advextractor
		for i, o in q do
			t.equal(o.defIndex, adv.index, "an advanced extractor")
			local sx, sz = Upgrades.site(world, adv, expected[i])
			t.expect(math.abs(o.x - sx) < 1 and math.abs(o.z - sz) < 1, `order {i} on the {i}th nearest T1`)
		end
		-- a circle with no T1 in it sends nothing
		local none, why2 = api.actions.upgradeArea(cx + 2000, cz, 20, false)
		t.expect(not none and why2 == "no extractor to upgrade there")
	end)

	t.test("an extractor drag queues every free deposit and upgrade in its circle", function()
		local sim, world, api, run, s = setup()
		local grid = world.grid
		-- the 6 deposits nearest the start: 3 under T1s, 3 free (start maps have 4+ per start)
		local cx, cz = 0, 0
		for i = 1, 6 do
			cx += s.deposits[i][1] / 6
			cz += s.deposits[i][2] / 6
		end
		local radius = 0
		for i = 1, 6 do
			radius = math.max(radius, math.sqrt((s.deposits[i][1] - cx) ^ 2 + (s.deposits[i][2] - cz) ^ 2) + 1)
		end
		local inside = 0
		for _, d in s.deposits do
			if (d[1] - cx) ^ 2 + (d[2] - cz) ^ 2 <= radius * radius then
				inside += 1
			end
		end
		-- the T1 builder: only the free deposits
		api.actions.select({ s.mason })
		t.expect(api.actions.beginPlacement("ord_extractor"))
		t.expect(api.actions.placeArea(cx, cz, radius, false, false))
		run(2)
		t.equal(#(sim.orders.queue[s.mason] or {}), inside - 3, "T1 extractors on the free deposits only")
		-- the T2 builder: free deposits and the T1s
		api.actions.select({ s.architect })
		t.expect(api.actions.beginPlacement("ord_advextractor"))
		t.expect(api.actions.placeArea(cx, cz, radius, false, false))
		run(2)
		-- the free deposits already have the Mason's queued T1s, which a new
		-- plan can't overlap (C-165): the upgrades of the three standing T1s
		t.equal(#(sim.orders.queue[s.architect] or {}), 3, "T2 extractors on the T1s; the Mason's queued spots are taken")
		local _ = grid
	end)
end

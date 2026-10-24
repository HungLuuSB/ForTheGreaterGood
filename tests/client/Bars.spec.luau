--!strict
-- Health and build bars (C-24): who gets them, two bars while building and
-- one when done, health growing with progress, and damage that lowers
-- health but never build progress (as the client sees it on the wire).

local Api = require("../../src/client/Api")
local Bars = require("../../src/client/Core/Bars")
local Icons = require("../../src/client/Core/Icons")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15

local function setup(players: { any })
	local sim = Sim.new({ seed = 2, players = players, mapId = "start:48", scenario = "standard_start" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local api = Api.new(world, function(p: buffer)
		assert(Sim.submit(sim, 1, p))
	end)
	api.send(Commands.camera(0, 0, 47, 47))
	local tick = 0
	local function run(n: number, each: (() -> ())?)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.died)
			Api.frame(api, tick * DT)
			if each then
				each()
			end
		end
	end
	run(2)
	return sim, world, api, run
end

local function barOf(list: { any }, id: number): any
	for _, b in list do
		if b.id == id then
			return b
		end
	end
	return nil
end

return function(t: any)
	t.test("a frame shows two bars while building, health rising with progress, then none", function()
		local _sim, world, api, run = setup({ { id = 1, team = 1 } })
		local cv = World.ownIds(world)[1]
		t.equal(#Bars.list(world, {}), 0, "a healthy, unselected unit has no bar")
		t.equal(#Bars.list(world, { [cv] = true }), 1, "selected: one bar")
		api.actions.select({ cv })
		local u = world.units[cv]
		assert(api.actions.beginPlacement("ord_generator"))
		assert(api.actions.place(u.x + 30, u.z - 20, false, false))
		local frameId
		local samples, twoBars = 0, 0
		local lastBuild = -1
		run(15 * 40, function()
			for id, w in world.units do
				local d = World.def(world, w)
				if d and d.id == "ord_generator" then
					frameId = id
				end
			end
			if frameId then
				local b = barOf(Bars.list(world, {}), frameId)
				local w = world.units[frameId]
				if w and (w.build or 1) < 1 then
					t.expect(b ~= nil and b.build ~= nil, "a frame under construction has a build bar")
					twoBars += 1
					-- health grows with progress (start at 1 %, no damage here)
					t.expect(math.abs(b.health - (0.01 + 0.99 * b.build)) < 0.03, `health {b.health} follows build {b.build}`)
					t.expect(b.build >= lastBuild, "progress never goes back")
					lastBuild = b.build
					samples += 1
				end
			end
		end)
		t.expect(samples > 10, `sampled the build ({samples} ticks)`)
		t.expect(twoBars > 0)
		local w = world.units[frameId]
		t.expect(w.build >= 1, "finished")
		t.equal(barOf(Bars.list(world, {}), frameId), nil, "finished and healthy: no bar")
		local sel = barOf(Bars.list(world, { [frameId] = true }), frameId)
		t.expect(sel and sel.build == nil, "selected and finished: one bar (health only)")
	end)

	t.test("a producing factory shows an amber progress bar, rising, unselected (C-168)", function()
		local sim, world, api, run = setup({ { id = 1, team = 1 } })
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 60, 60, 0)
		Spawn.unit(sim, "ord_fusion", 1, -100, -100, 0)
		run(3)
		t.equal(barOf(Bars.list(world, {}), plant), nil, "idle and healthy: no bar")
		api.actions.select({ plant })
		t.expect(api.actions.queueBuild("ord_lancer", 1))
		api.actions.select({})
		local last, rising, seen = -1, true, 0
		for _ = 1, 15 * 10 do
			run(1)
			local b = barOf(Bars.list(world, {}), plant)
			if b and b.production then
				seen += 1
				if b.production < last then
					rising = false
				end
				last = b.production
			end
		end
		t.expect(seen > 50, `the bar shows while it produces ({seen} ticks)`)
		t.expect(rising and last > 0.2, `and rises ({last})`)
	end)

	t.test("a Radiance recharging after its shot shows a recharge bar that fills over its reload (C-170)", function()
		local sim, world, _api, run = setup({ { id = 1, team = 1 }, { id = 2, team = 2 } })
		local tower = Spawn.unit(sim, "ord_radiance", 1, -40, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, -120, -120, 0)
		Spawn.unit(sim, "chs_ravager", 2, 200, 0, 0)
		local Effects = require("../../src/client/Core/Effects")
		local fx = Effects.new()
		local seen, first, last, done = 0, nil, nil, false
		for i = 1, 15 * 20 do
			run(1)
			world.shownTick = world.latestTick -- as World.settle sets it
			Effects.update(fx, world, world.latestTick, i * DT, 0, 0) -- notes the shots (FIRE)
			local b = barOf(Bars.list(world, {}), tower)
			if b and b.reload then
				if last and last > 0.9 and b.reload < 0.1 then
					done = true -- charged and fired again
					break
				end
				seen += 1
				first = first or b.reload
				last = b.reload
			elseif seen > 0 then
				done = true -- charged: the bar goes
				break
			end
		end
		t.expect(seen > 15 * 5, `the bar shows for most of the 9 s reload ({seen} ticks)`)
		t.expect((first :: number) < 0.1 and (last :: number) > 0.9, `it fills from empty to full ({first} → {last})`)
		t.expect(done, "and ends when charged")
	end)

	t.test("damage lowers a frame's health but not its build progress", function()
		local sim, world, api, run = setup({ { id = 1, team = 1 }, { id = 2, team = 2 } })
		local cv = World.ownIds(world)[1]
		api.actions.select({ cv })
		local u = world.units[cv]
		-- a sturdy, slow structure, and an enemy tank parked next to it
		assert(api.actions.beginPlacement("ord_vehplant"))
		assert(api.actions.place(u.x + 40, u.z, false, false))
		run(15 * 3)
		local frameId
		for id, w in world.units do
			local d = World.def(world, w)
			if d and d.id == "ord_vehplant" then
				frameId = id
			end
		end
		t.expect(frameId ~= nil, "the factory frame is up")
		local f = world.units[frameId]
		Spawn.unit(sim, "chs_ravager", 2, f.x + 60, f.z, -math.pi / 2)
		local hits, lastBuild, lastHealth = 0, -1, f.health :: number
		run(15 * 15, function()
			local w = world.units[frameId]
			if w == nil or (w.build or 1) >= 1 then
				return
			end
			local b = barOf(Bars.list(world, {}), frameId)
			t.expect(b.build >= lastBuild, "build progress never drops under fire")
			lastBuild = b.build
			if b.health < lastHealth - 1e-6 then
				hits += 1
			end
			lastHealth = b.health
		end)
		t.expect(hits > 0, "the frame took hits while building")
		t.expect(lastBuild > 0, "and kept building")
	end)

	t.test("damaged units get a bar; colors go green, yellow, red", function()
		local world: any = World.new(require("@shared/Defs/Defs").load())
		world.joined = true
		world.me = { player = 1, team = 1, allyTeam = 1 }
		world.units[1] = { id = 1, tier = "tactical", team = 2, health = 0.4, build = 1, state = 0, x = 0, z = 0, alt = 0 }
		world.units[2] = { id = 2, tier = "tactical", team = 2, health = 1, build = 1, state = 0, x = 0, z = 0, alt = 0 }
		world.units[3] = { id = 3, tier = "strategic", team = 2, x = 0, z = 0, alt = 0, state = 0 }
		local list = Bars.list(world, {})
		t.equal(#list, 1, "only the damaged enemy")
		t.equal(list[1].id, 1)
		t.expect(not list[1].own)
		-- top-down projector, 2 px per stud: centred on the unit, under its footprint (C-208), footprint wide
		world.units[1].x, world.units[1].z = 50, 40
		local function project(x: number, _y: number, z: number)
			return x * 2, z * 2, true
		end
		local d = Bars.draws(world, list, project, 400, 400, 1, 0)
		t.equal(#d, 1)
		t.equal(d[1].x, 100)
		t.equal(d[1].y, 88 + Bars.GAP, "the footprint's near edge (z 44 → 88 px) plus the gap")
		t.equal(d[1].width, Bars.MIN_WIDTH, "an 8-stud unit at 2 px/stud: clamped up to the minimum")
		t.equal(#Bars.draws(world, list, project, 50, 50, 1, 0), 0, "off screen: no bar")
		-- an aircraft drawn at 110 studs: its bar and icon sit just over the model, not at twice the altitude
		world.units[4] = { id = 4, tier = "tactical", team = 2, health = 0.5, build = 1, state = 0, x = 0, z = 0, alt = 110, rx = 0, ry = 110, rz = 0, defIndex = world.defs.units.ord_falcon.index }
		local function side(x: number, y: number, z: number)
			return x, y, true -- screen y = world height, to read it back
		end
		local barY, iconY
		for _, dd in Bars.draws(world, Bars.list(world, {}), side, 400, 400, 1, 0) do
			if dd.bar.id == 4 then
				barY = dd.y
			end
		end
		for _, ic in Icons.draws(Icons.table(world.defs), world, side, 400, 400, {}) do
			if ic.id == 4 then
				iconY = ic.y
			end
		end
		t.expect(barY and barY >= 110 and barY < 120, `aircraft bar right at the model, not at the ground ({barY})`)
		t.equal(iconY, 110, "aircraft icon at the model")
		local r, g = Bars.healthColor(1)
		t.expect(g > r, "full: green")
		r, g = Bars.healthColor(0.5)
		t.expect(r > 200 and g > 200, "half: yellow")
		r, g = Bars.healthColor(0.05)
		t.expect(r > 200 and g < 100, "low: red")
	end)
end

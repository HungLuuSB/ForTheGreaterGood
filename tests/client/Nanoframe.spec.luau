--!strict
-- Factory production frames (C-152): the client knows what its own and its
-- allies' factories are producing and how far along, through the real
-- NetOut → NetIn path; the build line rises with the progress and builds the
-- frame bottom up; every factory has a pad and spray emitters to draw at.

local Nanoframe = require("../../src/client/Core/Nanoframe")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local Commands = require("../../src/client/Core/Commands")
local Build = require("../../src/server/Sim/Build")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Blockout = require("@shared/Defs/Blockouts/Blockout")

local DT = 1 / 15

-- Player 1 watches; player 2 is an ally (same ally team), player 3 an enemy.
local function scene()
	local players = { { id = 1, team = 1, allyTeam = 1 }, { id = 2, team = 2, allyTeam = 1 }, { id = 3, team = 3, allyTeam = 2 } }
	local sim = Sim.new({ seed = 5, players = players, mapId = "start:64", scenario = "empty" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	local tick = 0
	local function step(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.died)
		end
	end
	return sim, world, step
end

local function produce(sim: any, plant: number, unitId: string)
	local index = assert(sim.defs.units[unitId], unitId).index :: number
	local x, z = sim.world.posX[plant], sim.world.posZ[plant]
	Build.commandBuild(sim, { plant }, index, x, z, 0)
	return index
end

return function(t: any)
	t.test("own and allied factories: the client sees the item and its progress as it builds", function()
		local sim, world, step = scene()
		local own = Spawn.unit(sim, "ord_vehplant", 1, 100, 0, 0)
		local ally = Spawn.unit(sim, "chs_vehplant", 2, -100, 0, 0)
		Spawn.unit(sim, "ord_fusion", 1, 150, -150, 0)
		Spawn.unit(sim, "chs_fusion", 2, -150, -150, 0)
		step(3)
		local ownItem = produce(sim, own, "ord_lancer")
		local allyItem = produce(sim, ally, "chs_jackal")
		local seen = { [own] = 0, [ally] = 0 }
		local rising = { [own] = true, [ally] = true }
		local last = { [own] = -1, [ally] = -1 }
		for _ = 1, 15 * 20 do
			step(1)
			for id, item in { [own] = ownItem, [ally] = allyItem } do
				local u = world.units[id]
				local defIndex, progress = Nanoframe.producing(assert(u))
				local server = sim.build.queue[id]
				if server and #server > 0 and defIndex ~= nil then
					t.equal(defIndex, item, "the item in production")
					t.expect(math.abs(progress - (sim.build.progress[id] or 0)) < 0.08, `progress {progress} vs {sim.build.progress[id]}`)
					if progress < last[id] then
						rising[id] = false
					end
					last[id] = progress
					seen[id] += 1
				end
			end
		end
		t.expect(seen[own] > 20, `own factory seen producing ({seen[own]} ticks)`)
		t.expect(seen[ally] > 20, `allied factory seen producing ({seen[ally]} ticks)`)
		t.expect(rising[own] and rising[ally], "progress only rises within one item")
		print(string.format("    own factory producing on %d ticks, ally on %d", seen[own], seen[ally]))
	end)

	t.test("the build line rises with progress and builds the frame bottom up", function()
		t.equal(Nanoframe.lineY(2, 10, 0), 2)
		t.equal(Nanoframe.lineY(2, 10, 0.5), 6)
		t.equal(Nanoframe.lineY(2, 10, 2), 10, "clamped")
		-- three stacked parts: tracks 0..2, hull 2..5, turret 5..7
		local parts = { { 0, 2 }, { 2, 5 }, { 5, 7 } }
		local before = 0
		for step = 0, 20 do
			local line = Nanoframe.lineY(0, 7, step / 20)
			local n = 0
			for i, p in parts do
				if Nanoframe.built(p[1], p[2], line, 0, 7) then
					n += 1
					t.expect(i == 1 or Nanoframe.built(parts[i - 1][1], parts[i - 1][2], line, 0, 7), "lower parts first")
				end
			end
			t.expect(n >= before, "never unbuilds")
			before = n
		end
		t.equal(before, 3, "all built at the end")
		t.expect(not Nanoframe.built(5, 7, Nanoframe.lineY(0, 7, 0.1), 0, 7), "the turret waits")
	end)

	t.test("drawn progress eases between the server's sixteenths, never backs down, and stalls", function()
		local tr = Nanoframe.tracker()
		local gap = Nanoframe.expectedGap(5100, 200) -- a Lancer from a vehicle plant: ~1.6 s a step
		t.expect(math.abs(gap - 5100 / 200 / 16) < 1e-9)
		local shown, moving = Nanoframe.track(tr, 0, 0, gap)
		t.equal(shown, 0)
		t.expect(moving, "building from the first reading")
		local last = 0
		local now = 0
		for step = 1, 8 do
			for _ = 1, 10 do
				now += gap / 10
				local s = Nanoframe.track(tr, (step - 1) / 16, now, gap)
				t.expect(s >= last, "never backs down")
				t.expect(s <= step / 16 + 1e-9, "never past the next step")
				last = s
			end
			Nanoframe.track(tr, step / 16, now, gap)
		end
		t.expect(last > 7 / 16, `eased up to the steps ({last})`)
		-- no step for a long while: a stalled economy
		local _, still = Nanoframe.track(tr, 8 / 16, now + gap * 3, gap)
		t.expect(not still, "the spray stops when no step comes")
		-- a new item of the same type starts over
		local fresh, again = Nanoframe.track(tr, 0, now + gap * 4, gap)
		t.equal(fresh, 0)
		t.expect(again, "building again")
	end)

	t.test("spray points stay inside the frame's footprint", function()
		for i = 1, 4 do
			for k = 0, 50 do
				local x, z = Nanoframe.sprayPoint(i, 4, k * 0.07, 3, 5)
				t.expect(math.abs(x) <= 3 and math.abs(z) <= 5, "inside")
			end
		end
	end)

	t.test("every factory's blockout has a build pad and spray emitters", function()
		local n = 0
		for _, def in Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "start:48", scenario = "empty" }).defs.unitByIndex do
			local isFactory = def.domain == "structure" and def.buildOptions ~= nil and #def.buildOptions > 0
			if isFactory then
				local bp = Blockout.forDef(def)
				local names = {}
				for _, a in bp.attachments or {} do
					names[a.name] = true
				end
				t.expect(names.buildpad, `{def.id} has a buildpad`)
				t.expect(names.nano1, `{def.id} has nano1`)
				n += 1
			end
		end
		t.expect(n >= 6, `factories checked ({n})`)
	end)
end

--!strict
-- Range rings (C-19): same-kind circles merge into one outline with no
-- interior arcs; separate circles stay separate; kinds never merge; the
-- cost with 50 selected units.

local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Ranges = require("../../src/client/Core/Ranges")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Ghosts = require("../../src/client/Core/Ghosts")
local Icons = require("../../src/client/Core/Icons")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")
local Profiler = require("@shared/Util/Profiler")

local TAU = 2 * math.pi

local function inside(c: any, x: number, z: number): boolean
	return (x - c.x) ^ 2 + (z - c.z) ^ 2 < c.r * c.r - 1e-6
end

-- Every sampled point of every arc lies on no other circle's inside.
local function noInteriorArcs(t: any, circles: { any }, arcs: { any })
	for _, arc in arcs do
		for k = 1, 31 do
			local a = arc.a0 + (arc.a1 - arc.a0) * k / 32
			local x, z = Ranges.at(arc, a)
			for _, c in circles do
				if c.kind == arc.kind and not (c.x == arc.x and c.z == arc.z and c.r == arc.r) then
					t.expect(not inside(c, x, z), `arc point ({x}, {z}) inside another {c.kind} circle`)
				end
			end
		end
	end
end

local function total(arcs: { any }): number
	local sum = 0
	for _, a in arcs do
		sum += a.a1 - a.a0
	end
	return sum
end

return function(t: any)
	t.test("arcs keep the unit they belong to, so rings can follow it between rebuilds (C-29)", function()
		local circles = {
			{ x = 0, z = 0, r = 50, kind = "weapon", owner = 7 },
			{ x = 30, z = 0, r = 50, kind = "weapon", owner = 9 },
			{ x = 200, z = 0, r = 30, kind = "weapon" }, -- the build ghost: no owner
		}
		local arcs = Ranges.union(circles)
		local owners = {}
		for _, arc in arcs do
			owners[arc.owner or 0] = true
			t.equal(arc.owner, if arc.x == 0 then 7 elseif arc.x == 30 then 9 else nil, "an arc's owner is its circle's")
		end
		t.expect(owners[7] and owners[9] and owners[0], "both units' arcs and the ghost's")
		for _, line in Ranges.polylines(arcs, function()
			return 0
		end) do
			t.expect(line.owner == nil or line.owner == 7 or line.owner == 9, "lines keep it too")
		end
	end)

	t.test("two overlapping circles give one outline with no interior arcs", function()
		local circles = { { x = 0, z = 0, r = 10, kind = "weapon" }, { x = 12, z = 0, r = 10, kind = "weapon" } }
		local arcs = Ranges.union(circles)
		t.equal(#arcs, 2, "one arc per circle")
		noInteriorArcs(t, circles, arcs)
		-- the two arcs meet at the intersection points: one closed outline
		local ends = {}
		for _, a in arcs do
			for _, ang in { a.a0, a.a1 } do
				local x, z = Ranges.at(a, ang)
				table.insert(ends, { x, z })
			end
		end
		for _, p in ends do
			local matched = 0
			for _, q in ends do
				if math.abs(p[1] - q[1]) < 1e-6 and math.abs(p[2] - q[2]) < 1e-6 then
					matched += 1
				end
			end
			t.equal(matched, 2, "every arc end meets another arc end")
		end
		-- each circle keeps 360 - 2 x acos(6/10) degrees
		local keep = TAU - 2 * math.acos(6 / 10)
		t.expect(math.abs(total(arcs) - 2 * keep) < 1e-9)
	end)

	t.test("separate circles stay separate; nested and identical ones vanish; kinds don't merge", function()
		local arcs = Ranges.union({ { x = 0, z = 0, r = 10, kind = "sight" }, { x = 30, z = 0, r = 10, kind = "sight" } })
		t.equal(#arcs, 2)
		for _, a in arcs do
			t.expect(math.abs((a.a1 - a.a0) - TAU) < 1e-9, "full circles")
		end
		arcs = Ranges.union({ { x = 0, z = 0, r = 20, kind = "radar" }, { x = 3, z = 0, r = 5, kind = "radar" } })
		t.equal(#arcs, 1, "the inner circle is hidden")
		t.equal(arcs[1].r, 20)
		arcs = Ranges.union({ { x = 0, z = 0, r = 10, kind = "weapon" }, { x = 0, z = 0, r = 10, kind = "weapon" } })
		t.equal(#arcs, 1, "identical circles draw once")
		arcs = Ranges.union({ { x = 0, z = 0, r = 10, kind = "weapon" }, { x = 5, z = 0, r = 10, kind = "sight" } })
		t.equal(#arcs, 2, "different kinds don't cut each other")
		t.expect(math.abs(total(arcs) - 2 * TAU) < 1e-9)
	end)

	t.test("a row of overlapping circles: outline only, crossing angle 0 handled", function()
		local circles = {}
		for i = 0, 9 do
			table.insert(circles, { x = i * 8, z = (i % 2) * 5, r = 12, kind = "weapon" })
		end
		local arcs = Ranges.union(circles)
		noInteriorArcs(t, circles, arcs)
		for _, a in arcs do
			t.expect(a.a1 > a.a0, "arcs run forward")
			t.expect(a.a1 - a.a0 <= TAU + 1e-9)
		end
		-- the leftmost circle's outer arc crosses angle π only; the rightmost one crosses 0 as one arc
		local right = 0
		for _, a in arcs do
			if a.x == 72 then
				right += 1
			end
		end
		t.equal(right, 1, "the rightmost circle's outer arc is one arc across angle 0")
	end)

	t.test("50 selected Lancers: circles by kind, own team only, and the cost", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "march_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
		for tick = 1, 3 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick / 15)
		end
		local ids = World.ownIds(world)
		t.equal(#ids, 50)
		local circles = Ranges.circles(world, ids)
		local kinds: { [string]: number } = {}
		for _, c in circles do
			kinds[c.kind] = (kinds[c.kind] or 0) + 1
		end
		t.equal(kinds.weapon, 50)
		t.equal(kinds.sight, 50)
		-- an enemy unit's ranges are never drawn
		local fake = table.clone(world.units[ids[1]])
		fake.id, fake.team = 999, 2
		world.units[999] = fake :: any
		t.equal(#Ranges.circles(world, { 999 }), 0)
		world.units[999] = nil
		-- the cost of a full recompute (what a selection or position change does)
		local runs = 50
		local t0 = Profiler.now()
		local arcs, lines
		for _ = 1, runs do
			arcs = Ranges.union(Ranges.circles(world, ids))
			lines = Ranges.polylines(arcs, function()
				return 10
			end)
		end
		local ms = (Profiler.now() - t0) / runs * 1000
		local points = 0
		for _, l in lines do
			points += #l.points
		end
		print(string.format("    50 Lancers: %d circles -> %d arcs, %d points; recompute %.2f ms (Lune)", #circles, #arcs, points, ms))
		t.expect(ms < 8, `recompute in {ms} ms`)
		noInteriorArcs(t, circles, arcs)
	end)

	t.test("known enemy defenses show their weapon rings: in sight, then as ghosts; radar blips and factories don't (C-41)", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:96", scenario = "empty" })
		Spawn.unit(sim, "ord_beacon", 1, -300, 0, 0) -- radar over the whole map
		local scout = Spawn.unit(sim, "ord_lancer", 1, -250, 60, math.pi / 2)
		local thorn = Spawn.unit(sim, "chs_thorn", 2, 300, 0, 0)
		Spawn.unit(sim, "chs_vehplant", 2, 300, 100, 0) -- a factory: never a ring
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 95, 95)))
		local memory = Ghosts.new()
		local known = { memory = memory.memory, sample = Icons.table(sim.defs).sample }
		local function run(ticks: number)
			for _ = 1, ticks do
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, sim.tick / 15)
				Ghosts.remember(memory, world)
				table.clear(world.died)
			end
		end
		local function move(x: number, z: number)
			assert(Sim.submit(sim, 1, Commands.toPoint(world.grid, Schema.CmdType.MOVE, { scout }, x, z)))
		end
		local thornRange = sim.defs.weaponByIndex[sim.defs.units.chs_thorn.weapons[1].weaponIndex].range
		-- 1. only on radar: an unknown blip, no ring
		run(30)
		local u = world.units[thorn]
		t.expect(u ~= nil and u.tier == "strategic" and bit32.band(u.flags or 0, Schema.StrategicFlag.RADAR_ONLY) ~= 0, "the Thorn starts as a radar blip")
		t.equal(#Ranges.enemyDefenses(world, known), 0)
		-- 2. the scout drives up and sees it: its anti-air ring, at the Thorn
		move(140, 60)
		run(15 * 14)
		u = world.units[thorn]
		t.expect(u ~= nil and u.tier == "tactical", "the Thorn is in sight")
		local seen = Ranges.enemyDefenses(world, known)
		t.equal(#seen, 1)
		t.equal(seen[1].kind, "enemyAa")
		t.equal(seen[1].r, thornRange)
		local tx, tz = sim.world.posX[thorn], sim.world.posZ[thorn]
		t.expect(math.abs(seen[1].x - tx) < 0.5 and math.abs(seen[1].z - tz) < 0.5, `ring at the Thorn ({seen[1].x}, {seen[1].z} vs {tx}, {tz})`)
		-- 3. the scout leaves: a ghost, the ring stays where the Thorn was seen
		move(-250, 60)
		run(15 * 14)
		u = world.units[thorn]
		t.expect(u ~= nil and u.tier == "strategic" and bit32.band(u.flags or 0, Schema.StrategicFlag.GHOST + Schema.StrategicFlag.RADAR_ONLY) ~= 0, "the Thorn is out of sight again")
		local ghost = Ranges.enemyDefenses(world, known)
		t.equal(#ghost, 1)
		t.expect(math.abs(ghost[1].x - tx) < 0.5 and math.abs(ghost[1].z - tz) < 0.5, "the remembered ring stays at the Thorn")
		-- the defense rule itself
		t.expect(Ranges.isDefense(sim.defs.units.chs_thorn), "a SAM site defends")
		t.expect(not Ranges.isDefense(sim.defs.units.chs_vehplant), "a factory doesn't")
		t.expect(not Ranges.isDefense(sim.defs.units.ord_lancer), "a tank isn't a structure")
	end)
end

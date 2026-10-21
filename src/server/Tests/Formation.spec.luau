--!strict
-- Formation slots (S-12, client request): the server's group moves use
-- Shared/Grid/Formation, so a client that knows the units' positions and
-- footprints computes exactly the server's goals.
local Formation = require("@shared/Grid/Formation")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local PlacementRules = require("@shared/Grid/PlacementRules")
local Nav = require("../Sim/Nav")
local Orders = require("../Sim/Orders")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

-- What a client computes for one group: footprints, the positions it last
-- saw and the order's points; no terrain (open ground keeps every slot).
local function predict(sim: Sim.Sim, members: { number }, air: boolean, posX: { [number]: number }, posZ: { [number]: number }, x: number, z: number, lx: number?, lz: number?): { [number]: { number } }
	local maxRadius, sumX, sumZ = 0, 0, 0
	for _, id in members do
		local def = sim.defs.unitByIndex[sim.world.defIndex[id]]
		maxRadius = math.max(maxRadius, def.footprint * PlacementRules.RADIUS_PER_FOOTPRINT)
		sumX += posX[id]
		sumZ += posZ[id]
	end
	local backX, backZ = sumX / #members, sumZ / #members
	local spacing = Formation.spacing(maxRadius)
	local cx, cz = x, z
	if lx ~= nil and lz ~= nil then
		cx, cz = (x + lx) / 2, (z + lz) / 2
	end
	local slots = if air or lx == nil
		then Formation.layout(#members, spacing, cx, cz, nil, nil, backX, backZ) -- aircraft: a spiral around the center
		else Formation.layout(#members, spacing, x, z, lx, lz, backX, backZ)
	Formation.deepestFirst(slots, cx, cz, backX, backZ, spacing)
	local pick = Formation.assign(posX, posZ, members, slots)
	local goals = {}
	for i, id in pick do
		if id ~= 0 then
			goals[id] = slots[i]
		end
	end
	return goals
end

return function(t: RunAll.Context)
	t.test("the server's constants and assignment are the shared ones", function()
		t.equal(Nav.SLOT_SPACING, Formation.SLOT_SPACING)
		t.equal(Nav.ASSIGN_BUCKET, Formation.ASSIGN_BUCKET)
		local posX, posZ = { [3] = 0, [7] = 10, [9] = 10 }, { [3] = 0, [7] = 0, [9] = 0 }
		local pick = Formation.assign(posX, posZ, { 3, 7, 9 }, { { 10, 0 }, { 0, 1 }, { 50, 50 }, { 0, 0 } })
		t.deepEqual(pick, { 7, 3, 9, 0 }, "closest unit per slot, ties to the lower ID, 0 once units run out")
	end)

	t.test("a sliced assignment picks exactly what one call picks (S-67)", function()
		local posX, posZ, members, slots = {}, {}, {}, {}
		for i = 1, 150 do
			posX[i * 3], posZ[i * 3] = (i * 37) % 400 - 200, (i * 91) % 300 - 150
			table.insert(members, i * 3)
		end
		for i = 1, 160 do
			table.insert(slots, { (i % 13) * 12 + 300, (i // 13) * 12 })
		end
		local whole, checks = Formation.assign(posX, posZ, members, slots)
		local a = Formation.newAssigner(posX, posZ, members, slots)
		local calls = 0
		repeat
			calls += 1
		until Formation.assignStep(a, 50)
		t.deepEqual(a.pick, whole)
		t.equal(a.checks, checks)
		t.expect(calls > 10, `spread over {calls} calls`)
	end)

	t.test("a select-all order gets its slots from the Pathing job, as an immediate one would (S-67)", function()
		local function goals(sliceMin: number): ({ [number]: { number } }, { [number]: { number } })
			local saved, savedBudget = Nav.SLICED_ASSIGN_MIN, Nav.PATHING_BUDGET
			Nav.SLICED_ASSIGN_MIN = sliceMin
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			local ids = {}
			for i = 0, 79 do
				table.insert(ids, Spawn.unit(sim, "ord_lancer", 1, -300 + (i % 10) * 12, -60 + (i // 10) * 12, 0))
			end
			local cell, ox, oz = (sim.map :: any).grid:encode(200, 0)
			local wr = Packer.Writer.new()
			Schema.encodeCommand(wr, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
			assert(Sim.submit(sim, 1, wr:finish()))
			Nav.PATHING_BUDGET, savedBudget = 0, Nav.PATHING_BUDGET -- the order is issued, its plan waits
			Sim.step(sim)
			local before = {}
			for _, id in ids do
				before[id] = { sim.world.goalX[id], sim.world.goalZ[id] }
			end
			Nav.PATHING_BUDGET = savedBudget
			Sim.step(sim)
			local after = {}
			for _, id in ids do
				after[id] = { sim.world.goalX[id], sim.world.goalZ[id] }
			end
			Nav.SLICED_ASSIGN_MIN = saved
			return before, after
		end
		local nowBefore, nowAfter = goals(math.huge)
		local slicedBefore, slicedAfter = goals(64)
		local centers, distinct = 0, {}
		local first = slicedBefore[next(slicedBefore) :: number]
		for id, g in slicedBefore do
			if g[1] == first[1] and g[2] == first[2] then
				centers += 1
			end
			distinct[`{nowBefore[id][1]},{nowBefore[id][2]}`] = true
		end
		t.equal(centers, 80, "sliced: every unit heads for the center at first")
		t.deepEqual(slicedAfter, nowAfter, "after one Pathing tick each unit has the slot an immediate assignment gave it")
		local n = 0
		for _ in distinct do
			n += 1
		end
		t.equal(n, 80, "80 distinct slots")
	end)

	t.test("layout: n slots, a line fills rows stepping back toward the centroid", function()
		local slots = Formation.layout(7, 10, 0, 0, 30, 0, 15, -50)
		t.equal(#slots, 7)
		t.deepEqual(slots[1], { 0, 0 })
		t.deepEqual(slots[4], { 30, 0 }, "4 per row on a 30-stud line at spacing 10")
		t.deepEqual(slots[5], { 0, -10 }, "the second row is on the centroid's side")
		Formation.deepestFirst(slots, 15, 0, 15, -50, 10)
		t.equal(slots[1][2], 0, "deepest first: the far row (from the centroid) leads")
		t.equal(slots[5][2], -10)
		local ring = Formation.layout(5, 4, 100, 100, nil, nil, 0, 0)
		t.deepEqual(ring, { { 100, 100 }, { 100, 96 }, { 96, 100 }, { 104, 100 }, { 100, 104 } }, "a spiral: center, then the nearest lattice points")
	end)

	t.test("a client computes the server's goals for line, spot and air moves", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local w = sim.world
		local tanks, mixed, air = {}, {}, {}
		for i = 0, 11 do
			table.insert(tanks, Spawn.unit(sim, "ord_lancer", 1, -120 + (i % 4) * 9, -100 + (i // 4) * 11))
		end
		for i = 0, 8 do
			table.insert(mixed, Spawn.unit(sim, if i % 2 == 0 then "ord_lancer" else "ord_herald", 1, 60 + (i % 3) * 12, -120 + (i // 3) * 10))
		end
		for i = 0, 5 do
			table.insert(air, Spawn.unit(sim, "ord_guardian", 1, -40 + i * 7, 100))
		end
		local cases = {
			{ "line move", tanks, 40, 60, 140, 20 },
			{ "short line, extra rows", tanks, -20, 120, 0, 130 },
			{ "spot move", tanks, -150, 150 },
			{ "spot move, two move classes (one group each)", mixed, 120, 120 },
			{ "air", air, 140, -140 },
			{ "air line", air, -100, 0, -100, 80 },
		}
		for _, c in cases do
			local label, members, x, z, lx, lz = c[1], c[2], c[3], c[4], c[5], c[6]
			local posX, posZ = {}, {}
			for _, id in members do
				posX[id], posZ[id] = w.posX[id], w.posZ[id]
			end
			-- the server groups an order's units by move class and clearance
			local groups: { [string]: { number } } = {}
			for _, id in members do
				local prof = sim.nav.profiles[w.defIndex[id]]
				local key = if prof.air then "air" else `{prof.moveClass}:{prof.need}`
				groups[key] = groups[key] or {}
				table.insert(groups[key], id)
			end
			local want: { [number]: { number } } = {}
			for _, group in groups do
				local air = sim.nav.profiles[w.defIndex[group[1]]].air
				for id, goal in predict(sim, group, air, posX, posZ, x, z, lx, lz) do
					want[id] = goal
				end
			end
			Orders.give(sim, members, { kind = "move", x = x, z = z, lx = lx, lz = lz }, false)
			Sim.step(sim)
			for _, id in members do
				local goal = want[id]
				t.expect(goal ~= nil, `{label}: unit {id} has a predicted slot`)
				if goal and (goal[1] ~= w.goalX[id] or goal[2] ~= w.goalZ[id]) then
					t.deepEqual({ w.goalX[id], w.goalZ[id] }, goal, `{label}: unit {id}'s goal`)
					return
				end
			end
			for _ = 1, 150 do
				Sim.step(sim)
			end
		end
	end)
end

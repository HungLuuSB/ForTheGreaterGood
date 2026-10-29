--!strict
local Packer = require("@shared/Net/Packer")
local Passability = require("@shared/Grid/Passability")
local Schema = require("@shared/Net/Schema")
local Combat = require("../Sim/Combat/Combat")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

local function build(sim: Sim.Sim, ids: { number }, defId: string, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = ids, defIndex = sim.defs.units[defId].index, cell = cell, offX = ox, offZ = oz, facing = 0 })
end

-- Steps until `pred` holds (returns the tick) or `limit` ticks pass (nil).
-- `onTick` sees each tick's events.
local function runUntil(sim: Sim.Sim, limit: number, pred: () -> boolean, onTick: ((Sim.Sim) -> ())?): number?
	for _ = 1, limit do
		Sim.step(sim)
		if onTick then
			onTick(sim)
		end
		if pred() then
			return sim.tick
		end
	end
	return nil
end

local function events(sim: Sim.Sim, kind: string): { Combat.Event }
	local out = {}
	for _, e in sim.combat.events do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- Enough income that factory tests measure production, not a power stall:
-- a Command Vehicle and two generators parked in a corner (+60 power/s).
local function fund(sim: Sim.Sim)
	Spawn.unit(sim, "ord_sovereign", 1, -200, -200)
	Spawn.unit(sim, "ord_solar", 1, -230, -230)
	Spawn.unit(sim, "ord_solar", 1, -230, -200)
end

local function newStart(): (Sim.Sim, number, number, number)
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
	local start = (sim.map :: any).layers.starts[1]
	local cv = Spawn.unit(sim, "ord_sovereign", 1, start[1], start[2], math.pi / 2)
	return sim, cv, start[1], start[2]
end

-- Time for `ids` to build a generator 60 studs east of the start.
local function generatorTime(withMason: boolean): number
	local sim, cv, sx, sz = newStart()
	local ids = { cv }
	if withMason then
		table.insert(ids, Spawn.unit(sim, "ord_mason", 1, sx, sz + 20, math.pi / 2))
	end
	build(sim, ids, "ord_solar", sx + 60, sz)
	local frame = 0
	local done = runUntil(sim, 2000, function()
		return frame ~= 0 and sim.world.buildProgress[frame] == 1
	end, function(s)
		for _, e in events(s, "BUILD_START") do
			frame = e.unit
		end
	end)
	return done :: number
end

return function(t: RunAll.Context)
	t.test("the Command Vehicle drives over and builds a generator that then produces", function()
		local sim, cv, sx, sz = newStart()
		local acc = sim.eco.accounts[1]
		build(sim, { cv }, "ord_solar", sx + 60, sz)
		local frame, started, maxDist = 0, 0, 0
		local w = sim.world
		local done = runUntil(sim, 2000, function()
			return frame ~= 0 and w.buildProgress[frame] == 1
		end, function(s)
			for _, e in events(s, "BUILD_START") do
				frame, started = e.unit, s.tick
				-- the frame starts only in range of where it stands (S-19: it used
				-- to start in range of the requested point, then the builder drove on)
				local reach = (s.defs.units.ord_sovereign.buildRange :: number) + s.defs.units.ord_solar.footprint * 4
				t.expect(math.abs(w.posX[cv] - w.posX[frame]) <= reach + 1e-6, `in range when the frame starts ({math.abs(w.posX[cv] - w.posX[frame])} studs)`)
			end
			if frame ~= 0 then
				maxDist = math.max(maxDist, math.abs(w.posX[cv] - w.posX[frame]))
			end
			t.expect(acc.supply.stored >= 0 and acc.power.stored >= 0, "stored never negative")
		end)
		t.expect(done ~= nil, "the generator was finished")
		local d = sim.defs.units.ord_solar
		-- 900 work units at BP 300 = 3 s = 45 ticks of building (no stall at 1,000 supply)
		t.expect(math.abs((done :: number) - started - 45) <= 2, `build took {(done :: number) - started} ticks`)
		t.equal(w.health[frame], d.health, "health grows to full with progress")
		t.expect(maxDist <= (sim.defs.units.ord_sovereign.buildRange :: number) + 4 + 1, "the CV stayed within build range")
		Sim.step(sim) -- (economy step comes at the next multiple of 5)
		for _ = 1, 5 do
			Sim.step(sim)
		end
		t.equal(acc.power.income, 20 + 20, "CV + new generator")
	end)

	t.test("assisting builders add their build power", function()
		local alone = generatorTime(false)
		local helped = generatorTime(true)
		t.expect(helped < alone, `with a Mason {helped} ticks vs alone {alone}`)
	end)

	t.test("a stalled team builds slower and never overspends", function()
		local function vehplantTicks(startSupply: number): (number?, boolean)
			local sim, cv, sx, sz = newStart()
			local acc = sim.eco.accounts[1]
			acc.supply.stored = startSupply
			build(sim, { cv }, "ord_vehplant", sx + 70, sz)
			local frame = 0
			local neverNegative = true
			local done = runUntil(sim, 9000, function()
				return frame ~= 0 and sim.world.buildProgress[frame] == 1
			end, function(s)
				for _, e in events(s, "BUILD_START") do
					frame = e.unit
				end
				neverNegative = neverNegative and acc.supply.stored >= 0 and acc.power.stored >= 0
			end)
			return done, neverNegative
		end
		local fullTicks, ok1 = vehplantTicks(1000)
		local starvedTicks, ok2 = vehplantTicks(50)
		t.expect(fullTicks ~= nil and starvedTicks ~= nil, "both plants were finished")
		t.expect(ok1 and ok2, "stored never went negative")
		t.expect((starvedTicks :: number) > (fullTicks :: number) * 2, `starved {starvedTicks} vs full {fullTicks}`)
		-- 600 supply at 1 supply/s income (+50 start) can't finish before ~550 s
		t.expect((starvedTicks :: number) > 15 * 500, "progress was limited by income")
	end)

	t.test("resource priority: in a stall, high consumers are served first, low ones get what is left (S-156)", function()
		-- two Vehicle Plants on one Lancer each; supply income covers one
		local function progress(lowFirst: boolean): (number, number)
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			local a = Spawn.unit(sim, "ord_vehplant", 1, -60, 0, math.pi / 2)
			local b = Spawn.unit(sim, "ord_vehplant", 1, 60, 0, math.pi / 2)
			local acc = sim.eco.accounts[1]
			local lancer = sim.defs.units.ord_lancer
			acc.supply.stored = 0
			acc.supply.bonusIncome = lancer.cost.supply * 200 / lancer.cost.buildTime
			acc.power.bonusIncome = 1000
			build(sim, { a }, "ord_lancer", 0, 0)
			build(sim, { b }, "ord_lancer", 0, 0)
			if lowFirst then
				submit(sim, 1, { cmdType = CT.PRIORITY, flags = 0, unitIds = { a }, value = 0 })
			end
			for _ = 1, 150 do
				Sim.step(sim)
			end
			t.equal(bit32.band(sim.world.state[a], World.State.LOW_PRIORITY) ~= 0, lowFirst, "the LOW_PRIORITY bit follows the command")
			return sim.build.progress[a] or 0, sim.build.progress[b] or 0
		end
		local full = 200 / 5100 * 10 -- a plant's progress in 10 s at full supply
		local evenA, evenB = progress(false)
		t.expect(math.abs(evenA - evenB) < 0.01 and evenA < full * 0.6, `both high: they share alike ({evenA}, {evenB})`)
		local lowA, highB = progress(true)
		t.expect(highB > full * 0.9, `the high plant runs at full speed: {highB} of {full}`)
		t.expect(lowA < full * 0.1, `the low plant gets what is left, next to nothing: {lowA}`)

		-- PRIORITY 1 makes it high again
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0)
		submit(sim, 1, { cmdType = CT.PRIORITY, flags = 0, unitIds = { plant }, value = 0 })
		submit(sim, 1, { cmdType = CT.PRIORITY, flags = 0, unitIds = { plant }, value = 1 })
		Sim.step(sim)
		t.equal(bit32.band(sim.world.state[plant], World.State.LOW_PRIORITY), 0, "high again")
	end)

	t.test("invalid sites fail with a reason", function()
		local sim, cv, sx, sz = newStart()
		build(sim, { cv }, "ord_extractor", sx + 30, sz) -- no deposit there
		local reason = nil
		runUntil(sim, 600, function()
			return reason ~= nil
		end, function(s)
			for _, e in events(s, "BUILD_FAILED") do
				reason = e.reason
			end
		end)
		t.equal(reason, "no deposit")
	end)

	t.test("factories produce their queue in order and units roll out", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim)
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2) -- exit faces +X
		build(sim, { plant }, "ord_lancer", 0, 0)
		build(sim, { plant }, "ord_mason", 0, 0)
		local produced = {}
		runUntil(sim, 3000, function()
			return #produced == 2
		end, function(s)
			for _, e in events(s, "PRODUCED") do
				table.insert(produced, { tick = s.tick, unit = e.unit })
			end
		end)
		t.equal(#produced, 2)
		local w = sim.world
		t.equal(w.defIndex[produced[1].unit], sim.defs.units.ord_lancer.index, "first in queue first out")
		t.equal(w.defIndex[produced[2].unit], sim.defs.units.ord_mason.index)
		-- 5,100 work units at BP 200 (S-94) = 25.5 s = 383 ticks
		t.expect(math.abs(produced[1].tick - 383) <= 3, `lancer finished at tick {produced[1].tick}`)
		for _ = 1, 60 do
			Sim.step(sim)
		end
		t.expect(w.posX[produced[1].unit] > 12 + 8, "the new tank drove out of the plant")
		t.expect(not Passability.canEnter(sim.map :: any, "TRACKED", (sim.map :: any).grid:index(32, 32)), "the plant blocks its cells")
	end)

	t.test("a produced unit appears on the build pad and drives out through its factory (S-133, client request 61)", function()
		local Build = require("../Sim/Build")
		local Blockouts = require("@shared/Defs/Blockouts/Registry")
		for _, heading in { math.pi / 2, 0, -math.pi / 2, math.pi } do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			fund(sim)
			local w = sim.world
			local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, heading)
			build(sim, { plant }, "ord_lancer", 0, 0)
			local unit = 0
			runUntil(sim, 3000, function()
				return unit ~= 0
			end, function(s)
				for _, e in events(s, "PRODUCED") do
					unit = e.unit
				end
			end)
			-- the blockout's pad, turned like the client turns the model (heading + π about +Y)
			local pad
			for _, a in (Blockouts :: any).ord_vehplant.attachments do
				if a.name == "buildpad" then
					pad = a.at
				end
			end
			local c, sn = math.cos(heading), math.sin(heading)
			local px, pz = w.posX[plant] - pad[1] * c - pad[3] * sn, w.posZ[plant] + pad[1] * sn - pad[3] * c
			local fx, fz = math.sin(heading), math.cos(heading)
			-- it appeared on the pad (then moved at most a tick): just in front of centre, inside the footprint
			local ahead = (w.posX[unit] - w.posX[plant]) * fx + (w.posZ[unit] - w.posZ[plant]) * fz
			t.expect(math.abs(ahead - (-pad[3])) < 2, `on the pad: {ahead} studs ahead of centre (pad {-pad[3]}, heading {heading})`)
			local bx, bz = Build.padPosition(sim, plant)
			t.expect(math.abs(bx - px) < 1e-9 and math.abs(bz - pz) < 1e-9, "padPosition follows the client's turn")
			t.expect(math.abs(w.heading[unit] - heading) < 0.2 or math.abs(math.abs(w.heading[unit] - heading) - 2 * math.pi) < 0.2, "facing the exit")
			t.expect(sim.build.exiting[unit] ~= nil, "driving out")
			for _ = 1, 150 do
				Sim.step(sim)
			end
			ahead = (w.posX[unit] - w.posX[plant]) * fx + (w.posZ[unit] - w.posZ[plant]) * fz
			local side = (w.posX[unit] - w.posX[plant]) * fz - (w.posZ[unit] - w.posZ[plant]) * fx
			t.expect(ahead > 16 + 8, `out of the front of the plant ({ahead} studs ahead, heading {heading})`)
			t.expect(math.abs(side) < 6, `straight out of the door ({side} studs aside)`)
			t.equal(sim.build.exiting[unit], nil, "and clear of it")
		end
	end)

	t.test("BUILD's facing turns the frame, so its pad and exit lane face that way (S-160, the user's reference #7)", function()
		for facing = 0, 3 do
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			fund(sim)
			local w = sim.world
			local mason = Spawn.unit(sim, "ord_mason", 1, 40, 0)
			local g = (sim.map :: any).grid
			local cell, ox, oz = g:encode(0, 0)
			submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { mason }, defIndex = sim.defs.units.ord_vehplant.index, cell = cell, offX = ox, offZ = oz, facing = facing })
			local plant = 0
			runUntil(sim, 600, function()
				return plant ~= 0
			end, function(s)
				for _, id in s.world.ids do
					if s.defs.unitByIndex[s.world.defIndex[id]].id == "ord_vehplant" then
						plant = id
					end
				end
			end)
			t.expect(plant ~= 0, `the frame started (facing {facing})`)
			local h = w.heading[plant]
			t.expect(math.abs(math.sin(h - facing * math.pi / 2)) < 1e-9 and math.cos(h - facing * math.pi / 2) > 0, `heading = facing × 90° ({h}, facing {facing})`)
			local px, pz = require("../Sim/Build").padPosition(sim, plant)
			local fx, fz = math.sin(h), math.cos(h)
			local ahead = (px - w.posX[plant]) * fx + (pz - w.posZ[plant]) * fz
			local side = (px - w.posX[plant]) * fz - (pz - w.posZ[plant]) * fx
			t.expect(math.abs(side) < 1e-6, `the pad on the facing's axis (facing {facing}, {side} aside, {ahead} ahead)`)
		end
		local Facing = Schema.Facing
		t.deepEqual({ Facing.NORTH, Facing.EAST, Facing.SOUTH, Facing.WEST }, { 0, 1, 2, 3 }, "0 north (+Z), 1 east (+X), 2 south, 3 west")
	end)

	t.test("a unit ordered behind its factory while driving out goes round it (S-161: the order was unreachable from inside the footprint)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim)
		local w = sim.world
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2) -- facing east
		build(sim, { plant }, "ord_lancer", 0, 0)
		local unit = 0
		runUntil(sim, 3000, function()
			return unit ~= 0
		end, function(s)
			for _, e in events(s, "PRODUCED") do
				unit = e.unit
			end
		end)
		t.expect(unit ~= 0 and sim.build.exiting[unit] ~= nil, "produced, still in the footprint")
		local g = (sim.map :: any).grid
		local cell, ox, oz = g:encode(-120, 0)
		submit(sim, 1, { cmdType = CT.MOVE, flags = 0, unitIds = { unit }, cell = cell, offX = ox, offZ = oz })
		for _ = 1, 15 * 30 do
			Sim.step(sim)
		end
		local d = math.sqrt((w.posX[unit] + 120) ^ 2 + w.posZ[unit] ^ 2)
		t.expect(d < 24, `it got round the plant to the west ({d} studs off)`)
	end)

	t.test("a factory waits while a unit is still on its pad (S-133, the user)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim)
		local w = sim.world
		local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
		build(sim, { plant }, "ord_lancer", 0, 0)
		build(sim, { plant }, "ord_lancer", 0, 0)
		local first = 0
		runUntil(sim, 3000, function()
			return first ~= 0
		end, function(s)
			for _, e in events(s, "PRODUCED") do
				first = e.unit
			end
		end)
		-- hold the first tank on the pad: stuck
		local px, pz = w.posX[first], w.posZ[first]
		for _ = 1, 300 do
			World.setPosition(w, first, px, pz)
			Sim.step(sim)
		end
		t.equal(sim.build.progress[plant], 0, "no progress while the pad is taken")
		t.expect(sim.build.exiting[first] ~= nil, "the tank is still in the plant")
		local freedAt = runUntil(sim, 300, function()
			return sim.build.exiting[first] == nil
		end)
		t.expect(freedAt ~= nil, "let go, it drives out")
		runUntil(sim, 30, function()
			return false
		end)
		t.expect((sim.build.progress[plant] or 0) > 0, "and the plant builds again")
	end)

	t.test("aircraft appear on their airfield's pad", function()
		local Build = require("../Sim/Build")
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim)
		local w = sim.world
		local field = Spawn.unit(sim, "ord_airfield", 1, 40, 40, 0)
		local opts = sim.defs.unitByIndex[w.defIndex[field]].buildOptions :: { string }
		build(sim, { field }, opts[1], 40, 40)
		local unit = 0
		runUntil(sim, 6000, function()
			return unit ~= 0
		end, function(s)
			for _, e in events(s, "PRODUCED") do
				unit = e.unit
			end
		end)
		t.expect(unit ~= 0, "produced")
		local px, pz = Build.padPosition(sim, field)
		t.expect(math.abs(w.posX[unit] - px) < 3 and math.abs(w.posZ[unit] - pz) < 3, `on the pad ({w.posX[unit]}, {w.posZ[unit]} vs {px}, {pz})`)
		t.equal(sim.build.exiting[unit], nil, "aircraft don't drive out")
	end)

	t.test("a factory still being built takes a queue and starts on it when finished (S-138, client request 63)", function()
		local sim, cv, sx, sz = newStart()
		fund(sim)
		local w = sim.world
		build(sim, { cv }, "ord_vehplant", sx + 60, sz)
		local frame = 0
		runUntil(sim, 600, function()
			return frame ~= 0
		end, function(s)
			for _, e in events(s, "BUILD_START") do
				frame = e.unit
			end
		end)
		t.expect(frame ~= 0 and w.buildProgress[frame] < 1, "a plant frame going up")
		build(sim, { frame }, "ord_lancer", 0, 0)
		build(sim, { frame }, "ord_lancer", 0, 0)
		build(sim, { frame }, "ord_mason", 0, 0)
		Sim.step(sim)
		t.equal(#sim.build.queue[frame], 3, "the frame took the queue")
		submit(sim, 1, { cmdType = CT.CANCEL, flags = 0, unitIds = { frame }, value = 3 })
		Sim.step(sim)
		t.equal(#sim.build.queue[frame], 2, "CANCEL n drops a queued item, the frame stays")
		t.expect(w.slot[frame] ~= nil, "still there")
		local produced = 0
		local finishedAt = runUntil(sim, 3000, function()
			return w.buildProgress[frame] >= 1
		end, function(s)
			t.equal(s.build.progress[frame] or 0, 0, "nothing produced or spent before it's finished")
			produced += #events(s, "PRODUCED")
		end)
		t.expect(finishedAt ~= nil, "the plant finished")
		t.equal(produced, 0, "no unit before then")
		runUntil(sim, 30, function()
			return false
		end)
		t.expect((sim.build.progress[frame] or 0) > 0, "and it starts on its queue at once")
		-- CANCEL 0 on a frame with a queue clears the queue first, then a second removes the frame
		build(sim, { cv }, "ord_vehplant", sx + 60, sz + 80)
		local frame2 = 0
		runUntil(sim, 600, function()
			return frame2 ~= 0
		end, function(s)
			for _, e in events(s, "BUILD_START") do
				frame2 = e.unit
			end
		end)
		build(sim, { frame2 }, "ord_lancer", 0, 0)
		Sim.step(sim)
		t.equal(#sim.build.queue[frame2], 1, "queued")
		submit(sim, 1, { cmdType = CT.CANCEL, flags = 0, unitIds = { frame2 }, value = 0 })
		Sim.step(sim)
		t.equal(#sim.build.queue[frame2], 0, "the first CANCEL 0 clears the queue")
		t.expect(w.slot[frame2] ~= nil, "and leaves the frame")
		submit(sim, 1, { cmdType = CT.CANCEL, flags = 0, unitIds = { frame2 }, value = 0 })
		Sim.step(sim)
		t.equal(w.slot[frame2], nil, "the second removes the frame")
	end)

	t.test("building over your own units: the frame starts and they walk out; an enemy still blocks (S-155, the user)", function()
		local Passability = require("@shared/Grid/Passability")
		local function attempt(blockerTeam: number): (Sim.Sim, number, number)
			local sim, cv, sx, sz = newStart()
			fund(sim)
			local w = sim.world
			local site = sx + 60
			local tank = Spawn.unit(sim, if blockerTeam == 1 then "ord_lancer" else "chs_ravager", blockerTeam, site + 2, sz + 3)
			World.setFireState(w, tank, World.FireState.HOLD_FIRE)
			World.setHealth(w, tank, 1e7)
			build(sim, { cv }, "ord_vehplant", site, sz)
			local frame = 0
			runUntil(sim, 400, function()
				return frame ~= 0
			end, function(s)
				for _, e in events(s, "BUILD_START") do
					frame = e.unit
				end
			end)
			return sim, frame, tank
		end
		local sim, frame, tank = attempt(1)
		t.expect(frame ~= 0, "the frame started over the friendly tank")
		runUntil(sim, 150, function()
			return false
		end)
		local w = sim.world
		local pm = sim.map :: any
		local cx, cz = pm.grid:cellAt(w.posX[tank], w.posZ[tank])
		t.equal(Passability.occupant(pm, pm.grid:index(cx, cz)), 0, "the tank walked out of the footprint")
		t.equal(sim.build.exiting[tank], nil, "and is clear of it")
		local _, frame2 = attempt(2)
		t.equal(frame2, 0, "an enemy tank on the site still blocks it")
	end)

	t.test("a builder assisting a factory speeds up production", function()
		local function firstLancer(assist: boolean): number
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			fund(sim)
			local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
			if assist then
				local cv = Spawn.unit(sim, "ord_sovereign", 1, -40, 0)
				submit(sim, 1, { cmdType = CT.REPAIR, flags = 0, unitIds = { cv }, targetId = plant })
			end
			build(sim, { plant }, "ord_lancer", 0, 0)
			local tick = 0
			runUntil(sim, 3000, function()
				return tick ~= 0
			end, function(s)
				for _ in events(s, "PRODUCED") do
					tick = s.tick
				end
			end)
			return tick
		end
		local alone, helped = firstLancer(false), firstLancer(true)
		t.expect(alone > 0 and helped > 0, "both produced")
		t.expect(helped < alone / 2, `assisted {helped} vs alone {alone} ticks (BP 100 + 300)`)
	end)

	t.test("reclaiming a wreck returns its supply", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		local victim = Spawn.unit(sim, "chs_ravager", 2, 40, 0)
		sim.world.health[victim] = 1
		Combat.queueDamage(sim.combat, victim, 100, 0) -- low overkill: leaves a wreck
		Sim.step(sim)
		local wreck = sim.combat.wreckIds[1]
		t.expect(wreck ~= nil, "a wreck")
		local value = sim.combat.wreckSupply[wreck]
		t.equal(value, sim.defs.units.chs_ravager.cost.supply * 0.5) -- half its supply
		local mason = Spawn.unit(sim, "ord_mason", 1, -20, 0)
		local acc = sim.eco.accounts[1]
		acc.supply.stored = 0
		submit(sim, 1, { cmdType = CT.RECLAIM, flags = 0, unitIds = { mason }, targetId = wreck })
		local done = runUntil(sim, 600, function()
			return sim.combat.wreckX[wreck] == nil
		end)
		t.expect(done ~= nil, "the wreck was reclaimed")
		for _ = 1, 5 do
			Sim.step(sim) -- settle the window
		end
		t.expect(math.abs(acc.supply.stored - value) < 1e-6, `stored {acc.supply.stored}, expected {value}`)
		t.equal(#sim.combat.wreckIds, 0)
	end)

	t.test("a frame destroyed mid-build frees its footprint and its builders", function()
		local sim, cv, sx, sz = newStart()
		build(sim, { cv }, "ord_vehplant", sx + 70, sz)
		local frame = 0
		runUntil(sim, 600, function()
			return frame ~= 0 and sim.world.buildProgress[frame] > 0.1
		end, function(s)
			for _, e in events(s, "BUILD_START") do
				frame = e.unit
			end
		end)
		local pm = sim.map :: any
		local cell = pm.grid:index(pm.grid:cellAt(sim.world.posX[frame], sim.world.posZ[frame]))
		t.equal(Passability.occupant(pm, cell), frame)
		Combat.queueDamage(sim.combat, frame, 1e6, 0)
		Sim.step(sim)
		Sim.step(sim)
		t.equal(Passability.occupant(pm, cell), 0, "footprint released")
		t.equal(sim.build.target[cv] or 0, 0, "the CV stopped building") -- idle: no target (nil or 0)
	end)

	t.test("construction is deterministic", function()
		local function run(): number
			local sim, cv, sx, sz = newStart()
			build(sim, { cv }, "ord_solar", sx + 60, sz)
			for _ = 1, 400 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run())
	end)

	-- S-35 (guide 9.3): cancelling refunds what was spent
	t.test("CANCEL: a frame goes and refunds its progress; a factory drops queue items, refunding the one in production", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim)
		local w = sim.world
		local acc = sim.eco.accounts[1]
		local cv = Spawn.unit(sim, "ord_sovereign", 1, -40, 0)
		build(sim, { cv }, "ord_vehplant", -20, 40)
		local frame = 0
		runUntil(sim, 3000, function()
			for _, id in w.ids do
				if w.defIndex[id] == sim.defs.units.ord_vehplant.index and w.buildProgress[id] >= 0.3 then
					frame = id
					return true
				end
			end
			return false
		end)
		local progress = w.buildProgress[frame]
		t.expect(frame ~= 0 and progress < 0.7, `a part-built plant ({progress})`)
		local cost = sim.defs.units.ord_vehplant.cost
		local Build = require("../Sim/Build")
		local s0, p0 = acc.supply.reclaimed, acc.power.reclaimed
		t.expect(Build.cancelFrame(sim, frame), "cancelled")
		t.expect(math.abs(acc.supply.reclaimed - s0 - cost.supply * progress) < 1e-6, "supply spent comes back")
		t.expect(math.abs(acc.power.reclaimed - p0 - cost.power * progress) < 1e-6, "and power")
		t.equal(w.slot[frame], nil, "the frame is gone")
		Sim.step(sim)
		t.expect(sim.build.target[cv] == nil or sim.build.target[cv] == 0, "its builder stopped")

		-- through the command: another frame
		build(sim, { cv }, "ord_vehplant", -20, 40)
		local frame2 = 0
		runUntil(sim, 3000, function()
			for _, id in w.ids do
				if w.defIndex[id] == sim.defs.units.ord_vehplant.index and w.buildProgress[id] > 0 then
					frame2 = id
					return true
				end
			end
			return false
		end)
		submit(sim, 1, { cmdType = CT.CANCEL, flags = 0, unitIds = { frame2 }, value = 0 })
		Sim.step(sim)
		t.equal(w.slot[frame2], nil, "CANCEL on a frame removes it")

		-- a factory: the head item in production is refunded its progress
		local sim2 = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
		fund(sim2)
		local plant = Spawn.unit(sim2, "ord_vehplant", 1, 0, 0, math.pi / 2)
		build(sim2, { plant }, "ord_lancer", 0, 0)
		build(sim2, { plant }, "ord_mason", 0, 0)
		build(sim2, { plant }, "ord_lancer", 0, 0)
		for _ = 1, 300 do
			Sim.step(sim2)
		end
		local b = sim2.build
		local p = b.progress[plant]
		t.expect(p > 0.2 and p < 1, `the first Lancer is in production ({p})`)
		local acc2 = sim2.eco.accounts[1]
		local lancer = sim2.defs.units.ord_lancer
		local r0 = acc2.supply.reclaimed
		Build.cancelQueued(sim2, plant, 1)
		t.expect(math.abs(acc2.supply.reclaimed - r0 - lancer.cost.supply * p) < 1e-6, "the Lancer's spend is refunded")
		t.equal(#b.queue[plant], 2, "two items left")
		t.equal(b.queue[plant][1], sim2.defs.units.ord_mason.index, "the Mason is next")
		t.equal(b.progress[plant], 0, "starting from scratch")
		Build.cancelQueued(sim2, plant, 2)
		t.equal(#b.queue[plant], 1, "a queued item goes without a refund")
		submit(sim2, 1, { cmdType = CT.CANCEL, flags = 0, unitIds = { plant }, value = 0 })
		Sim.step(sim2)
		t.equal(#b.queue[plant], 0, "CANCEL 0 clears the queue")
	end)
end

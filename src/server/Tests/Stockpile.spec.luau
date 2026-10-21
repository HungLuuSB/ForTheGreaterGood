--!strict
-- Missile stockpiles (S-47, client request 25): SAMs fire only from stock and
-- build missiles one at a time, paying for each like construction.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Economy = require("../Sim/Economy")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Stockpile = require("../Sim/Stockpile")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	local ok, err = Sim.submit(sim, player, w:finish())
	assert(ok, err)
end

local function stock(sim: Sim.Sim, id: number): number?
	return sim.world.wStock[World.slotKey(id, 1)]
end

-- Plenty of both resources, no income: what a stockpile spends shows in
-- `stored`. Storage is recomputed every economy step, so `bigStorage` raises
-- the base storage while `fn` runs.
local function rich(sim: Sim.Sim, team: number)
	local acc = sim.eco.accounts[team]
	for _, r in { acc.supply, acc.power } do
		r.storage = 1e5
		r.stored = 1e5
	end
end

local function bigStorage(fn: () -> ())
	local base = Economy.BASE_STORAGE
	Economy.BASE_STORAGE = 1e5
	local ok, err = pcall(fn)
	Economy.BASE_STORAGE = base
	if not ok then
		error(err, 0)
	end
end

local function launches(sim: Sim.Sim, shooter: number): number
	local n = 0
	for _, e in sim.combat.events do
		if e.kind == "SPAWN_PROJ" and e.unit == shooter then
			n += 1
		end
	end
	return n
end

-- A Thorn (Chaos) under a hovering Order helicopter that can't die.
local function siteUnderHeli(): (Sim.Sim, number, number)
	local sim = Sim.new({ seed = 4, players = PLAYERS, mapId = "flat:64" })
	local thorn = Spawn.unit(sim, "chs_thorn", 2, 0, 0, 0)
	local heli = Spawn.unit(sim, "ord_guardian", 1, 120, 0, 0)
	World.setHealth(sim.world, heli, 1e9)
	World.setMoveState(sim.world, heli, World.MoveState.HOLD_POSITION)
	sim.ew.flares[heli] = 0
	return sim, thorn, heli
end

return function(t: RunAll.Context)
	t.test("spawned SAMs start full, each unit with its own capacity; other weapons have no stockpile", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local want = {
			chs_thorn = 10, -- Chaos: more, cheaper missiles (S-62)
			ord_vigil = 8,
			chs_hornet = 5,
			ord_halo = 4,
			chs_wyvern = 18,
			ord_aegis = 15,
			chs_gorgon = 4,
			ord_seraph = 3,
		}
		local x = -200
		for defId, capacity in want do
			local id = Spawn.unit(sim, defId, 1, x, 0, 0)
			x += 40
			t.equal(stock(sim, id), capacity, `{defId} starts with {capacity}`)
			t.equal(Stockpile.capacity(sim, id, 1), capacity)
		end
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 0, 100, 0)
		t.equal(stock(sim, lancer), nil, "a tank gun has no stockpile")
		t.equal(Stockpile.capacity(sim, lancer, 1), nil)
	end)

	t.test("each shot spends a missile and an empty site holds its fire", function()
		bigStorage(function()
			local sim, thorn = siteUnderHeli()
			local acc = sim.eco.accounts[2]
			acc.supply.stored, acc.power.stored = 0, 0 -- stalled: no new missiles
			sim.world.wStock[World.slotKey(thorn, 1)] = 2
			local fired = 0
			for _ = 1, 450 do
				Sim.step(sim)
				fired += launches(sim, thorn)
			end
			t.equal(fired, 2, "two missiles in stock, two launches in 30 s")
			t.equal(stock(sim, thorn), 0)
			t.equal(sim.world.wStockProgress[World.slotKey(thorn, 1)], 0, "a stalled team builds nothing")

			-- money again: the next missile comes after its buildTime (6 s) and goes at once
			rich(sim, 2)
			local nextAt: number? = nil
			local start = sim.tick
			for _ = 1, 150 do
				Sim.step(sim)
				if launches(sim, thorn) > 0 and nextAt == nil then
					nextAt = sim.tick - start
				end
			end
			t.expect(nextAt ~= nil and nextAt >= 89 and nextAt <= 96, `the built missile was launched after {nextAt} ticks`)
		end)
	end)

	t.test("a site refills one missile per buildTime up to capacity and pays each missile's cost", function()
		bigStorage(function()
			local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:64" })
			local thorn = Spawn.unit(sim, "chs_thorn", 2, 0, 0, 0)
			Stockpile.empty(sim, thorn) -- 10 missiles, 6 s and 12 + 240 each (S-62)
			rich(sim, 2)
			local acc = sim.eco.accounts[2]
			local supply0, power0 = acc.supply.stored, acc.power.stored
			local reached: { number } = {}
			for _ = 1, 980 do
				Sim.step(sim)
				local n = stock(sim, thorn) :: number
				if n > #reached then
					table.insert(reached, sim.tick)
				end
			end
			t.equal(#reached, 10, "full at capacity, never above")
			t.expect(math.abs(reached[1] - 90) <= 2, `first missile at tick {reached[1]} (6 s)`)
			t.expect(math.abs(reached[10] - 900) <= 5, `tenth at tick {reached[10]} (60 s)`)
			-- settle the last economy window
			for _ = 1, 10 do
				Sim.step(sim)
			end
			t.expect(math.abs(supply0 - acc.supply.stored - 10 * 12) < 0.01, `supply spent {supply0 - acc.supply.stored}`)
			t.expect(math.abs(power0 - acc.power.stored - 10 * 240) < 0.01, `power spent {power0 - acc.power.stored}`)
			t.equal(acc.supply.demand, 0, "a full site demands nothing")
		end)
	end)

	t.test("units out of a factory start empty and fill up", function()
		bigStorage(function()
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			rich(sim, 1)
			local plant = Spawn.unit(sim, "ord_vehplant", 1, 0, 0, math.pi / 2)
			local g = (sim.map :: any).grid
			local cell, ox, oz = g:encode(0, 0)
			submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { plant }, defIndex = sim.defs.units.ord_halo.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
			local halo: number? = nil
			for _ = 1, 3000 do
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "PRODUCED" then
						halo = e.unit
					end
				end
				if halo then
					break
				end
			end
			assert(halo, "the Halo rolled out")
			t.equal(stock(sim, halo), 0, "a produced Halo starts empty")
			for _ = 1, 4 * 90 + 10 do
				Sim.step(sim)
			end
			t.equal(stock(sim, halo), 4, "and fills to its 4 in 24 s")
		end)
	end)

	t.test("a site built from a frame starts empty and fills up", function()
		bigStorage(function()
			local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "start:64" })
			rich(sim, 1)
			local mason = Spawn.unit(sim, "ord_mason", 1, 0, 0, 0)
			local g = (sim.map :: any).grid
			local cell, ox, oz = g:encode(40, 0)
			submit(sim, 1, { cmdType = CT.BUILD, flags = 0, unitIds = { mason }, defIndex = sim.defs.units.ord_vigil.index, cell = cell, offX = ox, offZ = oz, facing = 0 })
			local vigil: number? = nil
			for _ = 1, 3000 do
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "BUILD_START" then
						vigil = e.unit
					end
				end
				if vigil and sim.world.buildProgress[vigil] >= 1 then
					break
				end
			end
			assert(vigil and sim.world.buildProgress[vigil] >= 1, "the Vigil was built")
			t.equal(stock(sim, vigil), 0, "a finished site starts empty")
			for _ = 1, 100 do
				Sim.step(sim)
			end
			t.equal(stock(sim, vigil), 1, "its first missile after 6 s")
		end)
	end)

	t.test("the owner gets its units' stock on the wire, nobody else does", function()
		local sim, thorn = siteUnderHeli()
		local g = (sim.map :: any).grid
		for pid = 1, 2 do
			submit(sim, pid, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = 0, minZ = 0, maxX = 63, maxZ = 63 })
		end
		local views = { Client.new(g), Client.new(g) }
		local exact, leaked, changes, progressOff = 0, 0, 0, 0
		local last = -1
		for _ = 1, 300 do
			Sim.step(sim)
			for pid = 1, 2 do
				Client.receive(views[pid], sim.net.players[pid].outbox)
			end
			local u = views[2].units[thorn]
			local got = if u and u.stock then u.stock[1] else nil
			if got == stock(sim, thorn) then
				exact += 1
			end
			-- the next missile's progress, within one wire step (S-49)
			local gotP = if u and u.stockProgress then u.stockProgress[1] / 255 else 0
			progressOff = math.max(progressOff, math.abs(gotP - sim.world.wStockProgress[World.slotKey(thorn, 1)]))
			if got ~= last then
				changes += 1
				last = got :: number
			end
			for _, v in views[1].units do
				if v.stock then
					leaked += 1
				end
			end
		end
		t.expect(exact >= 299, `the owner's view matches the stock every tick after the first ({exact} of 300)`)
		t.expect(changes >= 3, `the stock changed on the wire ({changes} values)`)
		t.equal(leaked, 0, "the other player never gets stock")
		t.expect(progressOff <= 1 / Stockpile.WIRE_STEPS + 1 / 255, `the owner's progress stays within a step ({progressOff})`)
	end)

	t.test("stockpiles are deterministic and in the state hash", function()
		local function run(): number
			local sim, thorn = siteUnderHeli()
			Stockpile.empty(sim, thorn)
			for _ = 1, 400 do
				Sim.step(sim)
			end
			return Sim.hash(sim)
		end
		t.equal(run(), run())
		local sim, thorn = siteUnderHeli()
		local h = Sim.hash(sim)
		sim.world.wStock[World.slotKey(thorn, 1)] = 7
		t.expect(Sim.hash(sim) ~= h, "the stock is hashed")
	end)
end

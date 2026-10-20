--!strict
local Packer = require("@shared/Net/Packer")
local Prng = require("@shared/Util/Prng")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local L = Sensors.Level
local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, player: number, cmd: Schema.Command)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, cmd)
	assert(Sim.submit(sim, player, w:finish()))
end

local function camera(sim: Sim.Sim, player: number, minX: number, minZ: number, maxX: number, maxZ: number)
	submit(sim, player, { cmdType = CT.CAMERA, flags = 0, unitIds = {}, minX = minX, minZ = minZ, maxX = maxX, maxZ = maxZ })
end

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local g = (sim.map :: any).grid
	local cell, ox, oz = g:encode(x, z)
	submit(sim, player, { cmdType = CT.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

-- Two armies with radars, a jammer and a structure, wandering and fighting.
local function battle(seed: number): (Sim.Sim, { number }, { number })
	local sim = Sim.new({ seed = seed, players = PLAYERS, mapId = "flat:96" })
	local rng = Prng.new(seed)
	local mine, theirs = {}, {}
	for i = 1, 10 do
		table.insert(mine, Spawn.unit(sim, "ord_lancer", 1, -300 + rng:nextNumber(-40, 40), (i - 5) * 20, math.pi / 2))
		table.insert(theirs, Spawn.unit(sim, "chs_ravager", 2, 300 + rng:nextNumber(-40, 40), (i - 5) * 20, -math.pi / 2))
	end
	table.insert(mine, Spawn.unit(sim, "ord_oracle", 1, -340, 0))
	table.insert(mine, Spawn.unit(sim, "ord_veil", 1, -320, 60))
	table.insert(theirs, Spawn.unit(sim, "chs_watcher", 2, 340, 0))
	Spawn.unit(sim, "chs_generator", 2, 200, -200)
	Spawn.unit(sim, "ord_generator", 1, -200, 200)
	camera(sim, 1, 0, 20, 50, 70) -- west half
	camera(sim, 2, 45, 20, 95, 70) -- east half
	return sim, mine, theirs
end

-- What the server says `team` may know about `id` right now.
local function knows(sim: Sim.Sim, team: number, id: number): boolean
	return Sensors.level(sim, team, id) ~= L.HIDDEN
end

return function(t: RunAll.Context)
	t.test("1,000 ticks: fog holds, radar is wobbled, messages fit, the client view matches", function()
		local sim, mine, theirs = battle(11)
		local g = (sim.map :: any).grid
		local rng = Prng.new(99)
		local views = { Client.new(g), Client.new(g) }
		local largest = 0
		for _ = 1, 1000 do
			if sim.tick % 120 == 0 then
				moveTo(sim, 1, mine, rng:nextNumber(-300, 100), rng:nextNumber(-200, 200))
				moveTo(sim, 2, theirs, rng:nextNumber(-100, 300), rng:nextNumber(-200, 200))
			end
			Sim.step(sim)
			for pid = 1, 2 do
				local team = sim.players[pid].team
				local outbox = sim.net.players[pid].outbox
				for _, msgs in outbox do
					for _, msg in msgs do
						largest = math.max(largest, buffer.len(msg))
						t.expect(buffer.len(msg) <= Packer.MAX_MESSAGE_BYTES, `message of {buffer.len(msg)} bytes`)
					end
				end
				local view = views[pid]
				Client.receive(view, outbox)
				for _, entry in view.log do
					for _, id in entry.ids do
						if entry.channel == "Leave" or (entry.channel == "Events" and sim.world.slot[id] == nil) then
							continue -- dropping a unit the client already had, or its DEATH
						end
						t.expect(knows(sim, team, id), `player {pid} got {entry.channel} for unit {id} it can't know (tick {sim.tick})`)
						if entry.channel == "Tactical" or entry.channel == "State" then
							t.equal(Sensors.level(sim, team, id), L.VISIBLE, `{entry.channel} only for seen units`)
						end
					end
				end
				-- radar contacts: wobbled cell only
				for _, msg in outbox.Strategic do
					for _, r in (Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeTickHeader)) do
						if bit32.band(r.flags, Schema.StrategicFlag.RADAR_ONLY) ~= 0 then
							local kx, kz = Sensors.knownPosition(sim, team, r.unitId)
							t.equal(r.cell, (g:encode(kx :: number, kz :: number)), "radar cell is the wobbled one")
							t.equal(r.icon, 0, "radar blips carry no type")
						end
					end
				end
			end
		end
		t.expect(sim.combat.stats.kills > 0, "the armies fought")

		-- after the run, each client's view equals the server's knowledge
		for pid = 1, 2 do
			local team = sim.players[pid].team
			local view = views[pid]
			local w = sim.world
			local expected = {}
			for _, id in w.ids do
				if knows(sim, team, id) then
					expected[id] = true
				end
			end
			for _, gid in sim.sensors.ghostIds[team] do
				expected[gid] = true
			end
			for id in expected do
				t.expect(view.units[id] ~= nil, `player {pid} is missing unit {id}`)
			end
			for id, u in view.units do
				t.expect(expected[id] == true, `player {pid} still shows unit {id}`)
				if u.tier == "tactical" then
					t.expect(math.abs(u.x - w.posX[id]) < 1 / 32 and math.abs(u.z - w.posZ[id]) < 1 / 32, `tactical unit {id} position`)
					local def = sim.defs.unitByIndex[w.defIndex[id]]
					t.equal(u.health, math.clamp(math.ceil(w.health[id] / def.health * 255), 0, 255), `tactical unit {id} health`)
				elseif w.slot[id] then
					local kx, kz = Sensors.knownPosition(sim, team, id)
					local cx, cz = g:cellAt(u.x, u.z)
					t.equal(g:index(cx, cz), (g:encode(kx :: number, kz :: number)), `strategic unit {id} cell`)
				end
			end
		end
		print(string.format("    largest message: %d bytes", largest))
	end)

	t.test("tactical tier hysteresis: enter at +2 cells, leave beyond +5", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:64" })
		local g = (sim.map :: any).grid
		local tank = Spawn.unit(sim, "ord_lancer", 1, g:cellCenter(10, 32))
		camera(sim, 1, 20, 0, 40, 63)
		local function moveCell(cx: number)
			local x, z = g:cellCenter(cx, 32)
			World.setPosition(sim.world, tank, x, z)
			Sim.step(sim)
		end
		Sim.step(sim)
		t.expect(not sim.net.players[1].tactical[tank], "10 cells outside: strategic")
		moveCell(17)
		t.expect(not sim.net.players[1].tactical[tank], "3 cells outside: still strategic")
		moveCell(18)
		t.expect(sim.net.players[1].tactical[tank], "2 cells outside: enters")
		moveCell(15)
		t.expect(sim.net.players[1].tactical[tank], "5 cells outside: stays")
		moveCell(14)
		t.expect(not sim.net.players[1].tactical[tank], "6 cells outside: leaves")
	end)

	t.test("many movers are split into messages of at most 900 bytes", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:128" })
		local ids = {}
		for i = 0, 399 do
			table.insert(ids, Spawn.unit(sim, "ord_lancer", 1, -400 + (i % 20) * 30, -300 + (i // 20) * 30))
		end
		camera(sim, 1, 0, 0, 127, 127)
		Sim.step(sim)
		for _, id in ids do
			World.setHeading(sim.world, id, 1) -- every unit "moved" this tick
		end
		Sim.step(sim)
		local msgs = sim.net.players[1].outbox.Tactical
		local records = 0
		for _, m in msgs do
			t.expect(buffer.len(m) <= 900, `{buffer.len(m)} bytes`)
			records += #(Packer.readAll(m, Schema.decodeTactical, Schema.decodeTickHeader))
		end
		t.equal(records, 400, "every mover is sent exactly once")
		t.expect(#msgs >= 4, `400 × 8 bytes needs several messages, got {#msgs}`)
	end)
end

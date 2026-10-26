--!strict
-- The client world (Core/World + NetIn) fed by the real Sim and NetOut must
-- match the reference receiver (Tests/Support/Client) and the sim's truth,
-- and Interp must draw smoothly between snapshots.

local Commands = require("../../src/client/Core/Commands")
local Interp = require("../../src/client/Core/Interp")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local Reference = require("../../src/server/Tests/Support/Client")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

local function newDuel()
	local sim = Sim.new({
		seed = 7,
		players = { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "flat:48",
		scenario = "duel_test",
	})
	local grid = (sim.map :: any).layers.grid
	local world = World.new(sim.defs)
	local ref = Reference.new(grid, sim.defs)
	assert(NetOut.hello(sim, NetIn.hello(sim.defs.hash)) == nil, "HELLO accepted")
	NetOut.join(sim, 1)
	-- camera over the whole map, and both sides drive at each other
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
	local function idsOf(team: number): { number }
		local out = {}
		for _, id in sim.world.ids do
			if sim.world.owner[id] == team then
				table.insert(out, id)
			end
		end
		return out
	end
	assert(Sim.submit(sim, 1, Commands.toPoint(grid, Schema.CmdType.MOVE, idsOf(1), 60, 0)))
	assert(Sim.submit(sim, 2, Commands.toPoint(grid, Schema.CmdType.MOVE, idsOf(2), -60, 0)))
	return sim, world, ref
end

local function step(sim: any, world: any, ref: any, tick: number)
	Sim.step(sim)
	local outbox = sim.net.players[1].outbox
	NetIn.applyOutbox(world, outbox, tick * DT)
	Reference.receive(ref, outbox)
end

return function(t: any)
	t.test("the client world matches the reference receiver and the sim, tick by tick", function()
		local sim, world, ref = newDuel()
		local entered, died, moved = 0, 0, 0
		for tick = 1, 300 do
			step(sim, world, ref, tick)
			entered += #world.entered
			died += #world.died
			table.clear(world.entered)
			table.clear(world.died)
			table.clear(world.left)
			-- same units, same tiers, same positions as the reference
			for id, r in ref.units do
				local u = world.units[id]
				t.expect(u ~= nil, `tick {tick}: unit {id} missing`)
				t.equal(u.tier, r.tier, `tick {tick}: unit {id} tier`)
				t.equal(u.team, r.team)
				t.expect(math.abs(u.x - r.x) < 1e-9 and math.abs(u.z - r.z) < 1e-9, `tick {tick}: unit {id} position`)
				if r.tier == "tactical" then
					t.equal(u.defIndex, r.defIndex)
					t.expect(math.abs((u.health :: number) - (r.health :: number) / 255) < 1e-9, `unit {id} health`)
				end
			end
			for id in world.units do
				t.expect(ref.units[id] ~= nil, `tick {tick}: extra unit {id}`)
			end
			-- tactical positions are the sim's within wire precision (a quarter
			-- stud since protocol 38: within 1/8, S-189)
			for id, u in world.units do
				if u.tier == "tactical" and sim.world.slot[id] then
					local dx, dz = u.x - sim.world.posX[id], u.z - sim.world.posZ[id]
					t.expect(math.abs(dx) <= 1 / 8 + 1e-9 and math.abs(dz) <= 1 / 8 + 1e-9, `tick {tick}: unit {id} off the sim by {dx}, {dz}`)
					if #u.snaps >= 2 then
						moved += 1
					end
				end
			end
		end
		t.equal(entered, 20, "every tank entered the tactical tier once")
		t.expect(died > 0, "the tanks fought: some died")
		t.expect(moved > 0, "the tanks drove: units have several snapshots")
		t.equal(world.dropped, 0, "nothing dropped on a lossless link")
		t.expect(world.latestTick == 300, "latest tick follows the sim")
		t.expect(world.joined and world.joins == 1, "joined once")
		t.deepEqual(world.me, { player = 1, team = 1, allyTeam = 1 }, "WELCOME says who we are")
		t.equal(world.mapId, "flat:48")
		t.expect(world.economy ~= nil and world.economy.supply.storage > 0, "Eco record decoded")
	end)

	t.test("a client that joins late rebuilds the same view; nothing counts before WELCOME", function()
		local sim, early, _ = newDuel()
		local late = World.new(sim.defs)
		for tick = 1, 120 do
			if tick == 60 then
				NetOut.join(sim, 1) -- the late client's HELLO was accepted
			end
			Sim.step(sim)
			local outbox = sim.net.players[1].outbox
			NetIn.applyOutbox(early, outbox, tick * DT)
			if tick >= 60 then
				NetIn.applyOutbox(late, outbox, tick * DT)
			else
				-- before its WELCOME the late client drops everything
				for _, channel in NetIn.ORDER do
					for _, msg in outbox[channel] or {} do
						if channel ~= "Snapshot" then
							t.expect(not NetIn.apply(late, channel, msg, tick * DT), "dropped before WELCOME")
						end
					end
				end
			end
		end
		t.equal(late.joins, 1)
		t.equal(early.joins, 2, "the re-join reset the early client too (same player)")
		for id, u in early.units do
			local v = late.units[id]
			t.expect(v ~= nil, `late client has unit {id}`)
			t.equal(v.tier, u.tier)
			t.expect(v.x == u.x and v.z == u.z, `unit {id} same position`)
		end
		for id in late.units do
			t.expect(early.units[id] ~= nil, `no extra unit {id}`)
		end
	end)

	t.test("a REJECT is kept and stops the client", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:48" })
		local reject = NetOut.hello(sim, NetIn.hello((sim.defs.hash + 1) % 4294967296))
		t.expect(reject ~= nil, "server rejects other defs")
		local world = World.new(sim.defs)
		t.expect(NetIn.apply(world, "Snapshot", reject :: buffer, 0))
		t.expect(world.rejected ~= nil and not world.joined, "rejected, not joined")
	end)

	t.test("aim and weapon state arrive for tanks that engage", function()
		local sim, world, ref = newDuel()
		local aimed, ready = 0, 0
		for tick = 1, 120 do
			step(sim, world, ref, tick)
			for _, u in world.units do
				if u.aim[1] then
					aimed += 1
				end
				if u.tier == "tactical" and NetIn.weaponReady(u, 1) then
					ready += 1
				end
			end
		end
		t.expect(aimed > 0, "turret aim decoded")
		t.expect(ready > 0, "READY weapon state decoded")
	end)

	t.test("reordered unreliable records and malformed messages are dropped", function()
		local sim, world, ref = newDuel()
		local saved: buffer? = nil
		for tick = 1, 40 do
			Sim.step(sim)
			local outbox = sim.net.players[1].outbox
			if tick == 30 then
				saved = outbox.Tactical[1] -- delivered late, after tick 31
				local copy = table.clone(outbox)
				copy.Tactical = {}
				NetIn.applyOutbox(world, copy, tick * DT)
			else
				NetIn.applyOutbox(world, outbox, tick * DT)
			end
			Reference.receive(ref, outbox)
		end
		t.expect(saved ~= nil, "units were moving at tick 30")
		local before = {}
		for id, u in world.units do
			before[id] = { u.x, u.z, u.lastTick }
		end
		t.expect(NetIn.apply(world, "Tactical", saved :: buffer, 40 * DT))
		for id, u in world.units do
			t.deepEqual({ u.x, u.z, u.lastTick }, before[id], `unit {id} kept its newer position`)
		end
		local garbage = buffer.create(5)
		buffer.writeu16(garbage, 0, 41)
		buffer.writeu8(garbage, 2, 200) -- an event kind that doesn't exist
		t.expect(not NetIn.apply(world, "Events", garbage, 41 * DT), "malformed message refused")
		t.equal(world.dropped, 1)
		t.expect(not NetIn.apply(world, "Nope", Packer.Writer.new():finish(), 0), "unknown channel refused")
	end)

	t.test("interpolation: between snapshots, extrapolate one tick while moving, hold when stopped", function()
		local u: any = {
			snaps = {
				{ tick = 10, x = 0, z = 0, alt = 0, heading = 0 },
				{ tick = 11, x = 2, z = 0, alt = 0, heading = 0.2 },
				{ tick = 12, x = 4, z = 2, alt = 0, heading = 2 * math.pi - 0.1 },
			},
			x = 4,
			z = 2,
			alt = 0,
			heading = 0,
			state = World.State.MOVING,
		}
		local x, z, _, h = Interp.sample(u, 10.5)
		t.equal(x, 1)
		t.equal(z, 0)
		t.expect(math.abs(h - 0.1) < 1e-9)
		x, z, _, h = Interp.sample(u, 11.5)
		t.equal(x, 3)
		t.equal(z, 1)
		t.expect(math.abs(h - 0.05) < 1e-9, "heading takes the short way across 0")
		x, z = Interp.sample(u, 12.5)
		t.equal(x, 5, "extrapolates while moving")
		x, z = Interp.sample(u, 20)
		t.equal(x, 6, "but at most one tick")
		u.state = 0
		x, z = Interp.sample(u, 12.5)
		t.equal(x, 4, "a stopped unit holds")
		x = Interp.sample(u, 5)
		t.equal(x, 0, "before the first snapshot: the first")
	end)

	t.test("the render clock runs two ticks behind and absorbs jitter", function()
		local world: any = { latestTick = 100, latestAt = 10 }
		local clock = Interp.newClock()
		t.equal(Interp.advance(clock, world, 10, 0), 98)
		-- half a tick later, no new packet: the clock moves on by itself
		local r = Interp.advance(clock, world, 10 + 0.5 / 15, 0.5 / 15)
		t.expect(math.abs(r - 98.5) < 1e-6)
		-- a packet arrives a bit early: the clock is pulled, not snapped
		world.latestTick, world.latestAt = 101, 10 + 0.6 / 15
		r = Interp.advance(clock, world, 10 + 0.6 / 15, 0.1 / 15)
		t.expect(r > 98.6 and r < 99.1, `pulled toward 99, got {r}`)
		-- a long stall then a burst: far off, so it jumps
		world.latestTick, world.latestAt = 120, 20
		r = Interp.advance(clock, world, 20, 1 / 60)
		t.equal(r, 118)
	end)

	t.test("camera rectangles clamp to the map and the wire range", function()
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:48" })
		local grid = (sim.map :: any).layers.grid
		local minX, minZ, maxX, maxZ = Commands.cameraRect(grid, { -1000, 1000, 0, 0 }, { 0, 0, -1000, 1000 })
		t.deepEqual({ minX, minZ, maxX, maxZ }, { 0, 0, 47, 47 })
		minX, minZ, maxX, maxZ = Commands.cameraRect(grid, { -8, 8 }, { -8, 8 })
		t.deepEqual({ minX, minZ, maxX, maxZ }, { 23, 23, 25, 25 })
		local ok = Sim.submit(sim, 1, Commands.camera(minX, minZ, maxX, maxZ))
		t.expect(ok, "the server accepts it")
	end)
end

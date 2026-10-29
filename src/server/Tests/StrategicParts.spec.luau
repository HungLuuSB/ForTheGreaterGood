--!strict
-- A strategic snapshot cut into several messages says which part each is
-- (protocol 41, S-212, client-B's H36): the unreliable channel can lose a
-- part, and a client must not take the units in it for gone.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Client = require("./Support/Client")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

-- 300 solars of player 1's, no camera: every one is a strategic record.
local function field(): (Sim.Sim, { number })
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
	local ids = {}
	for i = 0, 19 do
		for j = 0, 14 do
			table.insert(ids, Spawn.unit(sim, "ord_solar", 1, -400 + i * 24, -400 + j * 24))
		end
	end
	return sim, ids
end

-- Steps to the next tick that sends a strategic snapshot to player 1.
local function nextSnapshot(sim: Sim.Sim): { buffer }
	for _ = 1, 10 do
		Sim.step(sim)
		local msgs = sim.net.players[1].outbox.Strategic
		if #msgs > 0 then
			return msgs
		end
	end
	error("no strategic snapshot in 10 ticks")
end

return function(t: RunAll.Context)
	t.test("a snapshot of several messages numbers them: part k of n, one tick (H36)", function()
		local sim, ids = field()
		local msgs = nextSnapshot(sim)
		t.expect(#msgs >= 2, `300 records take several messages ({#msgs})`)
		local seen, tick = 0, nil
		for i, msg in msgs do
			t.expect(buffer.len(msg) <= Packer.MAX_MESSAGE_BYTES, "under the message limit")
			local records, header = Packer.readAll(msg, Schema.decodeStrategic, Schema.decodeStrategicHeader)
			local h = header :: Schema.StrategicHeader
			t.equal(h.part, i - 1, "parts in order from 0")
			t.equal(h.parts, #msgs, "each says how many")
			tick = tick or h.tick
			t.equal(h.tick, tick, "one tick")
			seen += #records
		end
		t.equal(seen, #ids, "every solar once")
	end)

	t.test("an empty snapshot is one header-only message, part 0 of 1", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		local msgs = nextSnapshot(sim)
		t.equal(#msgs, 1)
		t.equal(buffer.len(msgs[1]), Schema.STRATEGIC_HEADER_BYTES)
		local records, header = Packer.readAll(msgs[1], Schema.decodeStrategic, Schema.decodeStrategicHeader)
		t.equal(#records, 0)
		t.deepEqual({ (header :: any).part, (header :: any).parts }, { 0, 1 })
	end)

	t.test("a lost part keeps its units; a complete snapshot drops the ones missing from it", function()
		local sim, ids = field()
		local view = Client.new((sim.map :: any).grid, sim.defs)
		local function count(): number
			local n = 0
			for _, id in ids do
				if view.units[id] ~= nil then
					n += 1
				end
			end
			return n
		end
		local function only(strategic: { buffer }): { [string]: { buffer } }
			return { Events = {}, Tactical = {}, State = {}, Strategic = strategic }
		end
		Client.receive(view, only(nextSnapshot(sim)))
		t.equal(count(), #ids, "all of them")
		local GONE = 4000 -- a blip the server no longer sends
		local function blip()
			view.units[GONE] = { tier = "strategic", team = 2, icon = 0, flags = Schema.StrategicFlag.RADAR_ONLY, x = 0, z = 0 } :: any
		end
		blip()
		local msgs = nextSnapshot(sim)
		Client.receive(view, only({ msgs[1] })) -- the other parts lost
		t.equal(count(), #ids, "none dropped with parts missing")
		t.expect(view.units[GONE] ~= nil, "nor the blip, yet")
		Client.receive(view, only({ table.unpack(msgs, 2) })) -- late, but they come
		t.equal(count(), #ids, "the snapshot complete: still all")
		t.equal(view.units[GONE], nil, "and the blip missing from it is gone")
		blip()
		local last = nextSnapshot(sim)
		Client.receive(view, only({ table.unpack(last, 1, #last - 1) }))
		t.equal(count(), #ids, "the next with its last part missing: still all")
		t.expect(view.units[GONE] ~= nil, "the blip too")

		-- a part that doesn't decode is refused
		local bad = buffer.create(Schema.STRATEGIC_HEADER_BYTES)
		buffer.writeu8(bad, Schema.TICK_HEADER_BYTES, 2)
		buffer.writeu8(bad, Schema.TICK_HEADER_BYTES + 1, 2)
		t.expect(not pcall(Packer.readAll, bad, Schema.decodeStrategic, Schema.decodeStrategicHeader), "part 2 of 2 is refused")
	end)
end

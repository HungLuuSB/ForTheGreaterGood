--!strict
-- A lost part of a strategic snapshot (C-249, S-212): a big snapshot comes
-- in several unreliable parts, each saying "part k of n"; units go only
-- when a whole snapshot leaves them out, so a lost part drops none. A far
-- selected unit stays selected, and a dead or long-gone one is dropped.
-- The user: a nuke silo selected, the camera at the enemy base on Supreme
-- Strait, and the selection was gone.

local Api = require("../../src/client/Api")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local function setup()
	local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	Sim.step(sim)
	NetIn.applyOutbox(world, sim.net.players[1].outbox, 0) -- the WELCOME
	return sim, world
end

local function header(wireTick: number): (any) -> ()
	return function(w: any)
		Schema.encodeTickHeader(w, wireTick)
	end
end

-- Part `k` of `n` (1-based) of the snapshot at `wireTick`: own silos with
-- the given IDs and enemy blips with the given IDs.
local function partOf(sim: any, wireTick: number, k: number, n: number, own: { number }, blips: { number }): buffer
	local silo = sim.defs.units.ord_reckoning.index
	local records = {}
	for i, id in own do
		table.insert(records, { unitId = id, cell = 100 + i, icon = silo, team = 1, flags = 0 })
	end
	for i, id in blips do
		table.insert(records, { unitId = id, cell = 300 + i, icon = 0, team = 2, flags = Schema.StrategicFlag.RADAR_ONLY })
	end
	local msg = Packer.chunk(records, Schema.encodeStrategic, nil, function(w: any)
		Schema.encodeStrategicHeader(w, wireTick)
	end)[1]
	if msg == nil then -- an empty snapshot: the header only (as NetOut sends it)
		local w = Packer.Writer.new(Schema.STRATEGIC_HEADER_BYTES)
		Schema.encodeStrategicHeader(w, wireTick)
		msg = w:finish()
	end
	buffer.writeu8(msg, Schema.TICK_HEADER_BYTES, k - 1)
	buffer.writeu8(msg, Schema.TICK_HEADER_BYTES + 1, n)
	return msg
end

-- A whole snapshot in one part.
local function part(sim: any, wireTick: number, own: { number }, blips: { number }): buffer
	return partOf(sim, wireTick, 1, 1, own, blips)
end

return function(t: any)
	t.test("units of a lost snapshot part stay till a whole snapshot leaves them out (S-212)", function()
		local sim, world = setup()
		-- snapshot 10 in two parts
		NetIn.apply(world, "Strategic", partOf(sim, 10, 1, 2, { 50 }, { 60, 61 }), 0)
		NetIn.apply(world, "Strategic", partOf(sim, 10, 2, 2, {}, { 70, 71 }), 0)
		for _, id in { 50, 60, 61, 70, 71 } do
			t.expect(world.units[id] ~= nil, `{id} after snapshot 10`)
		end
		-- snapshot 15: its first part is lost
		NetIn.apply(world, "Strategic", partOf(sim, 15, 2, 2, {}, { 70, 71 }), 0)
		for _, id in { 50, 60, 61, 70, 71 } do
			t.expect(world.units[id] ~= nil, `{id} still there with a part of snapshot 15 lost`)
		end
		-- snapshot 20, whole, in two parts: 60 and 71 aren't in it
		NetIn.apply(world, "Strategic", partOf(sim, 20, 1, 2, { 50 }, { 61 }), 0)
		t.expect(world.units[60] ~= nil and world.units[71] ~= nil, "nothing goes before the last part")
		NetIn.apply(world, "Strategic", partOf(sim, 20, 2, 2, {}, { 70 }), 0)
		for _, id in { 50, 61, 70 } do
			t.expect(world.units[id] ~= nil, `{id} listed`)
		end
		t.equal(world.units[60], nil, "60 left out of a whole snapshot: gone")
		t.equal(world.units[71], nil, "71 too")
		-- the same part twice counts once; a late part of an older snapshot is ignored
		NetIn.apply(world, "Strategic", partOf(sim, 25, 1, 2, {}, { 70 }), 0)
		NetIn.apply(world, "Strategic", partOf(sim, 25, 1, 2, {}, { 70 }), 0)
		t.expect(world.units[50] ~= nil, "a repeated part isn't the whole snapshot")
		NetIn.apply(world, "Strategic", partOf(sim, 20, 1, 2, {}, { 60 }), 0)
		t.equal(world.units[60], nil, "an older snapshot's part changes nothing")
		-- an empty snapshot: part 0 of 1, the header only
		NetIn.apply(world, "Strategic", part(sim, 30, {}, {}), 0)
		t.equal(next(world.units), nil, "an empty snapshot clears the far units")
	end)

	t.test("a far selected unit missing for a moment stays selected; a dead one doesn't", function()
		local sim, world = setup()
		local api = Api.new(world, function() end)
		NetIn.apply(world, "Strategic", part(sim, 10, { 50, 51 }, {}), 0)
		api.actions.select({ 50, 51 })
		api.actions.setGroup(3)
		Api.frame(api, 1)
		t.equal(#api.state.selection, 2)
		-- a whole snapshot leaves 50 out (the server didn't list it for a moment)
		NetIn.apply(world, "Strategic", part(sim, 15, { 51 }, {}), 0)
		t.equal(world.units[50], nil, "50 is out of the world")
		Api.frame(api, 2)
		Api.frame(api, 6)
		t.equal(table.concat(api.state.selection, ","), "50,51", "still selected while missing")
		t.equal(#api.state.groups[3], 2, "and still in its group")
		-- it comes back: nothing was lost
		NetIn.apply(world, "Strategic", part(sim, 25, { 50, 51 }, {}), 0)
		Api.frame(api, 7)
		t.equal(table.concat(api.state.selection, ","), "50,51")
		-- 51 dies: dropped at once
		local ev = Packer.chunk({ { kind = Schema.EventKind.DEATH, unitId = 51, severity = 0, wreckId = 0 } }, Schema.encodeEvent, nil, header(26))
		NetIn.apply(world, "Events", ev[1], 7.1)
		Api.frame(api, 7.2)
		t.equal(table.concat(api.state.selection, ","), "50", "a death drops it")
		-- 50 missing for good: dropped after Selection.MISSING_SECONDS
		NetIn.apply(world, "Strategic", part(sim, 30, {}, { 99 }), 8)
		Api.frame(api, 8)
		t.equal(#api.state.selection, 1, "missing, still selected")
		Api.frame(api, 19)
		t.equal(#api.state.selection, 0, "gone for good after 10 s")
		t.equal(#api.state.groups[3], 0, "and out of its group")
	end)
end

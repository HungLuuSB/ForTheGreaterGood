--!strict
-- A lost part of a strategic snapshot (C-249): a big snapshot comes in
-- several unreliable parts; units of a lost part stay one snapshot, a far
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

-- One part of the snapshot at `wireTick`: own silos with the given IDs and
-- enemy blips with the given IDs.
local function part(sim: any, wireTick: number, own: { number }, blips: { number }): buffer
	local silo = sim.defs.units.ord_reckoning.index
	local records = {}
	for i, id in own do
		table.insert(records, { unitId = id, cell = 100 + i, icon = silo, team = 1, flags = 0 })
	end
	for i, id in blips do
		table.insert(records, { unitId = id, cell = 300 + i, icon = 0, team = 2, flags = Schema.StrategicFlag.RADAR_ONLY })
	end
	return Packer.chunk(records, Schema.encodeStrategic, nil, header(wireTick))[1]
end

return function(t: any)
	t.test("units of a lost snapshot part stay one snapshot, then go", function()
		local sim, world = setup()
		-- snapshot 10 in two parts
		NetIn.apply(world, "Strategic", part(sim, 10, { 50 }, { 60, 61 }), 0)
		NetIn.apply(world, "Strategic", part(sim, 10, {}, { 70, 71 }), 0)
		for _, id in { 50, 60, 61, 70, 71 } do
			t.expect(world.units[id] ~= nil, `{id} after snapshot 10`)
		end
		-- snapshot 15: its second part is lost
		NetIn.apply(world, "Strategic", part(sim, 15, {}, { 70, 71 }), 0)
		for _, id in { 50, 60, 61, 70, 71 } do
			t.expect(world.units[id] ~= nil, `{id} still there with a part of snapshot 15 lost`)
		end
		-- snapshot 20 lists only 70: the others missed two snapshots
		NetIn.apply(world, "Strategic", part(sim, 20, {}, { 70 }), 0)
		t.expect(world.units[70] ~= nil, "70 listed")
		t.expect(world.units[71] ~= nil, "71 was in 15: one more snapshot")
		for _, id in { 50, 60, 61 } do
			t.equal(world.units[id], nil, `{id} missing from 15 and 20: gone`)
		end
		NetIn.apply(world, "Strategic", part(sim, 25, {}, { 70 }), 0)
		t.equal(world.units[71], nil, "71 missing from 20 and 25: gone")
	end)

	t.test("a far selected unit missing for a moment stays selected; a dead one doesn't", function()
		local sim, world = setup()
		local api = Api.new(world, function() end)
		NetIn.apply(world, "Strategic", part(sim, 10, { 50, 51 }, {}), 0)
		api.actions.select({ 50, 51 })
		api.actions.setGroup(3)
		Api.frame(api, 1)
		t.equal(#api.state.selection, 2)
		-- two snapshots in a row lose 50's part: it leaves the world for a while
		NetIn.apply(world, "Strategic", part(sim, 15, { 51 }, {}), 0)
		NetIn.apply(world, "Strategic", part(sim, 20, { 51 }, {}), 0)
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
		NetIn.apply(world, "Strategic", part(sim, 35, {}, { 99 }), 8)
		Api.frame(api, 8)
		t.equal(#api.state.selection, 1, "missing, still selected")
		Api.frame(api, 19)
		t.equal(#api.state.selection, 0, "gone for good after 10 s")
		t.equal(#api.state.groups[3], 0, "and out of its group")
	end)
end

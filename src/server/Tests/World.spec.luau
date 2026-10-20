--!strict
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local function info(team: number?): World.SpawnInfo
	return { defIndex = 1, team = team or 1, owner = 1, x = 0, z = 0, health = 100 }
end

return function(t: RunAll.Context)
	t.test("spawn hands out fresh IDs from 1 and keeps ids dense", function()
		local w = World.new()
		t.equal(World.spawn(w, 0, info()), 1)
		t.equal(World.spawn(w, 0, info()), 2)
		t.equal(World.spawn(w, 0, info()), 3)
		t.deepEqual(w.ids, { 1, 2, 3 })
		World.despawn(w, 0, 1)
		t.deepEqual(w.ids, { 3, 2 }, "swap-remove")
		t.equal(w.slot[3], 1)
		t.equal(w.slot[2], 2)
		t.expect(not World.isAlive(w, 1) and World.isAlive(w, 2), "alive flags")
		t.equal(w.health[1], nil, "fields cleared on despawn")
		t.equal(World.spawn(w, 0, info()), 4, "fresh IDs come before reused ones")
		t.throws(function()
			World.despawn(w, 0, 1)
		end, "not alive")
	end)

	t.test("freed IDs are reused only after the delay, oldest first", function()
		local w = World.new()
		for _ = 1, World.MAX_ID do
			World.spawn(w, 0, info())
		end
		t.equal(World.count(w), 65535)
		t.throws(function()
			World.spawn(w, 0, info())
		end, "no unit ID available")

		World.despawn(w, 10, 500)
		World.despawn(w, 12, 7)
		local delay = World.REUSE_DELAY_TICKS
		t.throws(function()
			World.spawn(w, 10 + delay - 1, info())
		end, "no unit ID available")
		t.equal(World.spawn(w, 10 + delay, info()), 500, "first freed, first reused")
		t.throws(function()
			World.spawn(w, 10 + delay, info())
		end, "no unit ID available")
		t.equal(World.spawn(w, 12 + delay, info()), 7)
	end)

	t.test("setters mark dirty bits; clearDirty resets them", function()
		local w = World.new()
		local id = World.spawn(w, 0, info())
		t.expect(w.dirty[id] ~= 0, "a spawn is dirty")
		World.clearDirty(w, id)
		World.setPosition(w, id, 5, 6)
		t.equal(w.dirty[id], World.Dirty.POSITION)
		World.setHealth(w, id, 50)
		t.equal(w.dirty[id], World.Dirty.POSITION + World.Dirty.HEALTH)
		World.clearDirty(w, id)
		World.setHeading(w, id, 1)
		World.setState(w, id, World.State.MOVING)
		World.setFireState(w, id, World.FireState.HOLD_FIRE)
		World.setAltitude(w, id, 30)
		t.equal(w.dirty[id], World.Dirty.HEADING + World.Dirty.STATE + World.Dirty.ALTITUDE)
		t.equal(w.posX[id], 5)
		t.equal(w.fireState[id], World.FireState.HOLD_FIRE)
	end)

	t.test("hash covers state and ignores ids order", function()
		local function build(order: { number }): World.World
			local w = World.new()
			for _ = 1, 3 do
				World.spawn(w, 0, info())
			end
			for _, id in order do
				World.setPosition(w, id, id * 10, -id)
			end
			return w
		end
		local a = build({ 1, 2, 3 })
		local b = build({ 3, 1, 2 })
		t.equal(World.hash(a), World.hash(b), "same state, same hash")

		-- Same live units, different dense order (swap-remove history).
		local c, d = World.new(), World.new()
		for _ = 1, 3 do
			World.spawn(c, 0, info())
			World.spawn(d, 0, info())
		end
		World.despawn(c, 0, 1)
		World.despawn(d, 0, 1)
		World.setPosition(c, 2, 1, 1)
		World.setPosition(d, 2, 1, 1)
		t.equal(World.hash(c), World.hash(d))

		local before = World.hash(a)
		World.setHealth(a, 2, 99)
		t.notEqual(World.hash(a), before, "health change")
		local e = build({ 1, 2, 3 })
		World.setPosition(e, 1, 10 + 1e-9, -1)
		t.notEqual(World.hash(e), World.hash(build({ 1, 2, 3 })), "tiny position change")
	end)
end

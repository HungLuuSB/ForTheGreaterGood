--!strict
-- Selection, control groups and orders (client task 5) against the real
-- Sim: what the API sends is what the server queues, and the client's
-- waypoint lines follow it.

local Api = require("../../src/client/Api")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Orders = require("../../src/client/Core/Orders")
local Selection = require("../../src/client/Core/Selection")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

-- Top-down test projection: 2 pixels per stud, map corner at (0, 0).
local function project(x: number, _y: number, z: number): (number, number, boolean)
	return (x + 192) * 2, (z + 192) * 2, true
end

local function setup(scenario: string, players: { any }?)
	local sim = Sim.new({
		seed = 3,
		players = players or { { id = 1, team = 1 }, { id = 2, team = 2 } },
		mapId = "flat:48",
		scenario = scenario,
	})
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local sent: { buffer } = {}
	local api = Api.new(world, function(payload: buffer)
		table.insert(sent, payload)
		local ok, why = Sim.submit(sim, 1, payload)
		assert(ok, why)
	end)
	api.send(Commands.camera(0, 0, 47, 47))
	local tick = 0
	local function run(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			table.clear(world.entered)
			table.clear(world.left)
			table.clear(world.died)
			Api.frame(api, tick * DT)
		end
	end
	run(2)
	return sim, world, api, sent, run
end

local function decode(payload: buffer): Schema.Command
	return Packer.readAll(payload, Schema.decodeCommand)[1]
end

return function(t: any)
	t.test("box select picks own units only; click picks the nearest unit", function()
		local _sim, world, api = setup("duel_test")
		-- the whole map: only the 10 own Lancers
		local ids = Selection.inBox(world, project, 0, 0, 768, 768)
		t.equal(#ids, 10)
		for _, id in ids do
			t.equal(world.units[id].team, 1)
		end
		api.actions.select(ids)
		t.equal(#api.state.selection, 10)
		-- a box around the east half holds only enemies: nothing
		t.equal(#Selection.inBox(world, project, 384, 0, 768, 768), 0)
		-- click on a Ravager picks it (any team)
		local enemy
		for id, u in world.units do
			if u.team == 2 then
				enemy = id
				break
			end
		end
		local u = world.units[enemy]
		local sx, sy = project(u.x, 0, u.z)
		t.equal(Selection.pick(world, project, sx + 3, sy - 3), enemy)
		t.equal(Selection.pick(world, project, sx + 60, sy), nil, "nothing within reach")
		-- but selecting it is refused: not own
		api.actions.select({ enemy }, "add")
		t.equal(#api.state.selection, 10)
	end)

	t.test("add, toggle, control groups and pruning dead units", function()
		local _sim, world, api, _, run = setup("duel_test")
		local own = World.ownIds(world)
		api.actions.select({ own[1], own[2] })
		api.actions.select({ own[2], own[3] }, "toggle")
		t.deepEqual(api.state.selection, { own[1], own[3] })
		api.actions.select({ own[4] }, "add")
		t.deepEqual(api.state.selection, { own[1], own[3], own[4] })
		t.expect(api.actions.setGroup(2))
		api.actions.select({ own[5] })
		t.expect(api.actions.recallGroup(2))
		t.deepEqual(api.state.selection, { own[1], own[3], own[4] })
		t.expect(not api.actions.setGroup(10), "groups are 1..9")
		-- the duel kills units: selection and groups drop them
		api.actions.select(own)
		api.actions.setGroup(1)
		local fired = 0
		api.changed.selection:Connect(function()
			fired += 1
		end)
		run(400)
		for _, id in api.state.selection do
			t.expect(world.units[id] ~= nil, `selected unit {id} is alive`)
		end
		t.expect(#api.state.selection < 10, "some Lancers died")
		t.equal(#api.state.groups[1], #api.state.selection, "group pruned too")
		t.expect(fired > 0, "selection signal fired on pruning")
	end)

	t.test("smart right-click: enemy → attack, own → guard, ground → move", function()
		local sim, world, api, sent, run = setup("duel_test")
		local own = World.ownIds(world)
		local enemy
		for id, u in world.units do
			if u.team == 2 then
				enemy = id
			end
		end
		api.actions.select({ own[1], own[2] })
		t.expect(api.actions.smartOrder(0, 0, enemy, false))
		local cmd = decode(sent[#sent])
		t.equal(cmd.cmdType, Schema.CmdType.ATTACK)
		t.equal(cmd.targetId, enemy)
		t.deepEqual(cmd.unitIds, { own[1], own[2] })
		run(1) -- the sim applies commands on its next tick
		local q = sim.orders.queue[own[1]]
		t.expect(q and q[1].kind == "attack" and q[1].target == enemy, "the server queued the attack")

		api.actions.smartOrder(0, 0, own[3], false)
		t.equal(decode(sent[#sent]).cmdType, Schema.CmdType.GUARD)

		api.actions.smartOrder(-20, 30, nil, false)
		cmd = decode(sent[#sent])
		t.equal(cmd.cmdType, Schema.CmdType.MOVE)
		local x, z = world.grid:decode(cmd.cell :: number, cmd.offX :: number, cmd.offZ :: number)
		t.expect(math.abs(x + 20) < 0.1 and math.abs(z - 30) < 0.1, "move point")
		run(1)
		t.equal(sim.orders.queue[own[1]][1].kind, "move", "a plain order replaces the queue")
		api.actions.select({})
		local ok, why = api.actions.smartOrder(0, 0, nil, false)
		t.expect(not ok and why == "nothing selected")
	end)

	t.test("shift queues orders on the server and in the waypoint lines", function()
		local sim, world, api, _, run = setup("march_test", { { id = 1, team = 1 } })
		local own = World.ownIds(world)
		local pick = { own[1], own[2], own[3] }
		api.actions.select(pick)
		api.actions.smartOrder(-100, -60, nil, false)
		api.actions.smartOrder(-60, -60, nil, true)
		api.actions.smartOrder(-60, 0, nil, true)
		run(1)
		t.equal(#sim.orders.queue[pick[1]], 3, "server queue has three moves")
		t.equal(#api.waypoints.byUnit[pick[1]], 3, "client draws three points")
		run(15 * 30)
		for _, id in pick do
			local u = world.units[id]
			t.expect(math.abs(u.x + 60) < 16 and math.abs(u.z) < 16, `unit {id} ended at the last point ({u.x}, {u.z})`)
			t.expect(api.waypoints.byUnit[id] == nil, "all points reached")
		end
		-- a 10-unit group stands in a formation around the point: its lines
		-- still clear (formation-sized reach, or idle after arriving)
		local ten = table.move(own, 11, 20, 1, {})
		api.actions.select(ten)
		api.actions.smartOrder(40, -80, nil, false)
		run(15 * 25)
		for _, id in ten do
			t.expect(api.waypoints.byUnit[id] == nil, `unit {id} has no stale line`)
		end
		api.actions.smartOrder(100, 0, nil, false)
		t.expect(api.actions.stop())
		run(1)
		t.expect(api.waypoints.byUnit[pick[1]] == nil, "stop clears the lines")
		t.expect(sim.orders.queue[pick[1]] == nil or #sim.orders.queue[pick[1]] == 0, "stop clears the server queue")
	end)

	t.test("line move spreads units along the line", function()
		local _sim, world, api, sent, run = setup("march_test", { { id = 1, team = 1 } })
		local own = World.ownIds(world)
		local group = table.move(own, 1, 10, 1, {})
		api.actions.select(group)
		t.expect(api.actions.lineMove(0, -60, 0, 60, false))
		local cmd = decode(sent[#sent])
		t.equal(cmd.flags, Schema.CmdFlag.LINE)
		local slots = Orders.lineSlots(world, group, 0, -60, 0, 60)
		local zs = {}
		for _, id in group do
			table.insert(zs, slots[id][2])
		end
		table.sort(zs)
		t.equal(zs[1], -60)
		t.equal(zs[#zs], 60)
		run(15 * 20)
		local minZ, maxZ = math.huge, -math.huge
		for _, id in group do
			local u = world.units[id]
			t.expect(math.abs(u.x) < 12, `unit {id} reached the line (x {u.x})`)
			minZ, maxZ = math.min(minZ, u.z), math.max(maxZ, u.z)
			-- the drawn goal is the server's slot for this unit (C-11)
			local goal = slots[id]
			t.expect((u.x - goal[1]) ^ 2 + (u.z - goal[2]) ^ 2 < 4 ^ 2, `unit {id} at its drawn slot ({u.x}, {u.z}) vs ({goal[1]}, {goal[2]})`)
		end
		t.expect(maxZ - minZ > 90, `spread along the line ({minZ} .. {maxZ})`)
	end)

	t.test("big selections are split into commands of at most 200 units", function()
		local _sim, world = setup("empty", { { id = 1, team = 1 } })
		local ids = {}
		for i = 1, 450 do
			ids[i] = i
		end
		local payloads = Orders.encode(world, { cmdType = Schema.CmdType.STOP, queue = false }, ids)
		t.equal(#payloads, 3)
		local total = 0
		for _, p in payloads do
			local n = #decode(p).unitIds
			t.expect(n <= Schema.MAX_UNITS_PER_COMMAND)
			total += n
		end
		t.equal(total, 450)
	end)
end

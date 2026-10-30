--!strict
-- Air transports on the client (S-219, protocol 43; C-272): a right click
-- or a Load order picks a unit up (or boards a transport), the cargo shows
-- on the transport (CARGO) while the carried unit is out of the world, and
-- Unload sets it down again (its ENTER). Plus the construction turret's
-- spray on a live enemy (RECLAIM_UNIT, protocol 42, S-218): a reclaim.

local Api = require("../../src/client/Api")
local BuildTargets = require("../../src/client/Core/BuildTargets")
local CommandSet = require("../../src/client/Core/CommandSet")
local Commands = require("../../src/client/Core/Commands")
local NetIn = require("../../src/client/Core/NetIn")
local Orders = require("../../src/client/Core/Orders")
local Transports = require("../../src/client/Core/Transports")
local World = require("../../src/client/Core/World")
local Schema = require("@shared/Net/Schema")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")

local DT = 1 / 15
local CT = Schema.CmdType

local function setup()
	local sim = Sim.new({ seed = 4, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:64", scenario = "empty" })
	local world = World.new(sim.defs)
	local api = Api.new(world, function(p: buffer)
		assert(Sim.submit(sim, 1, p))
	end)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	local tick = 0
	local function step(n: number)
		for _ = 1, n do
			tick += 1
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Api.frame(api, tick * DT)
		end
	end
	return sim, world, api, step
end

return function(t: any)
	t.test("transports offer Load and Unload; right clicks pick up and board what fits", function()
		local sim, world, _, step = setup()
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0, 0)
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 40, 0, 0)
		local big: string? = nil -- a T2 ground unit: too heavy for the Courier
		for id, def in sim.defs.units do
			if def.domain == "ground" and def.tier == 2 and def.transport == nil and string.sub(id, 1, 4) == "ord_" and def.shield == nil then
				big = id
				break
			end
		end
		assert(big, "a T2 ground unit")
		local heavy = Spawn.unit(sim, big, 1, -40, 0, 0)
		step(3)
		local set = CommandSet.forDef(sim.defs.units.ord_courier, sim.defs)
		t.expect(set.load and set.unload, "the Courier's card has Load and Unload")
		t.expect(not CommandSet.forDef(sim.defs.units.ord_lancer, sim.defs).load, "a tank's doesn't")
		local tw, lw, hw = world.units[courier], world.units[lancer], world.units[heavy]
		t.expect(Transports.fits(world, tw, lw), "a Lancer fits the Courier")
		t.expect(not Transports.fits(world, tw, hw), `{big} doesn't`)
		-- the transport selected, right click the tank: the transport picks it up
		local parts = Orders.smartFor(world, lw.x, lw.z, lancer, false, { courier })
		t.equal(#parts, 1)
		t.equal(parts[1].intent.cmdType, CT.LOAD)
		t.equal(parts[1].intent.targetId, lancer)
		-- the tanks selected, right click the transport: the one that fits boards, the other guards
		parts = Orders.smartFor(world, tw.x, tw.z, courier, false, { lancer, heavy })
		t.equal(#parts, 2)
		t.equal(parts[1].intent.cmdType, CT.LOAD)
		t.equal(parts[1].ids[1], lancer)
		t.equal(parts[2].intent.cmdType, CT.GUARD)
		t.equal(parts[2].ids[1], heavy)
	end)

	t.test("Load: the cargo shows on the transport, the carried unit leaves the world; Unload brings it back", function()
		local sim, world, api, step = setup()
		local courier = Spawn.unit(sim, "ord_courier", 1, 0, 0, 0)
		local lancer = Spawn.unit(sim, "ord_lancer", 1, 40, 0, 0)
		step(3)
		api.actions.select({ courier })
		t.expect(api.actions.setCommandMode("load"))
		t.expect(api.actions.commandAt(40, 0, lancer, false, false), "Load on the Lancer")
		local loaded = false
		for _ = 1, 15 * 20 do
			step(1)
			local tw = world.units[courier]
			if tw and tw.cargo and #tw.cargo == 1 then
				loaded = true
				break
			end
		end
		t.expect(loaded, "the CARGO lists the Lancer")
		step(2)
		local tw = world.units[courier]
		t.equal(tw.cargo and tw.cargo[1], lancer)
		t.equal(world.units[lancer], nil, "the carried Lancer is out of the client's world")
		local line = Transports.line(world, tw)
		t.equal(line, `Cargo 1 / 2: {sim.defs.units.ord_lancer.name}`)
		t.expect(api.actions.setCommandMode("unload"))
		t.expect(api.actions.commandAt(-60, 40, nil, false, false), "Unload at a point")
		local back = false
		for _ = 1, 15 * 25 do
			step(1)
			if world.units[lancer] and world.units[lancer].tier == "tactical" then
				back = true
				break
			end
		end
		t.expect(back, "the Lancer came back (its ENTER)")
		step(3)
		local lu = world.units[lancer]
		t.expect(lu and (lu.x + 60) ^ 2 + (lu.z - 40) ^ 2 < 40 * 40, "set down near the point")
		t.equal(#(world.units[courier].cargo or { 0 }), 0, "the Courier is empty")
		t.equal(Transports.line(world, world.units[courier]), "Cargo 0 / 2: empty")
	end)

	t.test("a construction turret's spray on a live enemy (RECLAIM_UNIT) is a reclaim", function()
		local world = World.new(require("@shared/Defs/Defs").load())
		world.me.team = 1
		local function unit(id: number, team: number): World.Unit
			local u = { id = id, defIndex = 1, team = team, tier = "tactical", x = id * 10, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} } :: any
			world.units[id] = u
			return u
		end
		local turret = unit(1, 1)
		unit(2, 2)
		turret.workKind, turret.workTarget = Schema.WorkKind.RECLAIM_UNIT, 2
		local out = BuildTargets.list(world, {}, {})
		t.equal(#out, 1)
		t.equal(out[1].kind, "reclaim")
		t.equal(out[1].target, 2)
		t.expect(not out[1].wreck, "a unit, not a wreck")
	end)
end

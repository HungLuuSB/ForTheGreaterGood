--!strict
-- Carriers as home bases (guide 12.3, S-36): recovering aircraft, carrying
-- them along, launching them, and empty aircraft going home.
local Packer = require("@shared/Net/Packer")
local Schema = require("@shared/Net/Schema")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local CT = Schema.CmdType
local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

local function submit(sim: Sim.Sim, cmd: Schema.Command)
	local wr = Packer.Writer.new()
	Schema.encodeCommand(wr, cmd)
	assert(Sim.submit(sim, 1, wr:finish()))
end

local function move(sim: Sim.Sim, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	submit(sim, { cmdType = CT.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
end

-- "sea:128": land west of x = -256, deep sea elsewhere.
local function scene(): (Sim.Sim, number, number, number)
	local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "sea:128" })
	Spawn.unit(sim, "ord_sovereign", 1, -450, -300) -- an account and power for rearming
	Spawn.unit(sim, "ord_generator", 1, -470, -260)
	local carrier = Spawn.unit(sim, "ord_sanctuary", 1, 150, 0, 0)
	local airfield = Spawn.unit(sim, "ord_airfield", 1, -350, 100, 0)
	local jet = Spawn.unit(sim, "ord_falcon", 1, -100, 0, math.pi / 2)
	return sim, carrier, airfield, jet
end

local function stepUntil(sim: Sim.Sim, limit: number, cond: () -> boolean): boolean
	for _ = 1, limit do
		Sim.step(sim)
		if cond() then
			return true
		end
	end
	return false
end

return function(t: RunAll.Context)
	t.test("a guard order recovers an aircraft to a carrier: it lands, stays and rides along", function()
		local sim, carrier, _, jet = scene()
		local w, a = sim.world, sim.air
		submit(sim, { cmdType = CT.GUARD, flags = 0, unitIds = { jet }, targetId = carrier })
		t.expect(stepUntil(sim, 15 * 40, function()
			return a.phase[jet] == "docked"
		end), "it landed and is held on the carrier")
		t.equal(a.home[jet], carrier, "the carrier is its home")
		t.expect(bit32.band(w.state[jet], World.State.LANDED) ~= 0, "landed")
		move(sim, { carrier }, 300, 200)
		for _ = 1, 15 * 10 do
			Sim.step(sim)
			if w.posX[jet] ~= w.posX[carrier] or w.posZ[jet] ~= w.posZ[carrier] then
				break
			end
		end
		t.expect(w.posX[carrier] > 160, "the carrier sailed")
		t.expect(w.posX[jet] == w.posX[carrier] and w.posZ[jet] == w.posZ[carrier], "the docked jet moved with it")
		t.equal(a.phase[jet], "docked", "and is still docked")
	end)

	t.test("an order launches a docked aircraft", function()
		local sim, carrier, _, jet = scene()
		local w, a = sim.world, sim.air
		submit(sim, { cmdType = CT.GUARD, flags = 0, unitIds = { jet }, targetId = carrier })
		stepUntil(sim, 15 * 40, function()
			return a.phase[jet] == "docked"
		end)
		move(sim, { jet }, -200, -200)
		Sim.step(sim)
		t.equal(a.phase[jet], "fly", "it took off")
		t.equal(bit32.band(w.state[jet], World.State.LANDED), 0, "no longer landed")
		t.expect(stepUntil(sim, 15 * 30, function()
			return (w.posX[jet] + 200) ^ 2 + (w.posZ[jet] + 200) ^ 2 < 250 ^ 2
		end), "and flew where it was sent")
	end)

	t.test("an empty aircraft goes home to its carrier, not to a nearer airfield", function()
		local sim, carrier, airfield, jet = scene()
		local w, a = sim.world, sim.air
		submit(sim, { cmdType = CT.GUARD, flags = 0, unitIds = { jet }, targetId = carrier })
		stepUntil(sim, 15 * 40, function()
			return a.phase[jet] == "docked"
		end)
		move(sim, { jet }, -300, 60) -- next to the airfield
		stepUntil(sim, 15 * 20, function()
			return (w.posX[jet] + 300) ^ 2 + (w.posZ[jet] - 60) ^ 2 < 200 ^ 2
		end)
		local Air = require("../Sim/Air")
		a.ammo[jet] = 0
		Air.onEmpty(sim, jet)
		t.equal(a.phase[jet], "return", "empty: going to rearm")
		t.equal(a.pad[jet], carrier, `to its home carrier (the airfield {airfield} is nearer)`)
		t.expect(stepUntil(sim, 15 * 60, function()
			return a.phase[jet] == "rearm" or a.phase[jet] == "fly"
		end), "it landed there")
		t.expect(w.posX[jet] == w.posX[carrier], "on the carrier")
	end)
end

--!strict
-- Pinpointers (S-59, client request 34): each raises the team's radar
-- precision, full at 6 (Witness 5, Augur 7 since S-62): contacts wobble
-- less, radar missiles keep their lock.
local Packer = require("@shared/Net/Packer")
local Pinpoint = require("@shared/Combat/Pinpoint")
local Schema = require("@shared/Net/Schema")
local Sensors = require("../Sim/Sensors")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local World = require("../Sim/World")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }
local L = Sensors.Level

local function moveTo(sim: Sim.Sim, player: number, ids: { number }, x: number, z: number)
	local cell, ox, oz = (sim.map :: any).grid:encode(x, z)
	local w = Packer.Writer.new()
	Schema.encodeCommand(w, { cmdType = Schema.CmdType.MOVE, flags = 0, unitIds = ids, cell = cell, offX = ox, offZ = oz })
	assert(Sim.submit(sim, player, w:finish()))
end

local function pinpointers(sim: Sim.Sim, player: number, defId: string, n: number, x: number)
	for i = 1, n do
		Spawn.unit(sim, defId, player, x, -300 + i * 40, 0)
	end
end

return function(t: RunAll.Context)
	t.test("precision grows linearly, full at 6", function()
		t.equal(Pinpoint.precision(0), 0)
		t.equal(Pinpoint.precision(3), 0.5)
		t.equal(Pinpoint.precision(6), 1)
		t.equal(Pinpoint.precision(9), 1, "more than 6 add nothing")
		t.expect(math.abs(Pinpoint.errorScale(1) - 0.1) < 1e-9, "a tenth of the error at full precision")
	end)

	t.test("Order's Witness is full at 5, Chaos's Augur at 7; a mixed team adds up (S-62)", function()
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
		local units = sim.defs.units
		t.equal(Pinpoint.weight(units.ord_lancer), 0, "not a Pinpointer")
		local function precisionWith(witnesses: number, augurs: number): number
			local s = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:128" })
			pinpointers(s, 1, "ord_witness", witnesses, -450)
			pinpointers(s, 1, "chs_augur", augurs, -380)
			Sim.step(s)
			Sim.step(s)
			return Sensors.precision(s.sensors, 1)
		end
		t.expect(math.abs(precisionWith(5, 0) - 1) < 1e-9, "5 Witnesses: full")
		t.expect(math.abs(precisionWith(4, 0) - 0.8) < 1e-9, "4 Witnesses: 0.8")
		t.expect(math.abs(precisionWith(0, 7) - 1) < 1e-9, "7 Augurs: full")
		t.expect(math.abs(precisionWith(0, 6) - 6 / 7) < 1e-9, "6 Augurs: not yet")
		t.expect(math.abs(precisionWith(2, 3) - (2 / 5 + 3 / 7)) < 1e-9, "2 Witnesses and 3 Augurs on one team")
	end)

	t.test("radar contacts wobble less with each Pinpointer, barely at all with 6", function()
		local function worstOffset(count: number): number
			local sim = Sim.new({ seed = 2, players = PLAYERS, mapId = "flat:128" })
			Spawn.unit(sim, "ord_beacon", 1, -400, 0, 0) -- long-range radar
			pinpointers(sim, 1, "ord_witness", count, -450)
			local tank = Spawn.unit(sim, "chs_ravager", 2, 200, 0, 0) -- 600 studs off: radar only
			World.setMoveState(sim.world, tank, World.MoveState.HOLD_POSITION)
			local worst = 0
			for _ = 1, 600 do
				Sim.step(sim)
				local x, z, level = Sensors.knownPosition(sim, 1, tank, true)
				if x and z and level == L.RADAR then
					worst = math.max(worst, math.sqrt((x - sim.world.posX[tank]) ^ 2 + (z - sim.world.posZ[tank]) ^ 2))
				end
			end
			local weight = Pinpoint.weight(sim.defs.units.ord_witness) -- 6 / 5 (S-62)
			t.equal(Sensors.precision(sim.sensors, 1), Pinpoint.precision(count * weight), `{count} Pinpointers counted`)
			return worst
		end
		local none, three, six = worstOffset(0), worstOffset(3), worstOffset(6)
		print(string.format("    worst radar offset: %.1f studs (0 Pinpointers), %.1f (3), %.1f (6)", none, three, six))
		t.expect(none > 8, `without Pinpointers a blip wanders ({none} studs)`)
		t.expect(three < none * 0.6, `3 Pinpointers: about half ({three})`)
		t.expect(six <= none * 0.12, `6 Pinpointers: a tenth ({six})`)
	end)

	t.test("radar missiles at a target seen only on radar lose their lock without Pinpointers, hold it with 6", function()
		-- a Wyvern (radar SAM, 945 studs) and a Falcon circling 700 studs off,
		-- far outside sight: the Wyvern's own radar finds it
		local function salvo(count: number): (number, number)
			local sim = Sim.new({ seed = 5, players = PLAYERS, mapId = "flat:256" })
			local site = Spawn.unit(sim, "chs_wyvern", 2, 400, 0, 0)
			sim.world.wStock[World.slotKey(site, 1)] = 255
			pinpointers(sim, 2, "chs_augur", count, 600)
			local jet = Spawn.unit(sim, "ord_falcon", 1, -300, 0, math.pi / 2)
			World.setHealth(sim.world, jet, 1e9)
			sim.ew.chaff[jet] = 0
			moveTo(sim, 1, { jet }, -300, 0)
			local lost, launched = 0, 0
			local mine: { [number]: boolean } = {}
			for _ = 1, 1500 do
				Sim.step(sim)
				for _, e in sim.combat.events do
					if e.kind == "SPAWN_PROJ" and e.unit == site then
						launched += 1
						mine[e.other] = true
						t.equal(Sensors.level(sim, 2, jet), L.RADAR, "the target is only on radar")
					elseif e.kind == "LOST_LOCK" and mine[e.other] then
						lost += 1
					end
				end
			end
			return lost, launched
		end
		local lost0, launched0 = salvo(0)
		local lost6, launched6 = salvo(6)
		print(string.format("    lost lock: %d of %d (0 Pinpointers), %d of %d (6)", lost0, launched0, lost6, launched6))
		t.expect(launched0 >= 10 and launched6 >= 10, "both fired")
		t.expect(lost0 >= launched0 * 0.25, `without Pinpointers many lose their lock ({lost0} of {launched0})`)
		t.expect(lost6 < lost0 / 2, `with 6 far fewer ({lost6} of {launched6})`)
	end)
end

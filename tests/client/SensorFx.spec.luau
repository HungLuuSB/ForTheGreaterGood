--!strict
-- Sensor effects (C-211): which units ping (own finished sonar emitters on
-- camera) and which wear a jammer dome (finished jammers on camera, any
-- team: the sim's jammers are always on), ping timing staggered per unit,
-- fading rings, and the dome's breath.

local SensorFx = require("../../src/client/Core/SensorFx")
local World = require("../../src/client/Core/World")
local Sim = require("../../src/server/Sim/Sim")

local function defWith(sim: any, key: string): any
	for _, d in sim.defs.units do
		if d.sensors and (d.sensors[key] or 0) > 0 then
			return d
		end
	end
	error(`no def with {key}`)
end

return function(t: any)
	t.test("who pings and who shimmers", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		world.me = { player = 1, team = 1, allyTeam = 1 }
		local sonar, jam = defWith(sim, "sonar"), defWith(sim, "jam")
		local function unit(id: number, def: any, team: number, state: number, build: number, tier: string?)
			world.units[id] = { id = id, tier = tier or "tactical", team = team, defIndex = def.index, x = id * 10, z = 0, alt = 0, rx = id * 10, ry = 0, rz = 0, state = state, build = build } :: any
		end
		unit(1, sonar, 1, 0, 1)
		unit(2, sonar, 2, 0, 1) -- an enemy's sonar: no ping
		unit(3, sonar, 1, 0, 0.5) -- unfinished
		unit(4, jam, 1, 0, 1)
		unit(5, jam, 2, 0, 1) -- an enemy's: shimmers too
		unit(6, jam, 1, 0, 0.3) -- unfinished
		unit(7, sonar, 1, 0, 1, "strategic") -- off camera
		local kinds = {}
		for _, e in SensorFx.emitters(world) do
			table.insert(kinds, `{e.id}{e.kind}`)
		end
		t.equal(table.concat(kinds, ","), "1sonar,4jam,5jam")
		t.equal(SensorFx.emitters(world)[1].r, sonar.sensors.sonar, "out to the sonar radius")
	end)

	t.test("pings: staggered, periodic, fading", function()
		local count = 0
		for i = 0, 299 do
			if SensorFx.ping(1, i / 100) then
				count += 1
			end
		end
		t.expect(math.abs(count / 300 - SensorFx.PING_TIME / SensorFx.PING_PERIOD) < 0.02, "a ring for PING_TIME of every PING_PERIOD")
		t.equal(SensorFx.ping(1, 0.7), SensorFx.ping(1, 0.7 + SensorFx.PING_PERIOD), "periodic")
		t.expect(math.abs(SensorFx.offset(1) - SensorFx.offset(2)) > 0.5, "neighbouring ids are staggered")
		t.equal(SensorFx.pingTransparency(0), 1, "clear as it starts")
		t.expect(SensorFx.pingTransparency(0.25) < 0.3, "clearest a quarter of the way")
		t.equal(SensorFx.pingTransparency(1), 1, "gone at the radius")
		local b = SensorFx.breath(4, 1)
		t.expect(b >= 0 and b <= 1, "a breath share")
		t.expect(math.abs(SensorFx.breath(4, 1) - SensorFx.breath(4, 1 + SensorFx.BREATH)) < 1e-9, "one breath per BREATH seconds")
	end)
end

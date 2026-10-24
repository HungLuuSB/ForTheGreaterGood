--!strict
-- The radar layer (C-207): coverage as fill with lighter rings (each
-- radar's own, and one outer edge where radars overlap), when it shows
-- (placing a radar, a radar selected, the sensor view) and which circles,
-- and its composite under the fog image (Core/FogBlanket).

local FogBlanket = require("../../src/client/Core/FogBlanket")
local RadarFill = require("../../src/client/Core/RadarFill")
local World = require("../../src/client/Core/World")
local Sim = require("../../src/server/Sim/Sim")

return function(t: any)
	t.test("fill, own rings, one outline where radars overlap", function()
		local layer = RadarFill.new(140, 100) -- 8-stud cells from (0, 0); cell 50's centre is at 404
		local changed = RadarFill.build(layer, { { x = 404, z = 404, r = 300 } }, 0, 0, 8)
		t.expect(changed and layer.version == 1, "built")
		t.expect(not RadarFill.build(layer, { { x = 405, z = 406, r = 300 } }, 0, 0, 8), "a move under a cell: unchanged")
		t.equal(RadarFill.at(layer, 50, 50), RadarFill.FILL, "the centre is fill")
		local function strength(px: number): number
			return RadarFill.strength(RadarFill.at(layer, px, 50))
		end
		t.expect(strength(50 + 37) > 0.6, `the edge (296 studs of 300) is a strong ring ({strength(50 + 37)})`)
		t.expect(strength(50 + 36) < strength(50 + 37), "fading inwards from the edge")
		t.equal(strength(50 + 20), 1, "an inner ring's line at RING_STEP (160 studs)")
		t.expect(strength(50 + 19) == 0 and strength(50 + 21) == 0, "a cell away: faded out")
		t.equal(RadarFill.at(layer, 50 + 10, 50), RadarFill.FILL, "between rings: fill")
		t.equal(RadarFill.at(layer, 50 + 40, 50), 0, "outside")
		-- a second radar whose centre lies inside the first: the first's edge inside it isn't drawn
		RadarFill.build(layer, { { x = 404, z = 404, r = 300 }, { x = 644, z = 404, r = 300 } }, 0, 0, 8)
		t.equal(RadarFill.at(layer, 50 + 37, 50), RadarFill.FILL, "the first edge, deep in the second: fill")
		t.equal(RadarFill.at(layer, 80 + 38, 50), 0, "past both: outside")
		t.expect(RadarFill.strength(RadarFill.at(layer, 80 + 37, 50)) > 0.6, "the union's outer edge stays a ring")
	end)

	t.test("when it shows, and which circles", function()
		local sim = Sim.new({ seed = 5, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "start:64", scenario = "empty" })
		local world = World.new(sim.defs)
		world.me = { player = 1, team = 1, allyTeam = 1 }
		local tower = sim.defs.units.ord_watchtower
		local lancer = sim.defs.units.ord_lancer
		world.units[1] = { id = 1, tier = "tactical", team = 1, defIndex = tower.index, x = 10, z = 20, alt = 0, state = 0, build = 1 } :: any
		world.units[2] = { id = 2, tier = "tactical", team = 1, defIndex = tower.index, x = 50, z = 20, alt = 0, state = 0, build = 0.5 } :: any
		world.units[3] = { id = 3, tier = "tactical", team = 2, defIndex = tower.index, x = 90, z = 20, alt = 0, state = 0, build = 1 } :: any
		world.units[4] = { id = 4, tier = "tactical", team = 1, defIndex = lancer.index, x = 0, z = 0, alt = 0, state = 0, build = 1 } :: any
		t.equal(RadarFill.circles(world, nil, {}, false), nil, "nothing selected: hidden")
		t.equal(RadarFill.circles(world, nil, { 4 }, false), nil, "a Lancer selected: hidden")
		local c = RadarFill.circles(world, nil, { 1 }, false)
		t.expect(c ~= nil and #c == 1, "a radar selected: shown, the finished own radar only")
		t.equal((c :: any)[1].r, tower.sensors.radar)
		c = RadarFill.circles(world, { defIndex = tower.index, x = 300, z = 300 }, {}, false)
		t.expect(c ~= nil and #c == 2 and (c :: any)[2].x == 300, "placing a radar: shown, its range added")
		t.equal(RadarFill.circles(world, { defIndex = lancer.index, x = 0, z = 0 }, {}, false), nil, "placing something else: hidden")
		t.expect(RadarFill.circles(world, nil, {}, true) ~= nil, "the sensor view: shown")
	end)

	t.test("composited under the fog; the radar alone with the fog off", function()
		local b = FogBlanket.new(4, 4, 2) -- all never seen
		local cells = buffer.create(16)
		buffer.writeu8(cells, 0, RadarFill.FILL)
		buffer.writeu8(cells, 1, RadarFill.RING)
		local _, before = FogBlanket.pixel(b, 0, 0)
		t.expect(FogBlanket.setOverlay(b, cells, 1, true), "changed")
		t.expect(not FogBlanket.setOverlay(b, cells, 1, true), "the same: unchanged")
		local _, fill = FogBlanket.pixel(b, 0, 0)
		local _, ring = FogBlanket.pixel(b, 1, 0)
		local _, none = FogBlanket.pixel(b, 2, 0)
		t.expect(fill > before and ring > fill, `radar adds to the fog's alpha, rings more ({before} {fill} {ring})`)
		t.expect(math.abs(none - before) < 0.005, "no radar there: the fog alone (to a 255th)")
		t.expect(buffer.readu8(b.rgba, 1) > buffer.readu8(b.rgba, 8 + 1), "greener where the radar is")
		FogBlanket.setOverlay(b, cells, 1, false)
		local _, alone = FogBlanket.pixel(b, 0, 0)
		local _, empty = FogBlanket.pixel(b, 2, 0)
		t.expect(math.abs(alone - FogBlanket.RADAR.fill) < 0.01, `fog off: the radar's own alpha ({alone})`)
		t.equal(empty, 0, "fog off, no radar: clear")
		FogBlanket.setOverlay(b, nil, 0, true)
		local _, back = FogBlanket.pixel(b, 0, 0)
		t.expect(math.abs(back - before) < 0.005, "hidden again: the fog as before")
	end)
end

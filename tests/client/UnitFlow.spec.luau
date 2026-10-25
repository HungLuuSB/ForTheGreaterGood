--!strict
-- A unit's economy flow for the unit panel (C-125): extractors by the
-- deposits under them, generators and wind, radar upkeep, a factory's or a
-- builder's drain at its buildpower, slowed by a stall; frames yield
-- nothing.

local UnitFlow = require("../../src/client/Core/UnitFlow")
local World = require("../../src/client/Core/World")
local Defs = require("@shared/Defs/Defs")
local Grid = require("@shared/Grid/Grid")
local Layers = require("@shared/Grid/Layers")

local defs = Defs.load()

local function world(): any
	local w = World.new(defs)
	local g = Grid.new(16, 16)
	local layers = Layers.new(g)
	w.grid, w.layers = g, layers
	w.me = { player = 1, team = 1, allyTeam = 1 }
	return w
end

local function unit(w: any, defId: string, x: number, z: number, extra: { [string]: any }?): any
	local def = defs.units[defId]
	local u = { team = 1, defIndex = def.index, x = x, z = z, build = 1, state = 0, tier = "tactical" }
	for k, v in extra or {} do
		u[k] = v
	end
	table.insert(w.units, u)
	return u, def
end

return function(t: any)
	t.test("an extractor yields rate × the deposits under it; a frame yields nothing", function()
		local w = world()
		local g = w.grid
		local cx, cz = g:cellAt(4, 4)
		Layers.setSupply(w.layers, g:index(cx, cz), 4)
		local u, def = unit(w, "ord_extractor", 4, 4)
		local s, p = UnitFlow.of(w, u, def, {})
		t.equal(s, def.extractor.rate * 4)
		t.equal(p, 0)
		u.build = 0.5
		t.equal((UnitFlow.of(w, u, def, {})), 0, "a frame: nothing yet")
	end)

	t.test("a factory drains its item's cost at its buildpower, slower in a stall", function()
		local w = world()
		local plant, pdef = unit(w, "ord_vehplant", 40, 40)
		local lancer = defs.units.ord_lancer
		local s, p = UnitFlow.of(w, plant, pdef, { queue = { lancer.index }, ratio = 1 })
		local rate = pdef.buildPower / lancer.cost.buildTime
		t.expect(math.abs(s + lancer.cost.supply * rate) < 1e-9, "supply drain")
		t.expect(math.abs(p + lancer.cost.power * rate) < 1e-9, "power drain")
		local s2 = UnitFlow.of(w, plant, pdef, { queue = { lancer.index }, ratio = 0.5 })
		t.expect(math.abs(s2 - s / 2) < 1e-9, "half in a 50% stall")
		t.equal((UnitFlow.of(w, plant, pdef, { queue = {} })), 0, "idle: nothing")
	end)

	t.test("made and used apart, green and red (F9)", function()
		local w = world()
		local cmd, cdef = unit(w, "ord_sovereign", 0, 0)
		unit(w, "ord_generator", 10, 0, { build = 0.3 })
		local f = UnitFlow.parts(w, cmd, cdef, {})
		t.expect(f.supplyIn > 0 and f.supplyOut > 0, "the Commander makes supply and spends it on the frame")
		local s = UnitFlow.of(w, cmd, cdef, {})
		t.expect(math.abs(s - (f.supplyIn - f.supplyOut)) < 1e-9, "net = made - used")
		local line = UnitFlow.rich("S", 1, 3.25)
		t.expect(string.find(line, UnitFlow.GAIN .. '">+1.0', 1, true) ~= nil, "made in green")
		t.expect(string.find(line, UnitFlow.COST .. '">−3.2', 1, true) ~= nil or string.find(line, UnitFlow.COST .. '">−3.3', 1, true) ~= nil, "used in red")
		t.expect(string.find(UnitFlow.rich("S", 0, 0), UnitFlow.NONE .. '">0', 1, true) ~= nil, "neither: a dim 0")
	end)

	t.test("a builder next to an own frame drains for it; wind follows the team's wind", function()
		local w = world()
		local mason, mdef = unit(w, "ord_mason", 0, 0)
		local _, gdef = unit(w, "ord_generator", 10, 0, { build = 0.3 })
		local s = UnitFlow.of(w, mason, mdef, {})
		t.expect(s < 0, "drains while a frame is in reach")
		t.expect(math.abs(s + gdef.cost.supply * mdef.buildPower / gdef.cost.buildTime) < 1e-9, "at the mason's buildpower")
		local windmill, wdef = unit(w, "ord_windmill", 60, 60)
		local _, p = UnitFlow.of(w, windmill, wdef, { wind = 0.5 })
		t.equal(p, wdef.wind.max * 0.5, "half the wind, half the power")
	end)

	t.test("the text: +5, −10, 0", function()
		t.equal(UnitFlow.text(5), "+5.0")
		t.equal(UnitFlow.text(-10), "−10")
		t.equal(UnitFlow.text(12.4), "+12")
		t.equal(UnitFlow.text(0.01), "0")
	end)
end

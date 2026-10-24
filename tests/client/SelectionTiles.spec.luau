--!strict
-- The unit panel's type tiles (C-157, BAR's selection panel): a click keeps
-- only that type, Shift-click drops it, Ctrl-click takes every own unit of
-- that type on screen.

local Selection = require("../../src/client/Core/Selection")
local World = require("../../src/client/Core/World")
local Defs = require("@shared/Defs/Defs")

local defs = Defs.load()

local function scene()
	local world = World.new(defs)
	world.me.team = 1
	local lancer, herald = defs.units.ord_lancer.index, defs.units.ord_herald.index
	local function add(id: number, defIndex: number, team: number, x: number)
		world.units[id] = { id = id, tier = "tactical", team = team, defIndex = defIndex, x = x, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} } :: any
	end
	add(1, lancer, 1, 0)
	add(2, lancer, 1, 10)
	add(3, herald, 1, 20)
	add(4, lancer, 1, 900) -- off screen
	add(5, lancer, 2, 30) -- an enemy's
	return world, lancer, herald
end

return function(t: any)
	t.test("click keeps the type, Shift-click drops it", function()
		local world, lancer, herald = scene()
		local sel = { 1, 2, 3 }
		t.equal(table.concat(Selection.tileClick(world, sel, lancer, "keep"), ","), "1,2")
		t.equal(table.concat(Selection.tileClick(world, sel, lancer, "remove"), ","), "3")
		t.equal(table.concat(Selection.tileClick(world, sel, herald, "remove"), ","), "1,2")
	end)

	t.test("Ctrl-click takes every own unit of the type on screen", function()
		local world, lancer = scene()
		-- a camera that sees x within 0..100 (studs map to pixels)
		local function project(x: number, _y: number, _z: number): (number, number, boolean)
			return x, 50, true
		end
		local onScreen = Selection.sameTypeOnScreen(world, project, lancer, 100, 100)
		t.equal(table.concat(Selection.tileClick(world, { 3 }, lancer, "screen", onScreen), ","), "1,2", "own Lancers in view; not the far one, not the enemy's")
	end)

	t.test("a box with a builder in it keeps only the builders (C-193)", function()
		local world = scene()
		local mason = defs.units.ord_mason.index
		world.units[6] = { id = 6, tier = "tactical", team = 1, defIndex = mason, x = 40, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} } :: any
		t.deepEqual(Selection.filterBox(world, { 1, 2, 3, 6 }), { 6 }, "the Mason only")
		t.deepEqual(Selection.filterBox(world, { 1, 2, 3 }), { 1, 2, 3 }, "no builder: everything")
		t.deepEqual(Selection.filterBox(world, {}), {})
	end)
end

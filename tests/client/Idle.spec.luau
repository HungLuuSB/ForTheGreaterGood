--!strict
-- Idle builders and factories (C-158): a factory with an empty queue is
-- idle; a builder that has stood still a few seconds with no orders and no
-- frame going up near it is idle; the cycle walks them in order and wraps.

local Idle = require("../../src/client/Core/Idle")
local World = require("../../src/client/Core/World")
local Defs = require("@shared/Defs/Defs")

local defs = Defs.load()

local function scene()
	local world = World.new(defs)
	world.me.team = 1
	local function add(id: number, defId: string, fields: any?)
		local u: any = { id = id, tier = "tactical", team = 1, defIndex = defs.units[defId].index, x = id * 100, z = 0, alt = 0, heading = 0, snaps = {}, lastTick = 0, state = 0, weapon = 0, aim = {} }
		for k, v in fields or {} do
			u[k] = v
		end
		world.units[id] = u
	end
	add(1, "ord_vehplant", { queue = {} }) -- idle factory
	add(2, "ord_vehplant", { queue = { defs.units.ord_lancer.index } }) -- busy
	add(3, "ord_vehplant") -- never had a queue: the server sends none
	add(4, "ord_mason") -- idle builder
	add(5, "ord_mason") -- has orders
	add(6, "ord_mason") -- building a frame next to it
	add(7, "ord_solar", { x = 600, build = 0.4 })
	add(8, "ord_mason", { team = 2 }) -- not ours
	return world
end

return function(t: any)
	t.test("idle factories and builders, and only those", function()
		local world = scene()
		local st = Idle.new()
		local orders = function(id: number): boolean
			return id == 5
		end
		Idle.update(st, world, orders, 0)
		t.equal(table.concat(st.factories, ","), "1,3")
		t.equal(#st.builders, 0, "a builder isn't idle the moment it stops")
		Idle.update(st, world, orders, Idle.STILL_SECONDS + 0.1)
		t.equal(table.concat(st.builders, ","), "4", "the one with no orders and no frame near")
	end)

	t.test("the cycle walks idle builders in order and wraps", function()
		local world = scene()
		world.units[6].x = 9000 -- no frame near it any more
		local st = Idle.new()
		local none = function(_id: number): boolean
			return false
		end
		Idle.update(st, world, none, 0)
		Idle.update(st, world, none, 10)
		t.equal(table.concat(st.builders, ","), "4,5,6")
		t.equal(Idle.next(st, "builder"), 4)
		t.equal(Idle.next(st, "builder"), 5)
		t.equal(Idle.next(st, "builder"), 6)
		t.equal(Idle.next(st, "builder"), 4, "wraps")
		t.equal(Idle.next(st, "factory"), 1)
		t.equal(Idle.next(st, "factory"), 3)
	end)
end

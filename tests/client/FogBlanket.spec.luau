--!strict
-- The fog blanket's image (C-100): three states from the team's sight,
-- explored remembered, fades over FADE seconds, only changed pixels
-- reported, and the real sim's sight driving it.

local Commands = require("../../src/client/Core/Commands")
local FogBlanket = require("../../src/client/Core/FogBlanket")
local NetIn = require("../../src/client/Core/NetIn")
local Vision = require("../../src/client/Core/Vision")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

-- a hand-made vision map: width × depth sensor cells
local function vision(w: number, d: number): Vision.Vision
	return { width = w, depth = d, originX = 0, originZ = 0, seen = buffer.create(w * d * 2), version = 0, changed = {}, sightVersion = -1 }
end
local function see(v: Vision.Vision, s: number, on: boolean)
	buffer.writeu16(v.seen, s * 2, if on then 1 else 0)
	table.insert(v.changed, s)
	v.version += 1
end

return function(t: any)
	t.test("starts all never seen; seen cells clear; left cells explored, a lighter grey wash; never stays the thickest", function()
		local v = vision(4, 4)
		local b = FogBlanket.new(8, 8, 2)
		local first = FogBlanket.step(b, 0)
		t.expect(first and first.w == 8 and first.h == 8, "the whole image is written once")
		local s0, a0 = FogBlanket.pixel(b, 0, 0)
		t.equal(s0, "never")
		t.expect(math.abs(a0 - FogBlanket.LOOK.never.alpha) < 0.01, "darkest")
		-- sensor cells (1..2, 1..2) seen = pixels (2..5, 2..5); pixels 3..4 are
		-- between seen cells only, so fully clear (the blend softens the rim)
		for _, s in { 5, 6, 9, 10 } do
			see(v, s, true)
		end
		FogBlanket.apply(b, v)
		table.clear(v.changed)
		FogBlanket.step(b, 1)
		t.equal((FogBlanket.pixel(b, 2, 2)), "visible")
		t.equal(select(2, FogBlanket.pixel(b, 3, 3)), 0)
		local _, rim = FogBlanket.pixel(b, 2, 3)
		t.expect(rim > 0 and rim < FogBlanket.LOOK.never.alpha, `the rim is soft ({rim})`)
		t.equal((FogBlanket.pixel(b, 6, 2)), "never")
		for _, s in { 5, 6, 9, 10 } do
			see(v, s, false)
		end
		FogBlanket.apply(b, v)
		FogBlanket.step(b, 1)
		local se, ae = FogBlanket.pixel(b, 3, 4)
		t.equal(se, "explored")
		t.expect(math.abs(ae - FogBlanket.LOOK.explored.alpha) < 0.01, "explored darkness")
		t.expect(FogBlanket.LOOK.explored.alpha < FogBlanket.LOOK.never.alpha, "explored is lighter than never seen")
	end)

	t.test("fades over FADE seconds; only the changed rectangle is reported", function()
		local v = vision(8, 8)
		local b = FogBlanket.new(16, 16, 2)
		FogBlanket.step(b, 0)
		-- sensor (3, 2) = pixels x 6..7, y 4..5; its blend reaches pixels 5..8, 3..6
		see(v, 2 * 8 + 3, true)
		FogBlanket.apply(b, v)
		local r = assert(FogBlanket.step(b, FogBlanket.FADE / 4))
		t.equal(r.x, 5)
		t.equal(r.y, 3)
		t.equal(r.w, 4)
		t.equal(r.h, 4)
		local _, before = FogBlanket.pixel(b, 6, 4)
		FogBlanket.step(b, FogBlanket.FADE)
		local _, after = FogBlanket.pixel(b, 6, 4)
		t.expect(before > after, `it fades over time ({before} → {after})`)
		t.expect(after < FogBlanket.LOOK.never.alpha * 0.6, "mostly clear: one seen cell among never-seen ones")
		t.equal(FogBlanket.step(b, 0.1), nil) -- nothing left moving
		local region = FogBlanket.region(b, { x = 5, y = 3, w = 4, h = 4 })
		t.equal(buffer.len(region), 64)
	end)

	t.test("driven by the server's sight: a scout clears its surroundings and leaves explored ground behind", function()
		local sim = Sim.new({ seed = 2, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local scout = Spawn.unit(sim, "ord_herald", 1, -350, -350, math.pi / 2)
		local v = Vision.new(g)
		local b = FogBlanket.new(g.cellsX, g.cellsZ, 2)
		local function run(ticks: number)
			for tick = 1, ticks do
				Sim.step(sim)
				NetIn.applyOutbox(world, sim.net.players[1].outbox, tick / 15)
				if Vision.update(v, world) or b.visionVersion < 0 then
					FogBlanket.apply(b, v)
				end
				FogBlanket.step(b, 1 / 15)
				table.clear(world.died)
			end
		end
		local function pixelAt(x: number, z: number): string
			return (FogBlanket.pixel(b, math.floor((x - g.originX) / 8), math.floor((z - g.originZ) / 8)))
		end
		run(15)
		t.equal(pixelAt(-350, -350), "visible")
		t.equal(pixelAt(450, 450), "never")
		assert(Sim.submit(sim, 1, Commands.toPoint(g, Schema.CmdType.MOVE, { scout }, 350, -350)))
		run(15 * 22)
		t.equal(pixelAt(350, -350), "visible")
		t.equal(pixelAt(-350, -350), "explored")
		t.equal(pixelAt(450, 450), "never")
	end)
end

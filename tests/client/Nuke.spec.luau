--!strict
-- Nukes on the client (protocol 16, S-48, C-57): the launch warning, the
-- landing the client predicts from the missile alone, interceptors that
-- chase it in step with the server's, and its end: a detonation (a "nuke"
-- burst at the spot) or an interception (a burst in the air).

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15
local CT = Schema.CmdType
local TARGET_X, TARGET_Z = 500, 0

local function scene(defended: boolean)
	local sim = Sim.new({ seed = 3, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:256", scenario = "empty" })
	local silo = Spawn.unit(sim, "ord_reckoning", 1, -800, 0, 0)
	if defended then
		Spawn.unit(sim, "chs_wyvern", 2, TARGET_X - 100, -150, 0)
		Spawn.unit(sim, "chs_wyvern", 2, TARGET_X - 100, 150, 0)
	end
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	local g = sim.map.layers.grid
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
	assert(Sim.submit(sim, 1, Commands.toPoint(g, CT.ATTACK_GROUND, { silo }, TARGET_X, TARGET_Z)))
	return sim, world
end

return function(t: any)
	t.test("an undefended nuke: warning, predicted landing, detonation at the spot", function()
		local sim, world = scene(false)
		local fx = Effects.new()
		local predicted: { number }? = nil
		local nukeBurst
		local maxWarnings = 0
		for tick = 1, 15 * 20 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			maxWarnings = math.max(maxWarnings, #fx.warnings)
			local w = fx.warnings[1]
			if predicted == nil and w and w.proj then
				local x, z = Effects.landing(world, w.proj :: Effects.Proj)
				if x then
					predicted = { x, z :: number }
				end
			end
			for _, b in fx.bursts do
				if b.kind == "nuke" then
					nukeBurst = b
				end
			end
		end
		t.expect(predicted ~= nil, "the client got a launch warning with its missile and predicted the landing")
		t.expect(nukeBurst ~= nil, "it detonated")
		t.equal(maxWarnings, 1) -- LAUNCH_WARNING and the missile's SPAWN_PROJ raise one warning
		if predicted and nukeBurst then
			local off = math.sqrt((predicted[1] - nukeBurst.x) ^ 2 + (predicted[2] - nukeBurst.z) ^ 2)
			print(string.format("    predicted landing %.1f studs from the detonation; detonation %.1f studs from the target", off, math.sqrt((nukeBurst.x - TARGET_X) ^ 2 + (nukeBurst.z - TARGET_Z) ^ 2)))
			t.expect(off < 2, `the predicted landing is the detonation's spot ({off} studs off)`)
			t.equal(nukeBurst.radius, sim.defs.weapons.ord_nuke.aoe)
		end
	end)

	t.test("Wyverns intercept: interceptors chase the nuke in step with the server's", function()
		local sim, world = scene(true)
		local fx = Effects.new()
		local interceptors, chasing, errs = 0, 0, {}
		local seen: { [any]: boolean } = {}
		local intercepted, detonated = false, false
		for tick = 1, 15 * 20 do
			Sim.step(sim)
			for _, e in sim.combat.events do
				if e.kind == "INTERCEPTED" then
					intercepted = true
				end
			end
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			local c = sim.combat
			for id, p in fx.projectiles do
				if p.chase then
					if not seen[p] then
						seen[p] = true
						interceptors += 1
					end
					if not p.chase.gone then
						chasing += 1
					end
					if c.projSlot[id] then
						table.insert(errs, math.sqrt((p.x - c.px[id]) ^ 2 + (p.y - c.py[id]) ^ 2 + (p.z - c.pz[id]) ^ 2))
					end
				end
			end
			for _, b in fx.bursts do
				if b.kind == "nuke" then
					detonated = true
				end
			end
		end
		table.sort(errs)
		local median = errs[math.max(1, #errs // 2)] or 0
		local p90 = errs[math.max(1, math.floor(#errs * 0.9))] or 0
		print(string.format("    %d interceptors, %d frames chasing; client vs server median %.2f, p90 %.2f studs; intercepted %s, detonated %s", interceptors, chasing, median, p90, tostring(intercepted), tostring(detonated)))
		t.expect(interceptors >= 1 and chasing > 0, "interceptors went up after the nuke")
		t.expect(median < 0.5 and p90 < 3, `in step with the server's (median {median}, p90 {p90})`)
		t.expect(intercepted ~= detonated, "the nuke either was intercepted or detonated, as the server says")
	end)
end

--!strict
-- Vertical-launch radar SAMs (S-42, C-53): the missile leaves the launcher
-- straight up, pitches over onto its target (Guidance.vertical) and then
-- flies proportional navigation; the client steps its own copy with the
-- same function and its `turned` state, so it stays with the server's.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local ServerWorld = require("../../src/server/Sim/World")
local Layers = require("@shared/Grid/Layers")

local DT = 1 / 15

return function(t: any)
	t.test("Wyvern missiles go up, pitch over and stay with the server's", function()
		t.equal(Sim.new({ seed = 1, players = { { id = 1, team = 1 } }, mapId = "flat:16", scenario = "empty" }).defs.weapons.chs_radar_sam.launch, "vertical")
		local sim = Sim.new({ seed = 25, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:160", scenario = "empty" })
		for i = 0, 2 do
			local f = Spawn.unit(sim, "ord_falcon", 1, -300, -120 + i * 120, math.pi / 2)
			ServerWorld.setHealth(sim.world, f, sim.world.health[f] * 5)
		end
		Spawn.unit(sim, "chs_wyvern", 2, 200, -100, 0)
		Spawn.unit(sim, "chs_wyvern", 2, 200, 100, 0)
		-- a tank next to the sites: projectiles reach a client only in its side's sight (D99)
		Spawn.unit(sim, "ord_lancer", 1, 150, 0, 0)
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		local g = sim.map.layers.grid
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
		local fx = Effects.new()
		local launched, upward, turnedSeen = 0, 0, 0
		local climbHeight = sim.defs.weapons.chs_radar_sam.climbHeight :: number
		local leveledAt: { [any]: number } = {} -- height above ground where it first moved sideways
		local seen: { [any]: boolean } = {}
		local errs = {}
		for tick = 1, 15 * 30 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			table.clear(world.died)
			local c = sim.combat
			for id, p in fx.projectiles do
				if p.weapon.launch ~= "vertical" then
					continue
				end
				if not seen[p] then
					seen[p] = true
					launched += 1
					local speed = math.sqrt(p.vx * p.vx + p.vy * p.vy + p.vz * p.vz)
					if p.vy > 0.8 * speed then
						upward += 1
					end
				end
				if leveledAt[p] == nil and (p.vx ~= 0 or p.vz ~= 0) then
					leveledAt[p] = p.y - Layers.heightAt(world.layers :: any, p.x, p.z)
				end
				if p.turned and seen[p] ~= "turned" then
					seen[p] = "turned"
					turnedSeen += 1
				end
				if c.projSlot[id] and p.target ~= 0 then
					table.insert(errs, math.sqrt((p.x - c.px[id]) ^ 2 + (p.y - c.py[id]) ^ 2 + (p.z - c.pz[id]) ^ 2))
				end
			end
		end
		table.sort(errs)
		local median = errs[math.max(1, #errs // 2)] or 0
		local p90 = errs[math.max(1, math.floor(#errs * 0.9))] or 0
		print(string.format("    %d vertical launches (%d going up when first drawn, %d pitched over); client vs server: median %.2f, 90th percentile %.2f studs", launched, upward, turnedSeen, median, p90))
		t.expect(launched >= 3, "the Wyverns fired")
		t.expect(upward == launched, "every missile leaves going up")
		t.expect(turnedSeen >= launched - 1, "they pitch over onto their targets")
		t.expect(median < 0.5 and p90 < 3, `the client's missiles stay with the server's (median {median}, p90 {p90})`)
		-- the straight climb (S-44): no sideways turn below climbHeight (less
		-- one tick's climb, as the turn starts on the tick it gets there)
		local low = math.huge
		for _, h in leveledAt do
			low = math.min(low, h)
		end
		local step = sim.defs.weapons.chs_radar_sam.projectileSpeed * DT
		print(string.format("    climbHeight %d: the lowest pitch-over started %.1f studs up", climbHeight, low))
		t.expect(low >= climbHeight - step - 1e-6 and low < math.huge, `every missile climbs to its climbHeight before turning ({low})`)
	end)
end

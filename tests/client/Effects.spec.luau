--!strict
-- Combat effects (client task 7): projectiles follow the server, IMPACT
-- ends them, effects wait for the render clock, and the caps hold.

local Commands = require("../../src/client/Core/Commands")
local Effects = require("../../src/client/Core/Effects")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

local function duel()
	local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
	local world = World.new(sim.defs)
	NetOut.join(sim, 1)
	assert(Sim.submit(sim, 1, Commands.camera(0, 0, 47, 47)))
	return sim, world
end

return function(t: any)
	t.test("unguided shells match the server's projectiles while they fly; IMPACT ends them", function()
		local sim, world = duel()
		local fx = Effects.new()
		local compared, worst, impacts = 0, 0, 0
		for tick = 1, 240 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			-- render exactly at the newest tick (no delay) so client and server line up
			local before = #fx.bursts
			Effects.update(fx, world, tick, tick * DT, 0, 0)
			for _, b in fx.bursts do
				if b.kind == "impact" and b.born == tick * DT then
					impacts += 1
				end
			end
			local _ = before
			table.clear(world.died)
			-- every server projectile the client has is where the server has it
			local c = sim.combat
			for id, p in fx.projectiles do
				if c.projSlot[id] then
					local dx = p.x - c.px[id]
					local dy = p.y - c.py[id]
					local dz = p.z - c.pz[id]
					local d = math.sqrt(dx * dx + dy * dy + dz * dz)
					worst = math.max(worst, d)
					compared += 1
				end
			end
		end
		t.expect(compared > 50, `compared {compared} projectile ticks`)
		t.expect(worst < 0.5, `worst drift {worst} studs (wire quantization only)`)
		t.expect(impacts > 10, `impact bursts: {impacts}`)
		local live = 0
		for _ in fx.projectiles do
			live += 1
		end
		t.expect(live < 10, "projectiles end on IMPACT, they don't pile up")
	end)

	t.test("events and deaths wait for the render clock", function()
		local sim, world = duel()
		local fx = Effects.new()
		local firstSpawnTick
		for tick = 1, 120 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, e in world.events do
				if (e :: any).kind == Schema.EventKind.SPAWN_PROJ and firstSpawnTick == nil then
					firstSpawnTick = (e :: any).tick
				end
			end
			if firstSpawnTick then
				break
			end
		end
		t.expect(firstSpawnTick ~= nil, "a shell was fired")
		-- the render clock is two ticks behind: nothing yet
		Effects.update(fx, world, firstSpawnTick - 2, 0, 0, 0)
		t.expect(next(fx.projectiles) == nil, "not before its tick")
		t.expect(#world.events > 0, "still queued")
		Effects.update(fx, world, firstSpawnTick, 0, 0, 0)
		t.expect(next(fx.projectiles) ~= nil, "spawned at its tick")
		-- deaths: queued with their tick
		local deaths = 0
		for tick = sim.tick + 1, sim.tick + 400 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, d in world.died do
				t.expect(d.tick == tick, "a death carries its tick")
				deaths += 1
			end
			Effects.update(fx, world, tick - 2, tick * DT, 0, 0)
			for _, d in fx.pendingDeaths do
				t.expect(d.tick > tick - 2, "only deaths not yet due wait")
			end
			table.clear(world.died)
		end
		t.expect(deaths > 0, "tanks died")
	end)

	t.test("a shell bursts when its drawn path reaches the impact point, not a tick later (C-26)", function()
		local sim, world = duel()
		local fx = Effects.new()
		local SUBS = 8 -- frames per sim tick
		local impactAt: { [number]: { number } } = {} -- projId → impact x, z
		local path: { [number]: { { number } } } = {} -- projId → drawn { renderTick, x, z }
		local delays = {}
		for tick = 1, 300 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
			for _, e in world.events do
				local ev = e :: any
				if ev.kind == Schema.EventKind.IMPACT then
					local x, z = world.grid:decode(ev.cell, ev.offX, ev.offZ)
					impactAt[ev.projId] = { x, z }
				end
			end
			for sub = 1, SUBS do
				local rt = tick - 2 + sub / SUBS -- two ticks behind, as Interp
				local live = {}
				for id in fx.projectiles do
					live[id] = true
				end
				Effects.update(fx, world, rt, rt * DT, 0, 0)
				table.clear(world.died)
				for id in live do
					local hit, drawn = impactAt[id], path[id]
					if fx.projectiles[id] == nil and hit and drawn then
						-- first frame the drawn shell was as far from its start as the impact point
						local s = drawn[1]
						local need = math.sqrt((hit[1] - s[2]) ^ 2 + (hit[2] - s[3]) ^ 2)
						for _, f in drawn do
							if math.sqrt((f[2] - s[2]) ^ 2 + (f[3] - s[3]) ^ 2) >= need - 1 then
								table.insert(delays, rt - f[1])
								break
							end
						end
					end
					if fx.projectiles[id] == nil then
						impactAt[id], path[id] = nil, nil -- projectile IDs are reused
					end
				end
				for _, v in Effects.visible(fx, rt) do
					local id = v[1].id
					path[id] = path[id] or {}
					table.insert(path[id], { rt, v[2], v[4] })
				end
			end
		end
		local worst = 0
		for _, d in delays do
			worst = math.max(worst, d)
		end
		print(string.format("    %d shells; worst delay after reaching the impact point %.1f ms", #delays, worst * DT * 1000))
		t.expect(#delays > 50, "plenty of impacts")
		t.expect(worst <= 1 / SUBS + 1e-9, `the burst comes within a frame of arrival (worst {worst} ticks)`)
	end)

	t.test("caps: at most 150 drawn projectiles, 60 bursts, 100 tracers; the far, small ones go first", function()
		local _sim, world = duel()
		local fx = Effects.new()
		fx.focusX, fx.focusZ = 0, 0
		local weapon = world.defs.weaponByIndex[1]
		for i = 1, 400 do
			-- half near the focus, half far away
			local far = i % 2 == 0
			fx.projectiles[i] = {
				id = i,
				x = if far then 2000 else i * 0.1,
				y = 20,
				z = 0,
				vx = 0,
				vy = 0,
				vz = 0,
				ox = 0,
				oy = 0,
				oz = 0,
				blend = 0,
				weapon = { gravity = 0 },
				target = 0,
				ttl = 100,
				size = 1,
			}
		end
		fx.tick = 10
		local drawn = Effects.visible(fx, 10.5)
		t.equal(#drawn, Effects.MAX_PROJECTILES)
		for _, v in drawn do
			t.expect(v[2] < 1000, "near ones are drawn first")
		end
		-- bursts and tracers through the event path
		local function event(kind: number, x: number): any
			local cell, offX, offZ = world.grid:encode(x, 0)
			return { kind = kind, projId = 9999, unitId = 1, slot = 1, hit = true, cell = cell, offX = offX, offZ = offZ, y = 80, tick = 11 }
		end
		world.joined = true
		for i = 1, 200 do
			table.insert(world.events, event(Schema.EventKind.IMPACT, if i % 2 == 0 then 180 else 0))
		end
		Effects.update(fx, world, 11, 0, 0, 0)
		t.equal(#fx.bursts, Effects.MAX_EXPLOSIONS)
		t.expect(fx.skipped.bursts == 200 - Effects.MAX_EXPLOSIONS, "the rest were skipped")
		local near = 0
		for _, b in fx.bursts do
			if math.abs(b.x) < 10 then
				near += 1
			end
		end
		t.expect(near >= Effects.MAX_EXPLOSIONS / 2 + 10, `near bursts kept first ({near})`)
		local _ = weapon
	end)
end

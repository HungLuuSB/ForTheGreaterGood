--!strict
-- Strategic zoom icons (client task 8): the client numbers icons like the
-- server, strategic records get the right family, blips and ghosts look
-- apart, and the zoom switch has hysteresis.

local Commands = require("../../src/client/Core/Commands")
local Icons = require("../../src/client/Core/Icons")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Defs = require("@shared/Defs/Defs")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("icon numbers match the server's", function()
		local defs = Defs.load()
		local mine = Icons.table(defs)
		t.deepEqual(mine.byDef, NetOut.iconIndex(defs))
		for n, def in mine.sample do
			t.equal(mine.names[n], def.icon)
		end
	end)

	t.test("every def has an icon family; builders, air, naval and structures look apart", function()
		local defs = Defs.load()
		local tbl = Icons.table(defs)
		local world = World.new(defs)
		local seen: { [string]: boolean } = {}
		for _, def in defs.unitByIndex do
			local u: any = { id = 1, team = 1, defIndex = def.index, flags = 0, x = 0, z = 0, alt = 0 }
			local s = Icons.style(tbl, world, u, false)
			seen[s.shape] = true
			t.expect(s.size >= 8 and s.size <= 26, `{def.id}: size {s.size}`)
			if def.domain == "air" then
				t.equal(s.shape, "triangle", def.id)
			elseif def.domain == "naval" then
				t.equal(s.shape, "diamond", def.id)
			elseif def.domain == "structure" then
				t.equal(s.shape, "frame", def.id)
			end
		end
		for _, shape in { "square", "circle", "diamond", "triangle", "frame" } do
			t.expect(seen[shape], `some unit is a {shape}`)
		end
	end)

	t.test("strategic records: real icons for known units, blips for radar contacts, ghosts", function()
		local defs = Defs.load()
		local tbl = Icons.table(defs)
		local world = World.new(defs)
		local lancer = defs.units.ord_lancer
		local SF = Schema.StrategicFlag
		local function style(icon: number, flags: number): any
			return Icons.style(tbl, world, { id = 5, team = 2, icon = icon, flags = flags, x = 0, z = 0, alt = 0 } :: any, false)
		end
		t.equal(style(tbl.byDef[lancer.index], 0).shape, "square", "a seen Lancer")
		t.equal(style(0, SF.RADAR_ONLY).shape, "blip", "an unidentified radar contact")
		local tracked = style(tbl.byDef[lancer.index], SF.RADAR_ONLY + SF.TRACKED)
		t.equal(tracked.shape, "square", "a tracked contact shows its real icon")
		t.equal(tracked.alpha, 1)
		t.equal(style(tbl.byDef[defs.units.ord_generator.index], SF.GHOST).shape, "ghost")
	end)

	t.test("draws: every known unit of a live match, selected last; hysteresis", function()
		local sim = Sim.new({ seed = 7, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:48", scenario = "duel_test" })
		local world = World.new(sim.defs)
		NetOut.join(sim, 1)
		assert(Sim.submit(sim, 1, Commands.camera(0, 0, 10, 10))) -- a corner: everyone strategic
		for tick = 1, 12 do
			Sim.step(sim)
			NetIn.applyOutbox(world, sim.net.players[1].outbox, tick * DT)
		end
		local tbl = Icons.table(sim.defs)
		local project = function(x: number, _y: number, z: number)
			return (x + 192) * 2, (z + 192) * 2, true
		end
		local own = World.ownIds(world)
		local known = 0
		for _ in world.units do
			known += 1
		end
		t.expect(known == 20, `all 20 known ({known})`)
		local selectedId
		for id, u in world.units do
			if u.team == 1 then
				selectedId = id
				break
			end
		end
		local draws = Icons.draws(tbl, world, project, 768, 768, { [selectedId] = true })
		t.equal(#draws, known)
		t.equal(draws[#draws].id, selectedId, "selected on top")
		t.expect(draws[#draws].style.selected)
		for _, d in draws do
			t.expect(d.style.shape == "square", "strategic Lancers and Ravagers are squares")
		end
		local _ = own
		t.expect(not Icons.strategic(false, 450) and Icons.strategic(false, 500), "enter beyond 480")
		t.expect(Icons.strategic(true, 450) and not Icons.strategic(true, 400), "leave below 420")
	end)
end

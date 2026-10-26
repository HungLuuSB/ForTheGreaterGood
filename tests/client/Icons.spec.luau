--!strict
-- Strategic zoom icons (client task 8): the client numbers icons like the
-- server, strategic records get the right family, blips and ghosts look
-- apart, and the zoom switch has hysteresis.

local Commands = require("../../src/client/Core/Commands")
local Icons = require("../../src/client/Core/Icons")
local IconAtlas = require("../../src/client/UI/IconAtlas")
local NetIn = require("../../src/client/Core/NetIn")
local World = require("../../src/client/Core/World")
local NetOut = require("../../src/server/Sim/NetOut")
local Sim = require("../../src/server/Sim/Sim")
local Spawn = require("../../src/server/Sim/Spawn")
local Defs = require("@shared/Defs/Defs")
local Schema = require("@shared/Net/Schema")

local DT = 1 / 15

return function(t: any)
	t.test("icon numbers match the server's", function()
		local defs = Defs.load()
		local mine = Icons.table(defs)
		t.deepEqual(mine.byDef, NetOut.iconIndex(defs))
		-- unique per unit type since S-58: icon n is def n itself
		for n, def in mine.sample do
			t.equal(def, defs.unitByIndex[n])
		end
		t.equal(#mine.sample, #defs.unitByIndex)
		-- every unit type its own two-letter code (C-67)
		local seen: { [string]: string } = {}
		for index, def in defs.unitByIndex do
			local code = mine.codes[index]
			t.expect(code ~= nil and #code == 2, `{def.id} has a two-letter code ({code})`)
			t.expect(seen[code] == nil, `{def.id} and {seen[code]} share "{code}"`)
			seen[code] = def.id
		end
	end)

	t.test("every def draws its catalogue tile, larger for higher tiers", function()
		local defs = Defs.load()
		local tbl = Icons.table(defs)
		local world = World.new(defs)
		for _, def in defs.unitByIndex do
			local u: any = { id = 1, team = 1, defIndex = def.index, flags = 0, x = 0, z = 0, alt = 0 }
			local s = Icons.style(tbl, world, u, false)
			t.equal(s.kind, "unit", def.id)
			t.equal(s.tile, IconAtlas.byDef[def.id].tile, def.id)
			t.expect(s.size >= Icons.BASE and s.size <= 30, `{def.id}: size {s.size}`)
		end
		t.expect(Icons.style(tbl, world, { id = 1, team = 1, defIndex = defs.units.ord_paladin.index, flags = 0, x = 0, z = 0, alt = 0 } :: any, false).size > Icons.BASE, "T2 drawn larger")
		t.equal(IconAtlas.byDef.ord_lancer.tile, IconAtlas.byDef.chs_ravager.tile, "faction counterparts share an icon (the catalogue)")
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
		t.equal(style(tbl.byDef[lancer.index], 0).tile, IconAtlas.byDef.ord_lancer.tile, "a seen Lancer")
		t.equal(style(0, SF.RADAR_ONLY).tile, IconAtlas.contacts.vehicle, "an unidentified radar contact: a dashed vehicle frame")
		t.equal(style(tbl.byDef[lancer.index], SF.RADAR_ONLY).tile, IconAtlas.contacts.vehicle, "an untracked contact shows only its frame")
		t.equal(style(tbl.byDef[defs.units.ord_falcon.index], SF.RADAR_ONLY).tile, IconAtlas.contacts.air)
		local tracked = style(tbl.byDef[lancer.index], SF.RADAR_ONLY + SF.TRACKED)
		t.equal(tracked.tile, IconAtlas.byDef.ord_lancer.tile, "a tracked contact shows its real icon")
		t.equal(tracked.alpha, 1)
		local ghost = style(tbl.byDef[defs.units.ord_generator.index], SF.GHOST)
		t.equal(ghost.kind, "ghost")
		t.equal(ghost.tile, IconAtlas.byDef.ord_generator.tile, "a ghost is its type's tile")
		t.expect(math.abs(ghost.alpha - 0.45) < 1e-6, "at 45% opacity")
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
			t.expect(d.style.tile == IconAtlas.byDef.ord_lancer.tile, "strategic Lancers and Ravagers draw the Light Tank icon")
		end
		local _ = own
		t.expect(not Icons.strategic(false, 450) and Icons.strategic(false, 500), "enter beyond 480")
		t.expect(Icons.strategic(true, 450) and not Icons.strategic(true, 400), "leave below 420")
	end)

	t.test("the Wraith: its owner sees the Decoy Drone; an enemy's radar sees a strategic bomber until it sees it (S-109, C-183)", function()
		-- (a big map: idle aircraft drift a long way while loitering, S-178's
		-- sharper turns; out of the beacon's sight, inside its radar)
		local sim = Sim.new({ seed = 1, players = { { id = 1, team = 1 }, { id = 2, team = 2 } }, mapId = "flat:128", scenario = "empty" })
		Spawn.unit(sim, "ord_beacon", 1, -420, 0, 0)
		local wraith = Spawn.unit(sim, "chs_wraith", 2, 300, 0, 0)
		local bomber = Spawn.unit(sim, "chs_behemoth", 2, 300, 160, 0)
		local function view(player: number): World.World
			local world = World.new(sim.defs)
			NetOut.join(sim, player)
			local g = sim.map.layers.grid
			assert(Sim.submit(sim, player, Commands.camera(0, 0, g.cellsX - 1, g.cellsZ - 1)))
			return world
		end
		local enemy, owner = view(1), view(2)
		for tick = 1, 150 do -- (both climb to cruise height)
			Sim.step(sim)
			NetIn.applyOutbox(enemy, sim.net.players[1].outbox, tick / 15)
			NetIn.applyOutbox(owner, sim.net.players[2].outbox, tick / 15)
		end
		local t1 = Icons.table(sim.defs)
		local mine = Icons.style(t1, owner, owner.units[wraith], false)
		t.equal(mine.tile, IconAtlas.byDef.chs_wraith.tile, "the owner sees the Decoy Drone")
		t.equal(IconAtlas.byDef.chs_wraith.name, "Decoy Drone")
		local w = enemy.units[wraith]
		t.expect(w ~= nil and bit32.band(w.flags or 0, Schema.StrategicFlag.RADAR_ONLY) ~= 0, "the enemy has the Wraith as a radar blip")
		t.equal(t1.sample[w.icon].id, "chs_behemoth", "its icon is the spoof's: a strategic bomber")
		-- on radar a unit shows only its frame: the Wraith the frame of a
		-- known strategic bomber (a never-seen real one has no icon yet)
		local seen = Icons.style(t1, enemy, w, false)
		t.equal(seen.kind, "contact")
		t.equal(seen.tile, IconAtlas.contacts[IconAtlas.byDef.chs_behemoth.frame], "a bomber's radar frame")
		t.expect(seen.tile ~= IconAtlas.byDef.chs_wraith.tile, "not the Decoy Drone")
		t.equal(enemy.units[bomber].icon, 0, "(a real bomber never seen shows a blank blip)")
		-- in sight it's identified
		Spawn.unit(sim, "ord_herald", 1, sim.world.posX[wraith] - 20, sim.world.posZ[wraith] - 20, 0)
		for tick = 151, 170 do
			Sim.step(sim)
			NetIn.applyOutbox(enemy, sim.net.players[1].outbox, tick / 15)
			NetIn.applyOutbox(owner, sim.net.players[2].outbox, tick / 15)
		end
		local id = Icons.style(t1, enemy, enemy.units[wraith], false)
		t.equal(id.tile, IconAtlas.byDef.chs_wraith.tile, "seen: the Decoy Drone")
	end)
end

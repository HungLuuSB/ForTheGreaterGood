--!strict
local Json = require("./Support/Json")
local MatchExport = require("./Support/MatchExport")
local Scenes = require("./Support/Scenes")
local Sensors = require("../Sim/Sensors")
local RunAll = require("./RunAll")

local L = Sensors.Level

return function(t: RunAll.Context)
	t.test("JSON: round trip, escapes, empty arrays, number formatting", function()
		local value = {
			name = 'say "hi"\n\tback\\slash',
			list = { 1, -2.5, 0.125, 3, 1e-4 },
			empty = Json.array(),
			obj = { b = true, a = false, n = 1234567 },
			nested = { { 1, 2 }, { x = "y" } },
		}
		local s = Json.encode(value)
		t.equal(Json.encode({ 1.5, 2, 0.333333 }), "[1.5,2,0.333]", "integers bare, decimals trimmed")
		t.equal(Json.encode({ b = 1, a = 2 }), '{"a":2,"b":1}', "sorted keys")
		t.equal(Json.encode(Json.array()), "[]")
		local back = Json.decode(s)
		t.equal(back.name, value.name)
		t.deepEqual(back.list, { 1, -2.5, 0.125, 3, 0 })
		t.equal(#back.empty, 0)
		t.deepEqual(back.obj, value.obj)
		t.deepEqual(back.nested, value.nested)
		t.throws(function()
			Json.encode({ math.huge })
		end, "infinity")
	end)

	t.test("base64 matches the standard alphabet and padding", function()
		local function b(s: string): string
			local bytes = {}
			for i = 1, #s do
				bytes[i] = string.byte(s, i)
			end
			return MatchExport.base64(bytes)
		end
		t.equal(b("Man"), "TWFu")
		t.equal(b("Ma"), "TWE=")
		t.equal(b("M"), "TQ==")
		t.equal(b(""), "")
		t.equal(MatchExport.base64({ 0, 255, 128 }), "AP+A")
	end)

	t.test("spectator export: frames, map, units and projectiles match the sim", function()
		local scene = Scenes.matchup("ord_lancer", "chs_ravager", "close", 3)
		local checked = 0
		local data = MatchExport.record(scene, "matchup:ord_lancer:chs_ravager", {
			view = "spectator",
			every = 3,
			maxTicks = 90,
			onFrame = function(sim, frame)
				t.equal(#frame.u, #sim.world.ids, "every unit of the sim is in the frame")
				t.equal(#frame.p, #sim.combat.proj, "every projectile too")
				checked += 1
			end,
		})
		local meta, map = data.meta, data.map
		t.equal(meta.format, "ftgg-match")
		t.equal(meta.version, 2)
		t.equal(meta.view, "spectator")
		t.equal(#map.height, map.cellsX * map.cellsZ, "height per cell")
		t.equal(#map.water, map.cellsX * map.cellsZ, "water per cell")
		t.equal(#data.frames, checked)
		t.equal(#data.frames, 90 // 3 + 1, "the start plus one frame every 3 ticks")
		local projectiles, events = 0, 0
		local minX, maxX = map.originX, map.originX + map.cellsX * map.cellSize
		for k, f in data.frames do
			t.equal(f.t, (k - 1) * 3, "frame ticks")
			t.equal(f.fog, nil, "no fog in the spectator view")
			for _, u in f.u do
				t.equal(#u, 11, "unit row length")
				t.expect(data.defs[u[2]] ~= nil, "a known def")
				t.expect(u[4] >= minX and u[4] <= maxX, "inside the map")
				t.expect(u[7] >= 0 and u[7] <= 1000, "health per mille")
			end
			projectiles += #f.p
			for _, e in f.e do
				t.expect(e[1] == "impact" or e[1] == "death" or e[1] == "decoy" or e[1] == "lost", `event kind {e[1]}`)
				events += 1
			end
		end
		t.expect(projectiles > 0 and events > 0, `shots recorded ({projectiles} projectile samples, {events} events)`)
		-- an exact round trip through JSON
		local back = Json.decode(MatchExport.encode(data))
		t.deepEqual(back.frames[10].u, data.frames[10].u, "unit rows survive the round trip")
		t.deepEqual(back.meta.icons, data.meta.icons)
		t.equal(back.defs[1].kind, data.defs[1].kind)
	end)

	t.test("player export: only what the player's client received, plus its sight map", function()
		-- Seraph radar SAM trucks (radar 520, sight 150) against Harpies 600 studs
		-- off: the fighters show up as radar blips before they are in sight
		local scene = Scenes.matchup("ord_seraph", "chs_harpy", "long", 2)
		local everKnown: { [number]: boolean } = {}
		local hiddenAll: { [number]: boolean } = {}
		local ally = 0
		local seen: { [number]: boolean } = {}
		local drawn, impacts, farthest, homingFarthest = 0, 0, 0, 0
		local data = MatchExport.record(scene, "matchup:ord_seraph:chs_harpy:long", {
			view = "player",
			player = 1,
			every = 1,
			maxTicks = 300,
			onFrame = function(sim, frame)
				local w = sim.world
				ally = sim.players[1].allyTeam :: number
				for _, id in w.ids do
					local level = Sensors.level(sim, ally, id)
					if level ~= L.HIDDEN then
						everKnown[id] = true
						hiddenAll[id] = nil
					elseif not everKnown[id] then
						hiddenAll[id] = true
					end
				end
				for _, u in frame.u do
					local id = u[1]
					seen[id] = true
					t.expect(w.slot[id] ~= nil, "tactical units are alive")
					t.expect(w.ally[id] == ally or Sensors.level(sim, ally, id) == L.VISIBLE, `tactical unit {id} is allied or VISIBLE`)
				end
				for _, r in frame.s do
					seen[r[1]] = true
					t.expect(everKnown[r[1]] or Sensors.level(sim, ally, r[1]) ~= L.HIDDEN, `strategic record {r[1]} was known`)
				end
				-- the fog bitmap is the ally team's sight map
				local los = sim.sensors.maps[ally].los
				local g = (sim.map :: any).grid
				local cells = g.sensorX * g.sensorZ
				local bytes = table.create((cells + 7) // 8, 0)
				for i = 0, cells - 1 do
					if buffer.readu16(los, i * 2) > 0 then
						bytes[i // 8 + 1] += 2 ^ (7 - i % 8)
					end
				end
				t.equal(frame.fog, MatchExport.base64(bytes), "fog = sight map")
				-- projectiles: the client's own, stepped from SPAWN_PROJ (D99);
				-- each unguided one is where a live server projectile is
				local c = sim.combat
				for _, p in frame.p do
					drawn += 1
					local best = math.huge
					for _, id in c.proj do
						best = math.min(best, math.sqrt((c.px[id] - p[1]) ^ 2 + (c.py[id] - p[2]) ^ 2 + (c.pz[id] - p[3]) ^ 2))
					end
					if sim.defs.weaponByIndex[p[4]].turnRate then
						homingFarthest = math.max(homingFarthest, best)
					else
						farthest = math.max(farthest, best)
					end
				end
				for _, e in frame.e do
					if e[1] == "impact" then
						impacts += 1
					end
				end
			end,
		})
		t.equal(data.meta.view, "player")
		t.equal(data.meta.player, 1)
		for id in hiddenAll do
			t.expect(not seen[id], `unit {id} was hidden all along and never shown`)
		end
		local blips = 0
		for _, f in data.frames do
			for _, r in f.s do
				if r[5] % 2 == 1 then
					blips += 1
				end
			end
		end
		t.expect(blips > 0, `radar blips were recorded ({blips})`)
		t.expect(drawn > 0 and impacts > 0, `the player view has projectiles ({drawn}) and impacts ({impacts}) from the wire`)
		t.expect(farthest < 1, `each unguided projectile drawn is a server one (worst {farthest} studs)`)
		print(string.format("    player view: %d projectile draws, %d impacts; unguided worst %.2f studs, homing worst %.0f studs from the server's", drawn, impacts, farthest, homingFarthest))
	end)

	t.test("exports are deterministic", function()
		local function export(): string
			local scene = Scenes.matchup("ord_falcon", "chs_wasp", "long", 4)
			return MatchExport.encode(MatchExport.record(scene, "m", { view = "spectator", every = 5, maxTicks = 150 }))
		end
		t.equal(export(), export())
	end)
end

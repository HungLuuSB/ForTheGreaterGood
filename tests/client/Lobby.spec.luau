--!strict
-- The match flow's lobby (C-70; seats since C-77, src/roblox/Lobby):
-- humans take seats, the host runs the settings, every human picks their
-- faction, every named map and mode gives a Sim config the sim accepts and
-- the AI plays, and the results name the winner once the humans are out.

local Lobby = require("../../src/roblox/Lobby")
local Stats = require("../../src/server/Sim/Stats")
local Combat = require("../../src/server/Sim/Combat/Combat")
local Sim = require("../../src/server/Sim/Sim")
local Skirmish = require("../../src/server/Sim/AI/Skirmish")
local MapRegistry = require("@shared/Grid/MapRegistry")

local function maps(): { Lobby.Map }
	local out = {}
	for _, id in { "map:ridgeline", "map:twin_lakes", "map:crossroads", "map:normandy" } do
		local layers = assert(MapRegistry.load(id))
		table.insert(out, { id = id, name = id, starts = #layers.starts })
	end
	return out
end

local function run(sim: any, brains: { any }, n: number)
	for _ = 1, n do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
	end
end

return function(t: any)
	t.test("seats: the first human hosts, a second takes the open seat, a third watches", function()
		local m = maps()
		local s = Lobby.new(m)
		t.equal(Lobby.seat(s, 101, "Ann"), 1)
		t.equal(Lobby.seat(s, 101, "Ann"), 1, "seated once")
		t.equal(Lobby.seat(s, 202, "Bo"), nil, "seat 2 is an AI: no seat")
		local _, notHost = Lobby.apply(s, m, { op = "slot", index = 2, kind = "open" }, 2)
		t.expect(notHost ~= nil, "only the host opens seats")
		Lobby.apply(s, m, { op = "slot", index = 2, kind = "open" }, 1)
		t.equal(Lobby.seat(s, 202, "Bo"), 2)
		t.equal(s.slots[2].kind, "human")
		t.equal(Lobby.seat(s, 303, "Cy"), nil, "no free seat")
		-- each human picks their own faction; the host can't change a human's
		Lobby.apply(s, m, { op = "faction", index = 2, value = "order" }, 2)
		t.equal(s.slots[2].faction, "order")
		local _, theirs = Lobby.apply(s, m, { op = "faction", index = 2, value = "chaos" }, 1)
		t.expect(theirs ~= nil, "the host can't pick a human's faction")
		local _, busy = Lobby.apply(s, m, { op = "slot", index = 2, kind = "ai" }, 1)
		t.expect(busy ~= nil, "a human's seat can't become an AI")
		-- the host leaves: the other human hosts
		Lobby.leave(s, 101)
		t.equal(Lobby.slotOf(s, 202), 1)
		t.equal(s.slots[2].kind, "open")
	end)

	t.test("settings: host only, validated; seats fit the map's starts", function()
		local m = maps()
		local s = Lobby.new(m)
		Lobby.seat(s, 1, "Host")
		local _, err = Lobby.apply(s, m, { op = "set", key = "mode", value = "WAR" }, 1)
		t.expect(err ~= nil, "a bad mode is refused")
		Lobby.apply(s, m, { op = "set", key = "mapId", value = "map:crossroads" }, 1)
		Lobby.apply(s, m, { op = "slot", index = 3, kind = "ai", level = "hard" }, 1)
		Lobby.apply(s, m, { op = "slot", index = 4, kind = "ai", level = "easy" }, 1)
		local _, full = Lobby.apply(s, m, { op = "slot", index = 5, kind = "ai", level = "easy" }, 1)
		t.equal(#s.slots, 4)
		t.expect(full ~= nil, "a 4-start map takes 4 seats")
		t.equal(s.slots[3].level, "hard")
		Lobby.apply(s, m, { op = "set", key = "mapId", value = "map:normandy" }, 1)
		t.equal(#s.slots, 2) -- a 2-start map keeps two
		local action = Lobby.apply(s, m, { op = "start" }, 1)
		t.equal(action, "start")
		t.equal(s.phase, "playing")
		local _, on = Lobby.apply(s, m, { op = "faction", index = 1, value = "chaos" }, 1)
		t.expect(on ~= nil, "no changes during a match")
	end)

	t.test("every map and mode gives a config the sim accepts and the AI plays", function()
		local m = maps()
		for _, map in m do
			for _, mode in Lobby.MODES do
				local s = Lobby.new(m)
				Lobby.seat(s, 1, "Host")
				Lobby.apply(s, m, { op = "set", key = "mapId", value = map.id }, 1)
				Lobby.apply(s, m, { op = "set", key = "mode", value = mode }, 1)
				Lobby.apply(s, m, { op = "faction", index = 1, value = "chaos" }, 1)
				for i = 3, map.starts do
					Lobby.apply(s, m, { op = "slot", index = i, kind = "ai", level = Lobby.LEVELS[(i % 3) + 1] }, 1)
					Lobby.apply(s, m, { op = "ally", index = i, value = (i % 2) + 1 }, 1)
				end
				local action = Lobby.apply(s, m, { op = "start" }, 1)
				t.equal(action, "start", `{map.id} {mode}`)
				local sim = Sim.new(Lobby.config(s, 7))
				local brains = Skirmish.forMatch(sim)
				t.equal(#brains, #s.slots - 1)
				t.equal(sim.players[1].team % 2, 0) -- Chaos: an even team
				if mode == "TEAM" then
					t.equal(sim.players[1].allyTeam, 1)
					t.equal(sim.players[2].allyTeam, 2)
				end
				run(sim, brains, 150)
				t.expect(#sim.world.ids > #sim.playerOrder, `{map.id} {mode}: the AI builds`)
			end
		end
	end)

	t.test("two humans: both play, open seats drop out at the start, the results find each", function()
		local m = maps()
		local s = Lobby.new(m)
		Lobby.seat(s, 11, "Ann")
		Lobby.apply(s, m, { op = "set", key = "mapId", value = "map:crossroads" }, 1)
		Lobby.apply(s, m, { op = "slot", index = 2, kind = "open" }, 1)
		Lobby.apply(s, m, { op = "slot", index = 3, kind = "open" }, 1)
		Lobby.apply(s, m, { op = "slot", index = 4, kind = "ai", level = "easy" }, 1)
		t.equal(Lobby.seat(s, 22, "Bo"), 2)
		t.equal(Lobby.apply(s, m, { op = "start" }, 1), "start")
		t.equal(#s.slots, 3, "the empty seat 3 dropped out")
		t.equal(s.slots[3].kind, "ai")
		t.deepEqual(Lobby.humans(s), { 1, 2 })
		local sim = Sim.new(Lobby.config(s, 5))
		local brains = Skirmish.forMatch(sim)
		t.equal(#brains, 1, "one AI")
		run(sim, brains, 450)
		t.expect(not Lobby.done(s, sim), "both humans in")
		-- one human out: the match goes on for the other
		for _, id in sim.world.ids do
			if sim.world.owner[id] == 1 then
				Combat.queueDamage(sim.combat, id, 1e6, 0)
			end
		end
		run(sim, brains, 30)
		t.expect(sim.match.eliminated[1] ~= nil, "Ann is out")
		t.expect(not Lobby.done(s, sim), "Bo still plays")
		for _, id in sim.world.ids do
			if sim.world.owner[id] == 2 then
				Combat.queueDamage(sim.combat, id, 1e6, 0)
			end
		end
		run(sim, brains, 30)
		t.expect(Lobby.done(s, sim), "every human out")
		local r = Lobby.results(s, sim, 0, Stats.report(sim))
		t.equal(r.players[1].user, 11)
		t.equal(r.players[2].user, 22)
		t.equal(r.players[1].name, "Ann")
		t.equal(r.players[3].name, "AI 1 (easy)")
		t.expect(r.players[1].stats.unitsLost >= 1, `Ann lost units ({r.players[1].stats.unitsLost})`)
		t.expect(r.players[3].stats.unitsBuilt >= 1, `the AI built ({r.players[3].stats.unitsBuilt})`)
		t.expect(r.players[3].stats.supplySpent > 0 and r.players[3].stats.powerGathered > 0, "spent and gathered")
		s.phase, s.results = "results", r
		local _, notHost = Lobby.apply(s, m, { op = "lobby" }, 2)
		t.expect(notHost ~= nil, "only the host goes back")
		t.equal(Lobby.apply(s, m, { op = "lobby" }, 1), "lobby")
		t.equal(Lobby.slotOf(s, 22), 2, "Bo keeps the seat")
	end)

	t.test("statistics in the results: the sim's Stats.report (S-63)", function()
		local m = maps()
		local s = Lobby.new(m)
		Lobby.seat(s, 1, "Host")
		Lobby.apply(s, m, { op = "slot", index = 2, kind = "ai", level = "hard" }, 1)
		Lobby.apply(s, m, { op = "start" }, 1)
		local sim = Sim.new(Lobby.config(s, 3))
		local brains = Skirmish.forMatch(sim)
		run(sim, brains, 15 * 60)
		local r = Lobby.results(s, sim, 0, Stats.report(sim))
		local ai = r.players[2].stats
		t.expect(ai.unitsBuilt >= 3, `the AI built units ({ai.unitsBuilt})`)
		t.expect(ai.supplyGathered > 0 and ai.powerGathered > 0, `gathered {ai.supplyGathered} / {ai.powerGathered}`)
		t.expect(ai.supplySpent > 0 and ai.powerSpent > 0, `spent {ai.supplySpent} / {ai.powerSpent}`)
		t.equal(r.players[1].stats.unitsBuilt, 0, "the idle human built nothing")
		print(string.format("    a minute of hard AI: built %d, supply %d / %d, power %d / %d", ai.unitsBuilt, ai.supplyGathered, ai.supplySpent, ai.powerGathered, ai.powerSpent))
	end)
end

--!strict
-- The match flow's lobby (C-70, src/roblox/Lobby): settings are validated,
-- every named map and mode gives a Sim config the sim accepts and the AI
-- plays, and the results name the winner once the human's Command Vehicle
-- dies (Command Ends).

local Lobby = require("../../src/roblox/Lobby")
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

return function(t: any)
	t.test("settings are validated; AI slots fit the map's starts", function()
		local m = maps()
		local s = Lobby.new(m)
		t.equal(s.phase, "lobby")
		local _, err = Lobby.apply(s, m, { op = "set", key = "mode", value = "WAR" })
		t.expect(err ~= nil, "a bad mode is refused")
		Lobby.apply(s, m, { op = "set", key = "mapId", value = "map:crossroads" })
		Lobby.apply(s, m, { op = "ai", index = 2, level = "hard" })
		Lobby.apply(s, m, { op = "ai", index = 3, level = "easy" })
		local _, full = Lobby.apply(s, m, { op = "ai", index = 4, level = "easy" })
		t.equal(#s.ai, 3)
		t.expect(full ~= nil, "a 4-start map takes 3 AIs")
		Lobby.apply(s, m, { op = "set", key = "mapId", value = "map:normandy" })
		t.equal(#s.ai, 1) -- a 2-start map keeps one
		local action = Lobby.apply(s, m, { op = "start" })
		t.equal(action, "start")
		t.equal(s.phase, "playing")
		local _, busy = Lobby.apply(s, m, { op = "set", key = "faction", value = "chaos" })
		t.expect(busy ~= nil, "no changes during a match")
	end)

	t.test("every map and mode gives a config the sim accepts and the AI plays", function()
		local m = maps()
		for _, map in m do
			for _, mode in Lobby.MODES do
				local s = Lobby.new(m)
				Lobby.apply(s, m, { op = "set", key = "mapId", value = map.id })
				Lobby.apply(s, m, { op = "set", key = "mode", value = mode })
				Lobby.apply(s, m, { op = "set", key = "faction", value = "chaos" })
				for i = 2, map.starts - 1 do
					Lobby.apply(s, m, { op = "ai", index = i, level = Lobby.LEVELS[(i % 3) + 1] })
				end
				local action = Lobby.apply(s, m, { op = "start" })
				if mode == "TEAM" and map.starts < 3 then
					t.expect(action == nil, `{map.id} TEAM needs 3 players`)
					continue
				end
				local sim = Sim.new(Lobby.config(s, 7))
				local brains = Skirmish.forMatch(sim)
				t.equal(#brains, #s.ai)
				t.equal(sim.players[1].team % 2, 0) -- Chaos: an even team
				for _ = 1, 150 do
					for _, b in brains do
						Skirmish.tick(b)
					end
					Sim.step(sim)
				end
				t.expect(#sim.world.ids > #sim.playerOrder, `{map.id} {mode}: the AI builds`)
			end
		end
	end)

	t.test("the human's Command Vehicle dies: the match is over, the AI won", function()
		local m = maps()
		local s = Lobby.new(m)
		Lobby.apply(s, m, { op = "start" })
		local sim = Sim.new(Lobby.config(s, 3))
		local brains = Skirmish.forMatch(sim)
		for _ = 1, 30 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
		end
		for _, id in sim.world.ids do
			if sim.world.owner[id] == 1 then
				Combat.queueDamage(sim.combat, id, 1e6, 0)
			end
		end
		for _ = 1, 30 do
			Sim.step(sim)
		end
		t.expect(sim.match.over, "the match is over")
		local r = Lobby.results(s, sim, 0)
		s.phase, s.results = "results", r
		t.equal(r.youWon, false)
		t.equal(r.over, true)
		t.equal(#r.players, 2)
		t.expect(r.players[1].outAt ~= nil, "you are out")
		t.equal(r.players[2].won, true)
		local action = Lobby.apply(s, m, { op = "lobby" })
		t.equal(action, "lobby")
		t.equal(s.phase, "lobby")
	end)
end

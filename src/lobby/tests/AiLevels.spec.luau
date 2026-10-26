--!strict
-- The AI levels and team roles in the room (F41, S-187): four levels, each
-- with a name and a picker name; the lobby's role badges follow the sim's
-- own rule (Skirmish.roleOf) for the config the room builds.

local Config = require("../shared/Config")
local MatchConfig = require("../shared/MatchConfig")
local Rooms = require("../shared/Rooms")
local Skirmish = require("../../server/Sim/AI/Skirmish")
local RunAll = require("../../server/Tests/RunAll")

local MAPS: { Rooms.MapInfo } = { { id = "map:quad", name = "Quad", starts = 4 } }
local LOBBY = { placeId = 1, jobId = "job" }

return function(t: RunAll.Context)
	t.test("four levels, each named, Hard - Balanced keeping the id hard", function()
		t.deepEqual(Config.LEVELS, { "easy", "normal", "hard", "hard_aggressive" })
		for _, v in Config.LEVELS do
			t.expect((Config.LABELS :: any)[v] ~= nil, `{v}: a name`)
			t.expect((Config.LEVEL_SHORT :: any)[v] ~= nil, `{v}: a picker name`)
		end
		t.equal((Config.LABELS :: any).hard, "Hard - Balanced")
		t.equal((Config.LABELS :: any).hard_aggressive, "Hard - Aggressive")
		local r = assert(Rooms.new("r1", { name = "Levels", privacy = "public" }, 10, "Host", MAPS))
		t.equal(Rooms.apply(r, MAPS, 10, { op = "addAi", level = "hard_aggressive" }), nil)
		local c = MatchConfig.build(r, "m1", 1, 0, LOBBY)
		t.equal(MatchConfig.validate(c), nil)
		t.equal(c.players[2].ai, "hard_aggressive")
		t.equal(c.players[2].name, "AI 1 (hard aggressive)")
	end)

	t.test("role badges follow the sim's rule for the room's config", function()
		t.deepEqual(Config.AI_ROLES, Skirmish.ROLES)
		local r = assert(Rooms.new("r2", { name = "Roles", privacy = "public", maxPlayers = 16 }, 10, "Host", MAPS))
		Rooms.apply(r, MAPS, 10, { op = "set", key = "mode", value = "TEAM" })
		Rooms.apply(r, MAPS, 10, { op = "mine", team = 1 })
		-- team 1: hard, aggressive, easy (easy never takes a role); team 2: three normal;
		-- team 3: one hard alone
		for _, a in { { 1, "hard" }, { 1, "hard_aggressive" }, { 1, "easy" }, { 2, "normal" }, { 2, "normal" }, { 2, "normal" }, { 3, "hard" } } do
			t.equal(Rooms.apply(r, MAPS, 10, { op = "addAi", team = a[1], level = a[2] }), nil)
		end
		local roles = MatchConfig.aiRoles(r)
		local c = MatchConfig.build(r, "m2", 1, 0, LOBBY)
		-- the sim's view of the same match
		local sim: any = { players = {}, playerOrder = {}, match = { ai = {} } }
		for _, p in c.players do
			sim.players[p.id] = { allyTeam = p.allyTeam }
			table.insert(sim.playerOrder, p.id)
			sim.match.ai[p.id] = p.ai
		end
		local seen = 0
		for _, seat in MatchConfig.seats(r) do
			local s = r.slots[seat.slot]
			if s.kind == "ai" then
				seen += 1
				t.equal(roles[seat.slot] or "balanced", Skirmish.roleOf(sim, seat.id, s.level), `slot {seat.slot} ({s.level}, team {s.team})`)
			end
		end
		t.equal(seen, 7)
		-- team 1's two non-easy AIs and team 2's three show badges; the easy one and the lone AI don't
		local badges = 0
		for _ in roles do
			badges += 1
		end
		t.equal(badges, 5)
	end)
end

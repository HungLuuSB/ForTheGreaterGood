--!strict
-- The AI rework (S-187, the user's F41): four levels (Hard - Aggressive
-- added), roles shared out on a side (air, defence, spam, tech), teamwork,
-- generators in a block, and the new units in the mix.
local Sim = require("../Sim/Sim")
local Skirmish = require("../Sim/AI/Skirmish")
local MatchConfig = require("@shared/Match/MatchConfig")
local RunAll = require("./RunAll")

local function teamMatch(levels: { string }, mapId: string?): Sim.Sim
	local players, ai = {}, {}
	local n = #levels
	for i, level in levels do
		table.insert(players, { id = i, team = i, allyTeam = if i <= n // 2 then 1 else 2 })
		ai[i] = level
	end
	return Sim.new({ seed = 5, players = players, mapId = mapId or "map:plains", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", startMode = "choose", ai = ai } })
end

local function run(sim: Sim.Sim, brains: { any }, ticks: number)
	for _ = 1, ticks do
		for _, b in brains do
			Skirmish.tick(b)
		end
		Sim.step(sim)
		if sim.match.over then
			return
		end
	end
end

local function owned(sim: Sim.Sim, player: number, suffix: string): number
	local w = sim.world
	local n = 0
	for _, id in w.ids do
		if w.owner[id] == player and string.sub(sim.defs.unitByIndex[w.defIndex[id]].id, 5) == suffix then
			n += 1
		end
	end
	return n
end

return function(t: RunAll.Context)
	t.test("four levels, the same names in the lobby's config", function()
		t.deepEqual(Skirmish.LEVEL_NAMES, { "easy", "normal", "hard", "hard_aggressive" })
		t.deepEqual(MatchConfig.LEVELS, Skirmish.LEVEL_NAMES)
		local hard, aggressive = Skirmish.LEVELS.hard, Skirmish.LEVELS.hard_aggressive
		t.expect(aggressive.firstWave < hard.firstWave and not aggressive.retreat and aggressive.raid and not aggressive.outweigh, "aggressive: earlier waves, no retreat, raids")
		t.expect(aggressive.defenses < hard.defenses, "and fewer turrets")
	end)

	t.test("roles go by spot: the AI nearest the enemy fights up front, the one farthest back takes air (S-207, H10)", function()
		local levels = { "normal", "normal", "normal", "normal", "normal", "normal", "normal", "normal" }
		local players, ai = {}, {}
		for i, level in levels do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 4 then 1 else 2 })
			ai[i] = level
		end
		local sim = Sim.new({ seed = 5, players = players, mapId = "map:supreme_strait", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", ai = ai } })
		local w = sim.world
		local front: { [number]: number } = {}
		for _, me in w.ids do
			if sim.defs.unitByIndex[w.defIndex[me]].id == "ord_sovereign" or sim.defs.unitByIndex[w.defIndex[me]].id == "chs_warlord" then
				local best = math.huge
				for _, them in w.ids do
					local td = sim.defs.unitByIndex[w.defIndex[them]].id
					if (td == "ord_sovereign" or td == "chs_warlord") and sim.players[w.owner[them]].allyTeam ~= sim.players[w.owner[me]].allyTeam then
						best = math.min(best, (w.posX[me] - w.posX[them]) ^ 2 + (w.posZ[me] - w.posZ[them]) ^ 2)
					end
				end
				front[w.owner[me]] = best
			end
		end
		for _, side in { { 1, 2, 3, 4 }, { 5, 6, 7, 8 } } do
			table.sort(side, function(a, b)
				return front[a] < front[b]
			end)
			t.equal(Skirmish.roleOf(sim, side[1], "normal"), "balanced", `side of {side[1]}: the front AI plays balanced`)
			t.equal(Skirmish.roleOf(sim, side[4], "normal"), "air", `side of {side[1]}: the back AI takes air`)
		end
	end)

	t.test("an AI's enemy starts are the enemy Commanders, not its allies' or empty spots (S-207, H15)", function()
		local levels = { "hard", "hard", "hard", "hard" }
		local players, ai = {}, {}
		for i, level in levels do
			table.insert(players, { id = i, team = i, allyTeam = if i <= 2 then 1 else 2 })
			ai[i] = level
		end
		local sim = Sim.new({ seed = 5, players = players, mapId = "map:supreme_strait", scenario = "standard_start", match = { mode = "TEAM", win = "COMMAND_ENDS", ai = ai } })
		local b = Skirmish.new(sim, 1, "hard") :: any
		t.equal(#b.enemyStarts, 2, "two enemy Commanders, of 16 map starts")
		local w = sim.world
		for _, s in b.enemyStarts do
			local owner = 0
			for _, id in w.ids do
				if math.abs(w.posX[id] - s[1]) < 1e-6 and math.abs(w.posZ[id] - s[2]) < 1e-6 then
					owner = w.owner[id]
				end
			end
			t.expect(owner == 3 or owner == 4, `an enemy Commander's spot ({s[1]}, {s[2]}: player {owner})`)
		end
	end)

	t.test("roles: a side's AIs take air, defence, spam and tech in turn; a lone AI plays balanced", function()
		local sim = teamMatch({ "hard", "hard", "hard", "hard", "normal", "hard", "hard", "easy" })
		local roles = {}
		for pid = 1, 8 do
			table.insert(roles, Skirmish.roleOf(sim, pid, sim.match.ai[pid]))
		end
		-- (in the pre-game no Commander stands yet: player order, the roles
		-- front to back, S-207)
		t.deepEqual(roles, { "balanced", "spam", "defense", "air", "balanced", "defense", "air", "balanced" })
		local lone = teamMatch({ "hard", "hard" })
		t.equal(Skirmish.roleOf(lone, 1, "hard"), "balanced", "1v1")
		local cfg = Skirmish.withRole(Skirmish.LEVELS.hard, "defense", "hard")
		t.expect(cfg.defenses > Skirmish.LEVELS.hard.defenses and cfg.teamwork and (cfg.lanes or 1) >= 2, "defence: more turrets; teamwork; waves in two lanes")
	end)

	t.slow("in a 3v3 the air AI builds an airfield early, the defence AI twice the turrets, and bot labs come into play", function()
		local sim = teamMatch({ "hard", "hard", "hard", "hard_aggressive", "hard_aggressive", "hard_aggressive" })
		local brains = Skirmish.forMatch(sim)
		run(sim, brains, 15 * 60 * 14) -- (14 min: S-193 slowed units and the bot lab waits for an established base)
		t.expect(owned(sim, 2, "airfield") + owned(sim, 5, "airfield") >= 1, "an air role built an airfield")
		local airUnits = 0
		for _, id in sim.world.ids do
			local d = sim.defs.unitByIndex[sim.world.defIndex[id]]
			if (sim.world.owner[id] == 2 or sim.world.owner[id] == 5) and d.domain == "air" then
				airUnits += 1
			end
		end
		t.expect(airUnits >= 2, `and flies aircraft ({airUnits})`)
		t.expect(owned(sim, 3, "sentry_tower") + owned(sim, 3, "guard") > owned(sim, 1, "sentry_tower") + owned(sim, 1, "guard"), "the defence AI has more turrets than the balanced one")
		t.expect(owned(sim, 4, "botlab") + owned(sim, 5, "botlab") + owned(sim, 6, "botlab") >= 1, "a bot lab")
	end)

	t.test("generators stand in a tidy block behind the base (F20)", function()
		local sim = teamMatch({ "hard", "hard" }, "map:ridgeline")
		local brains = Skirmish.forMatch(sim)
		run(sim, brains, 15 * 60 * 6)
		local w = sim.world
		local b = brains[1] :: any
		local xs: { [number]: boolean } = {}
		local n, onLattice = 0, 0
		for _, id in w.ids do
			if w.owner[id] == 1 and sim.defs.unitByIndex[w.defIndex[id]].id == b.prefix .. "solar" then -- the AI's generator since S-203
				n += 1
				-- distance behind the base along its axis, on the GEN_GAP lattice
				local along = (w.posX[id] - b.homeX) * b.dirX + (w.posZ[id] - b.homeZ) * b.dirZ
				local back = -along - 70
				if math.abs(back / Skirmish.GEN_GAP - math.floor(back / Skirmish.GEN_GAP + 0.5)) < 0.35 then
					onLattice += 1
				end
				xs[math.floor(along / 8)] = true
			end
		end
		t.expect(n >= 4, `generators built ({n})`)
		t.expect(onLattice >= n - 1, `in rows behind the base ({onLattice} of {n})`)
		-- (S-193, G3) the lanes between them are two cells wide: every
		-- footprint-2 unit fits through
		t.expect(Skirmish.GEN_GAP - 16 >= 16, "16-stud lanes")
	end)

	t.test("Hard - Aggressive starts on one factory type: no bot lab before its economy stands, never two (S-193, G1)", function()
		local sim = teamMatch({ "hard_aggressive", "hard" }, "map:ridgeline")
		local brains = Skirmish.forMatch(sim)
		local most, early = 0, 0
		for tick = 1, 15 * 60 * 7 do
			for _, b in brains do
				Skirmish.tick(b)
			end
			Sim.step(sim)
			if sim.match.over then
				break
			end
			if tick % 15 == 0 then
				local labs = owned(sim, 1, "botlab") -- frames and finished labs
				most = math.max(most, labs)
				if tick < 15 * 60 * 3 and labs > 0 then
					early += 1
				end
			end
		end
		t.expect(most <= 1, `at most one bot lab ({most})`)
		t.equal(early, 0, "none in the first 3 minutes")
	end)
end

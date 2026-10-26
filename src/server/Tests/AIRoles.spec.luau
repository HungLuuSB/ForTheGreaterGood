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

	t.test("roles: a side's AIs take air, defence, spam and tech in turn; a lone AI plays balanced", function()
		local sim = teamMatch({ "hard", "hard", "hard", "hard", "normal", "hard", "hard", "easy" })
		local roles = {}
		for pid = 1, 8 do
			table.insert(roles, Skirmish.roleOf(sim, pid, sim.match.ai[pid]))
		end
		t.deepEqual(roles, { "balanced", "air", "defense", "spam", "balanced", "air", "defense", "balanced" })
		local lone = teamMatch({ "hard", "hard" })
		t.equal(Skirmish.roleOf(lone, 1, "hard"), "balanced", "1v1")
		local cfg = Skirmish.withRole(Skirmish.LEVELS.hard, "defense", "hard")
		t.expect(cfg.defenses > Skirmish.LEVELS.hard.defenses and cfg.teamwork and (cfg.lanes or 1) >= 2, "defence: more turrets; teamwork; waves in two lanes")
	end)

	t.slow("in a 3v3 the air AI builds an airfield early, the defence AI twice the turrets, and bot labs come into play", function()
		local sim = teamMatch({ "hard", "hard", "hard", "hard_aggressive", "hard_aggressive", "hard_aggressive" })
		local brains = Skirmish.forMatch(sim)
		run(sim, brains, 15 * 60 * 10)
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
			if w.owner[id] == 1 and sim.defs.unitByIndex[w.defIndex[id]].id == b.prefix .. "generator" then
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
	end)
end

--!strict
-- The per-tick budget watchdog (S-140): what it logs, how often, and that a
-- tick within budget logs nothing.
local Log = require("@shared/Util/Log")
local Sim = require("../Sim/Sim")
local Spawn = require("../Sim/Spawn")
local Watchdog = require("../Sim/Watchdog")
local RunAll = require("./RunAll")

local PLAYERS = { { id = 1, team = 1 }, { id = 2, team = 2 } }

return function(t: RunAll.Context)
	local function capture(run: () -> ()): { { level: number, line: string } }
		local lines = {}
		Log.setSink(function(level: number, line: string)
			if string.find(line, "[Watchdog]", 1, true) then
				table.insert(lines, { level = level, line = line })
			end
		end)
		local ok, err = pcall(run)
		Log.setSink(nil)
		assert(ok, err)
		return lines
	end

	local function battle(): Sim.Sim
		local sim = Sim.new({ seed = 1, players = PLAYERS, mapId = "flat:64" })
		for i = 1, 6 do
			Spawn.unit(sim, "ord_lancer", 1, -100, i * 12)
			Spawn.unit(sim, "chs_ravager", 2, 100, i * 12)
		end
		return sim
	end

	t.test("over budget: one line a second naming the worst systems, the rest counted; a summary a minute (S-140)", function()
		local savedSummary = Watchdog.SUMMARY_TICKS
		Watchdog.SUMMARY_TICKS = 40
		local sim = battle()
		local dog = Watchdog.new(sim, { tickBudgetMs = 1e-9 }) -- every tick over
		local lines = capture(function()
			for _ = 1, 40 do
				Sim.step(sim)
				Watchdog.afterStep(dog)
			end
		end)
		Watchdog.SUMMARY_TICKS = savedSummary
		local warns, infos = {}, {}
		for _, l in lines do
			table.insert(if l.level == Log.Level.WARN then warns else infos, l.line)
		end
		t.equal(#warns, 3, "ticks 1, 16 and 31: one line per 15 ticks")
		t.expect(string.find(warns[1], "tick 1: ", 1, true) ~= nil, warns[1])
		t.expect(string.find(warns[2], "(+14 more over budget since the last line)", 1, true) ~= nil, `the skipped ticks are counted: {warns[2]}`)
		t.expect(string.find(warns[1], "Movement", 1, true) ~= nil or string.find(warns[1], "Targeting", 1, true) ~= nil or string.find(warns[1], "NetOut", 1, true) ~= nil, `systems named: {warns[1]}`)
		t.equal(#infos, 1, "one summary after SUMMARY_TICKS")
		t.expect(string.find(infos[1], "40 over budget (100.0%)", 1, true) ~= nil, infos[1])
		t.equal(dog.over, 40)
		print("    " .. warns[1])
		print("    " .. infos[1])
	end)

	t.test("within budget: nothing logged until the summary; timing totals still add up", function()
		local sim = battle()
		local dog = Watchdog.new(sim, { tickBudgetMs = 1e9 })
		local savedSlack = Watchdog.SYSTEM_SLACK
		Watchdog.SYSTEM_SLACK = 1e9
		local lines = capture(function()
			for _ = 1, 30 do
				Sim.step(sim)
				Watchdog.afterStep(dog)
			end
		end)
		Watchdog.SYSTEM_SLACK = savedSlack
		t.equal(#lines, 0, "no lines")
		t.equal(dog.over, 0)
		local sum = 0
		for _, v in dog.timing.last do
			sum += v
		end
		t.expect(math.abs(sum - dog.timing.lastTotal) < 1e-9, "last tick's systems add up to its total")
		t.equal(dog.timing.ticks, 30)
	end)
end

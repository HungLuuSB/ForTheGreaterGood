--!strict
-- Per-tick budget watchdog for a live server (S-140, next.md item 2): the
-- Lune timings are noisy and not Roblox's, so the Roblox server measures
-- itself. After each Sim.step, Watchdog.afterStep compares that tick's
-- system times (Sim.enableTiming) with guide 18.1's budgets and logs:
--   * a tick over the tick budget, or with a system over 2 × its own: one
--     WARN line with the tick, its total and the systems over budget, worst
--     first (at most one line per LOG_EVERY ticks; the rest are counted);
--   * every SUMMARY_TICKS: one INFO line with the share of ticks over
--     budget, the mean and worst tick, and the worst tick's top systems.
-- Observes only: it reads wall-clock timings that never feed back into the
-- simulation. Runs in Lune too (tests, soak).
--
--   local dog = Watchdog.new(sim)        -- after Sim.new
--   Sim.step(sim); Watchdog.afterStep(dog)

local Log = require("@shared/Util/Log")
local Sim = require("./Sim")

local Watchdog = {}

-- Guide 18.1 (15 Hz, 66.7 ms a tick, ~12 ms headroom), in ms per system.
-- Projectiles + damage share 8 ms; construction + lifecycle (Match) 2 ms.
Watchdog.BUDGET_MS = table.freeze({
	["Sim.Commands"] = 1,
	["Sim.Economy"] = 1,
	["Sim.Sensors"] = 5,
	["Sim.Targeting"] = 8,
	["Sim.Pathing"] = 8,
	["Sim.Movement"] = 10,
	["Sim.Weapons"] = 5,
	["Sim.Projectiles"] = 6,
	["Sim.Damage"] = 2,
	["Sim.Construction"] = 1.5,
	["Sim.Match"] = 0.5,
	["Sim.NetOut"] = 6,
} :: { [string]: number })
Watchdog.TICK_BUDGET_MS = 54 -- the systems together; the rest is headroom
Watchdog.SYSTEM_SLACK = 2 -- a system alone is flagged past this × its budget
Watchdog.LOG_EVERY = 15 -- ticks between over-budget lines (1 s)
Watchdog.SUMMARY_TICKS = 900 -- ticks between summaries (60 s)
Watchdog.TOP = 3 -- systems named per line

export type Options = {
	tickBudgetMs: number?,
	logger: Log.Logger?,
}

export type Watchdog = {
	sim: Sim.Sim,
	timing: Sim.Timing,
	tickBudgetMs: number,
	log: Log.Logger,
	lastLogTick: number,
	suppressed: number, -- over-budget ticks not logged since the last line
	-- this summary window
	windowTicks: number,
	windowOver: number,
	windowSum: number,
	worstMs: number,
	worstTick: number,
	worstTop: string,
	-- since start
	ticks: number,
	over: number,
}

function Watchdog.new(sim: Sim.Sim, options: Options?): Watchdog
	local o: Options = options or {}
	return {
		sim = sim,
		timing = Sim.enableTiming(sim),
		tickBudgetMs = o.tickBudgetMs or Watchdog.TICK_BUDGET_MS,
		log = o.logger or Log.new("Watchdog"),
		lastLogTick = -math.huge,
		suppressed = 0,
		windowTicks = 0,
		windowOver = 0,
		windowSum = 0,
		worstMs = 0,
		worstTick = 0,
		worstTop = "",
		ticks = 0,
		over = 0,
	}
end

type Entry = { name: string, ms: number, budget: number }
local entries: { Entry } = {}

-- The latest tick's systems, worst against their budget first; and how
-- many are over 2 × their budget.
local function ranked(dog: Watchdog): ({ Entry }, number)
	table.clear(entries)
	local flagged = 0
	for name, dt in dog.timing.last do
		local ms = dt * 1000
		local budget = Watchdog.BUDGET_MS[name] or 1
		if ms > 0 then
			table.insert(entries, { name = name, ms = ms, budget = budget })
		end
		if ms > budget * Watchdog.SYSTEM_SLACK then
			flagged += 1
		end
	end
	table.sort(entries, function(a: Entry, b: Entry): boolean
		local ra, rb = a.ms / a.budget, b.ms / b.budget
		if ra ~= rb then
			return ra > rb
		end
		return a.name < b.name
	end)
	return entries, flagged
end

local function topText(list: { Entry }): string
	local parts = {}
	for i = 1, math.min(Watchdog.TOP, #list) do
		local e = list[i]
		table.insert(parts, string.format("%s %.1f (%g)", string.sub(e.name, 5), e.ms, e.budget))
	end
	return table.concat(parts, ", ")
end

-- Call after every Sim.step.
function Watchdog.afterStep(dog: Watchdog)
	local tick = dog.sim.tick
	local totalMs = dog.timing.lastTotal * 1000
	local list, flagged = ranked(dog)
	local isOver = totalMs > dog.tickBudgetMs or flagged > 0
	dog.ticks += 1
	dog.windowTicks += 1
	dog.windowSum += totalMs
	if totalMs > dog.worstMs then
		dog.worstMs, dog.worstTick, dog.worstTop = totalMs, tick, topText(list)
	end
	if isOver then
		dog.over += 1
		dog.windowOver += 1
		if tick - dog.lastLogTick >= Watchdog.LOG_EVERY then
			local more = if dog.suppressed > 0 then string.format(" (+%d more over budget since the last line)", dog.suppressed) else ""
			dog.log:warn("tick %d: %.1f ms (budget %g): %s%s", tick, totalMs, dog.tickBudgetMs, topText(list), more)
			dog.lastLogTick = tick
			dog.suppressed = 0
		else
			dog.suppressed += 1
		end
	end
	if dog.windowTicks >= Watchdog.SUMMARY_TICKS then
		dog.log:info(
			"last %d ticks: %d over budget (%.1f%%), mean %.1f ms, worst %.1f ms at tick %d (%s); %d units",
			dog.windowTicks,
			dog.windowOver,
			dog.windowOver / dog.windowTicks * 100,
			dog.windowSum / dog.windowTicks,
			dog.worstMs,
			dog.worstTick,
			dog.worstTop,
			#dog.sim.world.ids
		)
		dog.windowTicks, dog.windowOver, dog.windowSum = 0, 0, 0
		dog.worstMs, dog.worstTick, dog.worstTop = 0, 0, ""
	end
end

return Watchdog

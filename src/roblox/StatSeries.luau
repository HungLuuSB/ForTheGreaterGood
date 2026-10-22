--!strict
-- Match statistics over time for the statistics panel (C-105): a sample of
-- every player's Sim/Stats report (S-63) and their team's stored supply and
-- power every EVERY ticks of the match. When it holds MAX samples, every
-- other one is dropped and the interval doubles, so a long match stays at
-- most MAX points per line (the lobby state carries it as JSON).
-- Stopgap until the sim keeps samples itself (client request 41, with
-- damage taken): it only reads the sim. Pure Luau (no Instances).

local StatSeries = {}

StatSeries.EVERY = 150 -- ticks between samples (10 s at 15 Hz)
StatSeries.MAX = 120
StatSeries.FIELDS = table.freeze({
	"supplyGathered",
	"supplySpent",
	"supplyStored",
	"powerGathered",
	"powerSpent",
	"powerStored",
	"unitsBuilt",
	"unitsLost",
	"unitsKilled",
	"damageDealt",
})

export type Series = {
	start: number, -- sim tick of the match start
	every: number, -- ticks between kept samples
	t: { number }, -- seconds since the start
	players: { [string]: { [string]: { number } } }, -- player id (as text, for JSON) → field → values
}

function StatSeries.new(startTick: number): Series
	return { start = startTick, every = StatSeries.EVERY, t = {}, players = {} }
end

-- Whether tick `tick` is a sample tick.
function StatSeries.due(s: Series, tick: number): boolean
	return (tick - s.start) % s.every == 0
end

local function halve(list: { number })
	local kept = {}
	for i = 1, #list, 2 do
		table.insert(kept, list[i])
	end
	table.clear(list)
	table.move(kept, 1, #kept, 1, list)
end

-- Appends a sample: `report` is Stats.report(sim); stored amounts come
-- from each player's team account.
function StatSeries.sample(s: Series, sim: any, report: { [number]: any })
	table.insert(s.t, (sim.tick - s.start) / 15)
	for _, pid in sim.playerOrder do
		local key = tostring(pid)
		local p = s.players[key]
		if p == nil then
			p = {}
			for _, f in StatSeries.FIELDS do
				p[f] = {}
			end
			s.players[key] = p
		end
		local r = report[pid] or {}
		local acc = sim.eco.accounts[sim.players[pid].team]
		local values = {
			supplyStored = if acc then acc.supply.stored else 0,
			powerStored = if acc then acc.power.stored else 0,
		}
		for _, f in StatSeries.FIELDS do
			local v = values[f] or r[f] or 0
			table.insert(p[f], math.floor(v + 0.5))
		end
	end
	if #s.t > StatSeries.MAX then
		halve(s.t)
		for _, p in s.players do
			for _, list in p do
				halve(list)
			end
		end
		s.every *= 2
	end
end

return StatSeries

--!strict
-- Match statistics per player (S-63, client request 38): the results
-- screen's units built and lost, resources gathered and spent, and damage
-- dealt. Server-side only (no wire format): the Roblox server reads
-- Stats.report at match end. Counted where things happen:
--   unitsBuilt    finished units, structures included (Build: PRODUCED,
--                 BUILD_DONE); the starting Command Vehicle doesn't count
--   unitsLost     own units that died (Damage)
--   unitsKilled   enemy units this player's damage finished (Damage)
--   damageDealt   health removed from enemy units, capped at what the target
--                 had left (Damage); a projectile keeps its shooter's player
--                 after the shooter dies (Combat.pPlayer)
--   damageTaken   health enemies removed from this player's units, capped
--                 the same way (Damage; client request 41)
-- Resources come from the player's team account (Economy: players sharing a
-- team share an account):
--   gathered      production, extraction, wind, reclaim and converter
--                 output credited per economy window (refunds included),
--                 before the storage cap
--   spent         drawn by construction, production, stockpiles, rearming
--                 and converters, after stall ratios; a window's
--                 forgiven shortfall isn't counted
-- Not hashed: it only reads the sim, and nothing in the sim reads it back.
--
-- Over time (client request 41, S-88): a sample of every player's report,
-- with their team's stored supply and power, at tick 0 and every EVERY
-- ticks (10 s). Past MAX samples every other one is dropped and the
-- interval doubles, so a line never holds more than MAX points. Stats.series
-- gives it in the shape the client's StatSeries used (C-105): `t` in
-- seconds, `players[tostring(pid)][field]` arrays of whole numbers.
-- Replays and headless runs get it too, since the sim keeps it.

local Stats = {}

export type PlayerStats = {
	unitsBuilt: number,
	unitsLost: number,
	unitsKilled: number,
	damageDealt: number,
	damageTaken: number,
}

export type Report = {
	unitsBuilt: number,
	unitsLost: number,
	unitsKilled: number,
	damageDealt: number,
	damageTaken: number,
	supplyGathered: number,
	powerGathered: number,
	supplySpent: number,
	powerSpent: number,
}

function Stats.new(playerIds: { number }): { [number]: PlayerStats }
	local out = {}
	for _, id in playerIds do
		out[id] = { unitsBuilt = 0, unitsLost = 0, unitsKilled = 0, damageDealt = 0, damageTaken = 0 }
	end
	return out
end

-- Every player's statistics so far, with their team account's resources.
function Stats.report(sim: any): { [number]: Report }
	local out = {}
	for _, pid in sim.playerOrder do
		local s = sim.playerStats[pid]
		local acc = sim.eco.accounts[sim.players[pid].team]
		out[pid] = {
			unitsBuilt = s.unitsBuilt,
			unitsLost = s.unitsLost,
			unitsKilled = s.unitsKilled,
			damageDealt = s.damageDealt,
			damageTaken = s.damageTaken,
			supplyGathered = if acc then acc.supply.gathered else 0,
			powerGathered = if acc then acc.power.gathered else 0,
			supplySpent = if acc then acc.supply.drawn else 0,
			powerSpent = if acc then acc.power.drawn else 0,
		}
	end
	return out
end

Stats.EVERY = 150 -- ticks between samples (10 s at 15 Hz)
Stats.MAX = 120 -- samples per line at most
Stats.FIELDS = table.freeze({
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
	"damageTaken",
})

export type Series = {
	start: number, -- sim tick of the first sample
	every: number, -- ticks between kept samples
	t: { number }, -- seconds since the start
	players: { [string]: { [string]: { number } } }, -- player id (as text, for JSON) → field → values
}

function Stats.newSeries(startTick: number): Series
	return { start = startTick, every = Stats.EVERY, t = {}, players = {} }
end

local function halve(list: { number })
	local n = 0
	for i = 1, #list, 2 do
		n += 1
		list[n] = list[i]
	end
	for i = #list, n + 1, -1 do
		list[i] = nil
	end
end

-- Appends a sample of every player now.
function Stats.sample(sim: any)
	local s: Series = sim.statSeries
	table.insert(s.t, (sim.tick - s.start) / 15)
	local report = Stats.report(sim)
	for _, pid in sim.playerOrder do
		local key = tostring(pid)
		local p = s.players[key]
		if p == nil then
			p = {}
			for _, f in Stats.FIELDS do
				p[f] = {}
			end
			s.players[key] = p
		end
		local r: any = report[pid]
		local acc = sim.eco.accounts[sim.players[pid].team]
		for _, f in Stats.FIELDS do
			local v = if f == "supplyStored" then (if acc then acc.supply.stored else 0)
				elseif f == "powerStored" then (if acc then acc.power.stored else 0)
				else r[f]
			table.insert(p[f], math.floor(v + 0.5))
		end
	end
	if #s.t > Stats.MAX then
		halve(s.t)
		for _, p in s.players do
			for _, list in p do
				halve(list)
			end
		end
		s.every *= 2
	end
end

-- Called at the end of every tick: samples when one is due.
function Stats.step(sim: any)
	local s: Series = sim.statSeries
	if (sim.tick - s.start) % s.every == 0 then
		Stats.sample(sim)
	end
end

-- The match so far, sample by sample (see the header).
function Stats.series(sim: any): Series
	return sim.statSeries
end

return Stats
